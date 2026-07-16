#!/usr/bin/env bash
# scan_slugs.sh — READ ONLY. Discover every table with a venture_id column and list
# its distinct values + row counts, plus aria_metrics.venture. Run before and after
# the remap to see reality / verify.
# Usage: scan_slugs.sh "$PGURI"   (pass the pooler connection string, do not hardcode)

set -o pipefail
PGURI="${1:?usage: scan_slugs.sh <postgres-connection-uri>}"
command -v psql >/dev/null 2>&1 || { echo "✗ psql not installed"; exit 1; }

echo "== distinct venture_id values across all public tables (project: gildedge-portal) =="
psql "$PGURI" -v ON_ERROR_STOP=1 -At <<'SQL'
do $$
declare
  r record;
begin
  create temp table _slug_scan(source text, value text, n bigint) on commit drop;
  -- every public table with a venture_id column
  for r in
    select table_name from information_schema.columns
    where table_schema='public' and column_name='venture_id'
  loop
    execute format(
      'insert into _slug_scan select %L, venture_id, count(*) from public.%I group by venture_id',
      r.table_name, r.table_name);
  end loop;
  -- aria_metrics carries the slug under column "venture"
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='aria_metrics' and column_name='venture') then
    insert into _slug_scan select 'aria_metrics(venture)', venture, count(*)
    from public.aria_metrics group by venture;
  end if;
end $$;

-- rolled-up: one line per distinct value, total rows, and where it appears
select coalesce(value,'<null>') as venture_id,
       sum(n)                    as rows,
       count(distinct source)    as tables
from _slug_scan
group by value
order by rows desc;
SQL

echo ""
echo "Compare against sql/mapping.csv. Every non-null value MUST have a mapping row"
echo "before you run the remap, or the leftover will later block the FK."
