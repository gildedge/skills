#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════
# new-crud-entity.sh — scaffold a full CRM entity for gildedge-portal
# in the Gilded Edge house style: page.tsx + route.ts + migration + seed.
#
# DRY-RUN BY DEFAULT: prints every file to stdout with separators.
# Pass --write to save them into the venture. Pure bash 3.2 (no mapfile,
# no associative arrays), no exotic deps. Read-only unless --write.
#
# Usage:
#   new-crud-entity.sh --entity quotes --section crm \
#     --column 'quote_number:text:notnull' --column 'total:numeric' \
#     --column 'status:text' --fk 'client_id:clients' --access staff
#
#   new-crud-entity.sh --entity saved_views --section metrics \
#     --column 'name:text:notnull' --owner user_id --access owner --write
#
# Flags:
#   --entity   <name>   snake_case, plural (required)
#   --section  <name>   RBAC section for requireAuth (default: crm)
#   --column   k:type[:notnull]   repeatable
#   --fk       child_col:parent_table   repeatable (adds FK + index)
#   --access   staff|owner   access model (default: staff)
#                 staff: shared CRM route, references/route-handler.ts
#                 owner: per-user route, references/route-handler.owner.ts;
#                        stamps --owner on insert and filters every query on it
#   --owner    <col>    owner column for owner-scoped tables (default: user_id)
#   --venture  <name>   target venture dir (default: gildedge-portal)
#   --write             write files instead of printing
#
# The route's ALLOWED_FIELDS allowlist is filled from the --column and --fk
# names (minus id, created_at, updated_at and the owner column). Only those
# keys are ever written from a request body.
# ══════════════════════════════════════════════════════════════════
set -e

ENTITY=""
SECTION="crm"
ACCESS="staff"
OWNER="user_id"
VENTURE="gildedge-portal"
WRITE=0
ROOT="${GILDED_ROOT:-$HOME/GILDED-EDGE-ECOSYSTEM}"
COLS=""   # newline-delimited "name:type:notnull"
FKS=""    # newline-delimited "child:parent"

# Names end up inside SQL, TypeScript and sed replacements, so hold them to
# plain snake_case. Explicit classes, not a-z ranges, so locale can't widen it.
is_ident() {
  case "$1" in
    ''|[![:lower:]_]*|*[![:lower:][:digit:]_]*) return 1 ;;
    *) return 0 ;;
  esac
}
need_ident() {
  if ! is_ident "$2"; then
    echo "ERROR: $1 must be snake_case [a-z0-9_]: '$2'" >&2; exit 2
  fi
}

while [ $# -gt 0 ]; do
  case "$1" in
    --entity)  ENTITY="$2";  shift 2 ;;
    --section) SECTION="$2"; shift 2 ;;
    --access)  ACCESS="$2";  shift 2 ;;
    --owner)   OWNER="$2";   shift 2 ;;
    --venture) VENTURE="$2"; shift 2 ;;
    --column)  need_ident "--column name" "${2%%:*}"
               COLS="$COLS$2
"; shift 2 ;;
    --fk)      need_ident "--fk column" "${2%%:*}"
               need_ident "--fk parent table" "${2#*:}"
               FKS="$FKS$2
"; shift 2 ;;
    --write)   WRITE=1; shift ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$ENTITY" ]; then echo "ERROR: --entity is required" >&2; exit 2; fi
need_ident "--entity" "$ENTITY"
need_ident "--owner" "$OWNER"
# RBAC section slugs use hyphens (pitch-deck, audit-log).
case "$SECTION" in
  ''|*[![:lower:][:digit:]_-]*)
    echo "ERROR: --section must be a slug [a-z0-9_-]: '$SECTION'" >&2; exit 2 ;;
esac
case "$ACCESS" in
  staff) ROUTE_TEMPLATE="route-handler.ts" ;;
  owner) ROUTE_TEMPLATE="route-handler.owner.ts" ;;
  *) echo "ERROR: --access must be staff or owner: '$ACCESS'" >&2; exit 2 ;;
