#!/usr/bin/env bash
# generate_sql.sh — emit SQL to stdout from the CSV mapping. Generates SQL only;
# it never connects to a database. Review the output, then apply with psql.
# Usage:
#   generate_sql.sh --backup      # snapshot every (table, pk, venture_id) into bak_YYYYMMDD
#   generate_sql.sh --remap       # single-transaction CTE remap of 14 variants -> 6 slugs
#   generate_sql.sh --guardrail   # ventures(slug PK) table + FK from every venture_id
#   generate_sql.sh --guardrail --check   # use CHECK(...) instead of FK (softer guard)

set -o pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
MAP="$HERE/sql/mapping.csv"
CANON="$HERE/sql/canonical_ventures.csv"
STAMP="$(date '+%Y%m%d')"

MODE="${1:?usage: generate_sql.sh --backup|--remap|--guardrail [--check]}"
USE_CHECK=0
[ "${2:-}" = "--check" ] && USE_CHECK=1

[ -f "$MAP" ]   || { echo "-- ✗ missing $MAP" >&2; exit 1; }
[ -f "$CANON" ] || { echo "-- ✗ missing $CANON" >&2; exit 1; }

# sql-escape single quotes in a value
esc() { printf "%s" "$1" | sed "s/'/''/g"; }

# Build a SQL VALUES list from mapping.csv (skip comments / blank canonical).
map_values() {
  local first=1
  while IFS=',' read -r variant canonical; do
    case "$variant" in ''|\#*) continue;; esac
    [ -z "$canonical" ] && continue
    variant="$(echo "$variant" | sed 's/[[:space:]]*$//')"
    canonical="$(echo "$canonical" | sed 's/[[:space:]]*$//')"
    [ $first -eq 1 ] && first=0 || printf ",\n"
    printf "    ('%s','%s')" "$(esc "$variant")" "$(esc "$canonical")"
  done < "$MAP"
  printf "\n"
}

case "$MODE" in
  --backup)
    cat <<SQL
-- ══════════════════════════════════════════════════════════════════
-- slug-normalize · BACKUP (generated $(date '+%Y-%m-%d %H:%M:%S'))
-- Snapshots every table with a venture_id column into schema bak_${STAMP}.
-- Rollback one table:
--   update public.<t> set venture_id = b.venture_id
--   from bak_${STAMP}.<t> b where <t>.id = b.id;
-- ══════════════════════════════════════════════════════════════════
create schema if not exists bak_${STAMP};

do \$\$
declare r record;
begin
  for r in
    select table_name from information_schema.columns
    where table_schema='public' and column_name='venture_id'
  loop
    execute format('drop table if exists bak_${STAMP}.%I', r.table_name);
    execute format('create table bak_${STAMP}.%I as table public.%I', r.table_name, r.table_name);
    raise notice 'backed up public.% -> bak_${STAMP}.%', r.table_name, r.table_name;
  end loop;
  -- aria_metrics uses column "venture"
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='aria_metrics' and column_name='venture') then
    execute 'drop table if exists bak_${STAMP}.aria_metrics';
    execute 'create table bak_${STAMP}.aria_metrics as table public.aria_metrics';
    raise notice 'backed up public.aria_metrics -> bak_${STAMP}.aria_metrics';
  end if;
end \$\$;
SQL
    ;;

  --remap)
    cat <<SQL
-- ══════════════════════════════════════════════════════════════════
-- slug-normalize · REMAP (generated $(date '+%Y-%m-%d %H:%M:%S'))
-- ONE transaction. Remaps 14 variants -> 6 canonical slugs across every
-- table with a venture_id column, plus aria_metrics.venture. All-or-nothing.
-- RUN THE BACKUP FIRST.
-- ══════════════════════════════════════════════════════════════════
begin;

create temp table _slug_map(variant text primary key, canonical text not null) on commit drop;
insert into _slug_map(variant, canonical) values
$(map_values);

do \$\$
declare r record; touched bigint;
begin
  for r in
    select table_name from information_schema.columns
    where table_schema='public' and column_name='venture_id'
  loop
    execute format(
      'update public.%I t set venture_id = m.canonical
         from _slug_map m
        where t.venture_id = m.variant and t.venture_id is distinct from m.canonical',
      r.table_name);
    get diagnostics touched = row_count;
    if touched > 0 then raise notice 'remapped % rows in public.%', touched, r.table_name; end if;
  end loop;

  -- aria_metrics.venture (different column name)
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='aria_metrics' and column_name='venture') then
    update public.aria_metrics t set venture = m.canonical
      from _slug_map m
     where t.venture = m.variant and t.venture is distinct from m.canonical;
    get diagnostics touched = row_count;
    if touched > 0 then raise notice 'remapped % rows in public.aria_metrics(venture)', touched; end if;
  end if;