esac

DATE="$(date +%Y%m%d)"
VENTURE_DIR="$ROOT/ventures/$VENTURE"
MIG="$VENTURE_DIR/supabase/migrations/${DATE}_${ENTITY}.sql"
ROUTE="$VENTURE_DIR/src/app/api/${ENTITY}/route.ts"
PAGE="$VENTURE_DIR/src/app/portal/${ENTITY}/page.tsx"

# ── Build column DDL ────────────────────────────────────────────────
col_ddl() {
  printf '%s\n' "$COLS" | while IFS= read -r line; do
    [ -z "$line" ] && continue
    name="$(printf '%s' "$line" | cut -d: -f1)"
    type="$(printf '%s' "$line" | cut -d: -f2)"
    nn="$(printf '%s' "$line" | cut -d: -f3)"
    [ -z "$type" ] && type="text"
    if [ "$nn" = "notnull" ]; then
      printf '  %-14s %s NOT NULL,\n' "$name" "$(printf '%s' "$type" | tr a-z A-Z)"
    else
      printf '  %-14s %s,\n' "$name" "$(printf '%s' "$type" | tr a-z A-Z)"
    fi
  done
}

fk_ddl() {
  printf '%s\n' "$FKS" | while IFS= read -r line; do
    [ -z "$line" ] && continue
    child="$(printf '%s' "$line" | cut -d: -f1)"
    parent="$(printf '%s' "$line" | cut -d: -f2)"
    printf '  %-14s UUID REFERENCES %s(id),\n' "$child" "$parent"
  done
}

fk_idx() {
  printf '%s\n' "$FKS" | while IFS= read -r line; do
    [ -z "$line" ] && continue
    child="$(printf '%s' "$line" | cut -d: -f1)"
    printf 'CREATE INDEX IF NOT EXISTS idx_%s_%s ON %s(%s);\n' "$ENTITY" "$child" "$ENTITY" "$child"
  done
}

# Owner-scoped routes filter every query on the owner column, so index it.
owner_idx() {
  if [ "$ACCESS" = "owner" ]; then
    printf 'CREATE INDEX IF NOT EXISTS idx_%s_%s ON %s(%s);\n' "$ENTITY" "$OWNER" "$ENTITY" "$OWNER"
  fi
}

# ALLOWED_FIELDS for the route: FK + regular column names as a TS list body,
# e.g. 'client_id', 'total'. Server-owned columns are never client-settable.
fields_list() {
  printf '%s\n%s\n' "$FKS" "$COLS" | while IFS= read -r line; do
    [ -z "$line" ] && continue
    name="$(printf '%s' "$line" | cut -d: -f1)"
    case "$name" in
      id|created_at|updated_at) continue ;;
    esac
    if [ "$ACCESS" = "owner" ] && [ "$name" = "$OWNER" ]; then continue; fi
    printf "'%s'\n" "$name"
  done | awk 'NF && !seen[$0]++' | paste -sd, - | sed 's/,/, /g'
}
FIELDS="$(fields_list)"
if [ -z "$FIELDS" ]; then
  echo "WARNING: no --column/--fk given, so ALLOWED_FIELDS is empty and" >&2
  echo "         POST/PATCH will write nothing from the body until you fill it." >&2
fi

# All column lines together (FK + owner + regular), each on its own line.
all_cols() {
  fk_ddl
  if [ "$ACCESS" = "owner" ]; then
    printf '  %-14s UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,\n' "$OWNER"
  fi
  col_ddl
}

# ── Migration SQL ───────────────────────────────────────────────────
gen_migration() {
cat <<SQL
-- =========================================================
-- gildedge-portal — ${ENTITY} (${ACCESS}-scoped)
-- Generated by crud-route-scaffold. Date: ${DATE}
-- =========================================================

CREATE TABLE IF NOT EXISTS ${ENTITY} (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
$(all_cols)
  created_at     TIMESTAMPTZ DEFAULT now(),
  updated_at     TIMESTAMPTZ DEFAULT now()
);

$(fk_idx; owner_idx)
ALTER TABLE ${ENTITY} ENABLE ROW LEVEL SECURITY;

-- ═══════════════════════════════════════════════════════════════════
-- >>> RLS: delegate the policy block to the rls-migration-writer skill.
--   staff-shared CRM (admin/team see all rows):
--     CREATE POLICY "Authenticated CRM access" ON ${ENTITY}
--       FOR ALL USING (auth.role() = 'authenticated');
--   owner-scoped (per-user private data): use the 4 owner policies:
--     bash ~/.claude/skills/rls-migration-writer/scripts/new-migration.sh \\
--       --venture ${VENTURE} --table ${ENTITY} --owner ${OWNER}
--   NEVER emit WITH CHECK (true) or a self-referential (recursive) policy.
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS \$\$ BEGIN NEW.updated_at = now(); RETURN NEW; END; \$\$ LANGUAGE plpgsql;

CREATE TRIGGER set_updated_at BEFORE UPDATE ON ${ENTITY}
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ─── Idempotent seed (fixed UUIDs; safe to re-run) ─────────────────
-- INSERT INTO ${ENTITY} (id, ...) VALUES
--   ('00000000-0000-0000-0000-0000000000${ENTITY}'::uuid /* replace */, ...)
-- ON CONFLICT (id) DO NOTHING;
SQL
}

# ── Route handler ───────────────────────────────────────────────────
# staff -> route-handler.ts, owner -> route-handler.owner.ts (see --access).
# Every substituted value was validated above, so none can break the sed.
# SECTION and OWNER are matched with their quotes: a bare s/SECTION/crm/
# also rewrote the const's own name (const crm = 'crm'), which is a syntax
# error for hyphenated sections such as pitch-deck.
gen_route() {
  sed -e "s/ENTITY/${ENTITY}/g" -e "s/'SECTION'/'${SECTION}'/g" \
      -e "s/'OWNER'/'${OWNER}'/g" \
      -e "s|/\* FIELDS \*/|${FIELDS}|" \
    "$(dirname "$0")/../references/${ROUTE_TEMPLATE}"
}

# ── Page ────────────────────────────────────────────────────────────
title="$(printf '%s' "$ENTITY" | tr '_' ' ' | awk '{for(i=1;i<=NF;i++)$i=toupper(substr($i,1,1)) substr($i,2)}1')"
gen_page() {
  sed -e "s/ENTITY_TITLE/${title}/g" -e "s/ENTITY/${ENTITY}/g" -e "s/SECTION/${SECTION}/g" \
    "$(dirname "$0")/../references/page.tsx"
}

emit() {
  echo "════════════════════════════════════════════════════════════════"
  echo "FILE: $1"
  echo "════════════════════════════════════════════════════════════════"
  shift
  "$@"
  echo
}

if [ "$WRITE" -eq 1 ]; then
  mkdir -p "$(dirname "$MIG")" "$(dirname "$ROUTE")" "$(dirname "$PAGE")"
  gen_migration > "$MIG"
  gen_route     > "$ROUTE"
  gen_page      > "$PAGE"
  echo "Wrote:"
  echo "  $MIG"
  echo "  $ROUTE"
  echo "  $PAGE"
  echo
  echo "Next: fill the RLS block via rls-migration-writer, replace placeholder"
  echo "columns/seed, build <Entity>Client.tsx + .module.css, then 'npm run build'."
else
  echo "# DRY RUN — nothing written. Re-run with --write to save into $VENTURE."
  echo
  emit "$MIG"   gen_migration
  emit "$ROUTE" gen_route
  emit "$PAGE"  gen_page
fi