end \$\$;

-- Safety net: refuse to commit if any UNMAPPED value would survive and later
-- block the FK. Lists offenders and aborts.
do \$\$
declare r record; bad text;
begin
  for r in
    select table_name from information_schema.columns
    where table_schema='public' and column_name='venture_id'
  loop
    execute format(
      'select string_agg(distinct venture_id, '', '')
         from public.%I
        where venture_id is not null
          and venture_id not in (select canonical from _slug_map)',
      r.table_name) into bad;
    if bad is not null then
      raise exception 'unmapped venture_id in public.%: %  (add to mapping.csv, re-run)', r.table_name, bad;
    end if;
  end loop;
end \$\$;

commit;
-- If the safety net raised, the whole transaction rolled back — nothing changed.
SQL
    ;;

  --guardrail)
    # canonical seed rows
    seed=""
    first=1
    while IFS=',' read -r slug name; do
      case "$slug" in ''|\#*) continue;; esac
      slug="$(echo "$slug" | sed 's/[[:space:]]*$//')"
      name="$(echo "$name" | sed 's/[[:space:]]*$//')"
      [ $first -eq 1 ] && first=0 || printf -v seed "%s,\n" "$seed"
      seed="${seed}  ('$(esc "$slug")','$(esc "$name")')"
    done < "$CANON"

    cat <<SQL
-- ══════════════════════════════════════════════════════════════════
-- slug-normalize · GUARDRAIL (generated $(date '+%Y-%m-%d %H:%M:%S'))
-- THE ACTUAL FIX: a canonical registry + a database-enforced constraint so
-- venture_id CANNOT drift again. Run AFTER the remap (data must be clean).
-- ══════════════════════════════════════════════════════════════════

-- 1. Canonical registry — the single source of truth for valid slugs.
create table if not exists public.ventures (
  slug        text primary key,
  name        text not null,
  created_at  timestamptz not null default now()
);

insert into public.ventures(slug, name) values
${seed}
on conflict (slug) do update set name = excluded.name;
SQL

    if [ "$USE_CHECK" -eq 1 ]; then
      # CHECK variant: build IN-list from canonical slugs
      inlist=""
      first=1
      while IFS=',' read -r slug name; do
        case "$slug" in ''|\#*) continue;; esac
        slug="$(echo "$slug" | sed 's/[[:space:]]*$//')"
        [ $first -eq 1 ] && first=0 || inlist="${inlist}, "
        inlist="${inlist}'$(esc "$slug")'"
      done < "$CANON"
      cat <<SQL

-- 2. (CHECK variant) constrain each venture_id to the canonical set.
do \$\$
declare r record;
begin
  for r in
    select table_name from information_schema.columns
    where table_schema='public' and column_name='venture_id'
  loop
    execute format(
      'alter table public.%I add constraint %I
         check (venture_id is null or venture_id in (${inlist}))',
      r.table_name, r.table_name||'_venture_id_chk');
  end loop;
end \$\$;
SQL
    else
      cat <<SQL

-- 2. (FK variant, preferred) FK every venture_id to public.ventures(slug).
--    on update cascade => an intentional future rename is a one-row update to
--    public.ventures that propagates everywhere; an unknown slug is rejected.
do \$\$
declare r record;
begin
  for r in
    select table_name from information_schema.columns
    where table_schema='public' and column_name='venture_id'
  loop
    begin
      execute format(
        'alter table public.%I add constraint %I
           foreign key (venture_id) references public.ventures(slug)
           on update cascade on delete restrict',
        r.table_name, r.table_name||'_venture_id_fk');
      raise notice 'FK added on public.%', r.table_name;
    exception when duplicate_object then
      raise notice 'FK already exists on public.% (skipped)', r.table_name;
    end;
  end loop;

  -- aria_metrics.venture
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='aria_metrics' and column_name='venture') then
    begin
      execute 'alter table public.aria_metrics add constraint aria_metrics_venture_fk
               foreign key (venture) references public.ventures(slug)
               on update cascade on delete restrict';
      raise notice 'FK added on public.aria_metrics(venture)';
    exception when duplicate_object then
      raise notice 'FK already exists on public.aria_metrics (skipped)';
    end;
  end if;
end \$\$;
SQL
    fi

    cat <<SQL

-- 3. Verify the guard bites (should raise a FK/CHECK violation):
--    insert into public.leads(venture_id) values ('nope');
SQL
    ;;

  *)
    echo "-- ✗ unknown mode: $MODE  (use --backup | --remap | --guardrail [--check])" >&2
    exit 1
    ;;
esac
