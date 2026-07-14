#!/usr/bin/env bash
# backfill.sh — bring an EXISTING venture up to Tier-1 conventions. Idempotent.
#
# Usage:  backfill.sh <repo-path> [--kind next|node|python|static]
#
# Copies canonical files from templates/, sets engines.node, injects lint-staged,
# pins Next/React for `next` repos, generates a values-free .env.example, and wires
# hooks. Prints "+ added" / "= already ok" per action. NEVER commits. NEVER writes secrets.

set -euo pipefail

REPO="${1:-}"
KIND=""
shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --kind) KIND="${2:-}"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

if [ -z "$REPO" ] || [ ! -d "$REPO" ]; then
  echo "Usage: $0 <repo-path> [--kind next|node|python|static]"; exit 1
fi
REPO="$(cd "$REPO" && pwd)"

ECO_ROOT="${GILDED_EDGE_ROOT:-$HOME/GILDED-EDGE-ECOSYSTEM}"
TPL="$ECO_ROOT/templates"
VTPL="$TPL/venture-nextjs"
NAME="$(basename "$REPO")"

NODE_VERSION="20.9.0"
NEXT_VERSION="16.2.4"
REACT_VERSION="19.2.4"

GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; CYAN=$'\033[0;36m'; NC=$'\033[0m'
add()  { printf "  ${GREEN}+ %s${NC}\n" "$1"; }
skip() { printf "  = %s\n" "$1"; }
warn() { printf "  ${YELLOW}! %s${NC}\n" "$1"; }

if [ ! -d "$TPL" ]; then
  echo "Templates not found at $TPL — set GILDED_EDGE_ROOT or run from the ecosystem."; exit 1
fi

# --- infer kind if not given ---
if [ -z "$KIND" ]; then
  # honor the audit's canonical list first
  KIND="$(awk -F'|' -v n="$NAME" '$0 ~ "/"n"\\|" {print $2}' "$ECO_ROOT/scripts/audit-ecosystem.sh" 2>/dev/null | head -1 | tr -d '[:space:]' || true)"
fi
if [ -z "$KIND" ]; then
  if [ -f "$REPO/package.json" ] && grep -Eq '"next"[[:space:]]*:' "$REPO/package.json"; then
    KIND="next"
  elif [ -f "$REPO/requirements.txt" ] || [ -f "$REPO/pyproject.toml" ]; then
    KIND="python"
  elif [ -f "$REPO/package.json" ]; then
    KIND="node"
  else
    KIND="static"
  fi
fi

echo "${CYAN}Tier-1 backfill: $NAME  (kind=$KIND)${NC}"
echo "Repo: $REPO"
echo ""

# --- base files (all kinds) ---
if [ ! -f "$REPO/.gitignore" ]; then
  cp "$TPL/configs/gitignore.nextjs" "$REPO/.gitignore"; add ".gitignore (from template)"
else
  skip ".gitignore present"
fi

if [ ! -f "$REPO/.gitattributes" ]; then
  cp "$TPL/configs/gitattributes" "$REPO/.gitattributes"; add ".gitattributes (LFS globs)"
else
  skip ".gitattributes present"
fi

if [ ! -f "$REPO/README.md" ]; then
  sed "s/{{NAME}}/$NAME/g" "$VTPL/README.md.tmpl" > "$REPO/README.md"; add "README.md (from template)"
else
  skip "README.md present"
fi

# CLAUDE.md / AGENTS.md — never overwrite a customized one.
if [ ! -f "$REPO/CLAUDE.md" ]; then
  cp "$VTPL/CLAUDE.md" "$REPO/CLAUDE.md"; add "CLAUDE.md (@AGENTS.md indirection)"
else
  skip "CLAUDE.md present (kept as-is)"
fi
if [ ! -f "$REPO/AGENTS.md" ]; then
  cp "$VTPL/AGENTS.md" "$REPO/AGENTS.md"; add "AGENTS.md (from template)"
else
  skip "AGENTS.md present (kept as-is)"
fi

# --- static repos stop here ---
if [ "$KIND" = "static" ]; then
  echo ""
  echo "${YELLOW}Static repo — base files only. No Node tooling added.${NC}"
  echo "Re-audit: (cd $ECO_ROOT && bash scripts/audit-ecosystem.sh)"
  exit 0
fi

# --- CI (node/next/python) ---
mkdir -p "$REPO/.github/workflows"
if [ ! -f "$REPO/.github/workflows/ci.yml" ]; then
  cp "$TPL/ci/nextjs-ci.yml" "$REPO/.github/workflows/ci.yml"; add ".github/workflows/ci.yml"
else
  skip "ci.yml present"
fi

# --- .env.example (values-free) ---
if [ ! -f "$REPO/.env.example" ]; then
  {
    echo "# $NAME — environment variables (names only, NO real values)."
    echo "# Provision with the venture-provision skill / PROVISIONING_CHECKLIST.md."
    if [ -x "$ECO_ROOT/scripts/scan-env-vars.sh" ]; then
      bash "$ECO_ROOT/scripts/scan-env-vars.sh" "$REPO" 2>/dev/null | while read -r v; do
        [ -n "$v" ] && echo "${v}="
      done
    fi
  } > "$REPO/.env.example"
  add ".env.example (generated from source refs, values blank)"
else
  skip ".env.example present"
fi

# --- python repos need only .env.example + CI ---
if [ "$KIND" = "python" ]; then
  echo ""
  echo "${GREEN}Python repo backfill complete (.env.example + CI).${NC}"
  echo "Re-audit: (cd $ECO_ROOT && bash scripts/audit-ecosystem.sh)"
  exit 0
fi

# --- Node/Next below ---

# .nvmrc
if [ -f "$REPO/.nvmrc" ] && grep -q "^${NODE_VERSION}\$" "$REPO/.nvmrc"; then
  skip ".nvmrc pins $NODE_VERSION"
else
  cp "$TPL/configs/nvmrc" "$REPO/.nvmrc"; add ".nvmrc → $NODE_VERSION"
fi

# renovate.json
if [ ! -f "$REPO/renovate.json" ]; then
  cp "$TPL/configs/renovate.json" "$REPO/renovate.json"; add "renovate.json"
else
  skip "renovate.json present"
fi

# package.json edits via node (safe JSON) — backup first.
if [ -f "$REPO/package.json" ]; then
  cp "$REPO/package.json" "$REPO/package.json.bak"
  KIND="$KIND" NEXTV="$NEXT_VERSION" REACTV="$REACT_VERSION" NODEV="$NODE_VERSION" \
  node - "$REPO/package.json" <<'NODE'
const fs = require('fs');
const p = process.argv[2];
const pkg = JSON.parse(fs.readFileSync(p, 'utf8'));
const kind = process.env.KIND, nextv = process.env.NEXTV, reactv = process.env.REACTV, nodev = process.env.NODEV;
let changed = [];

pkg.engines = pkg.engines || {};
if (pkg.engines.node !== `>=${nodev}`) { pkg.engines.node = `>=${nodev}`; changed.push('engines.node'); }

if (!pkg['lint-staged']) {
  pkg['lint-staged'] = {
    "*.{ts,tsx,js,jsx,mjs,cjs}": ["eslint --fix"],
    "*.{json,md,yml,yaml,css}": ["prettier --write"]
  };
  changed.push('lint-staged');
}

// Exact Next/React pins ONLY for `next` repos.
if (kind === 'next') {
  const pin = (obj, key, ver) => {
    if (obj && obj[key] && obj[key] !== ver) { obj[key] = ver; changed.push(key); }
  };
  pin(pkg.dependencies, 'next', nextv);
  pin(pkg.dependencies, 'react', reactv);
  pin(pkg.dependencies, 'react-dom', reactv);
  pin(pkg.devDependencies, 'eslint-config-next', nextv);
}

if (changed.length) {
  fs.writeFileSync(p, JSON.stringify(pkg, null, 2) + '\n');
  console.log('  + package.json updated: ' + changed.join(', '));
} else {
  console.log('  = package.json already conforming');
}
NODE
  rm -f "$REPO/package.json.bak"
else
  warn "no package.json — cannot set engines/lint-staged/pins"
fi

# hooks — prefer the canonical installer; fallback to local copy.
if [ -f "$REPO/.githooks/pre-commit" ] && [ -f "$REPO/.githooks/pre-push" ]; then
  skip ".githooks/{pre-commit,pre-push} present"
else
  mkdir -p "$REPO/.githooks"
  cp "$TPL/hooks/pre-commit" "$REPO/.githooks/pre-commit"
  cp "$TPL/hooks/pre-push"   "$REPO/.githooks/pre-push"
  chmod +x "$REPO/.githooks/pre-commit" "$REPO/.githooks/pre-push"
  add ".githooks/{pre-commit,pre-push}"
fi
if [ -d "$REPO/.git" ]; then
  if [ "$(git -C "$REPO" config core.hooksPath 2>/dev/null)" = ".githooks" ]; then
    skip "core.hooksPath=.githooks"
  else
    git -C "$REPO" config core.hooksPath .githooks; add "core.hooksPath=.githooks"
  fi
else
  warn "no .git dir — run 'git init' then re-run so core.hooksPath can be set"
fi

echo ""
echo "${GREEN}Backfill pass complete for $NAME.${NC}"
echo "Next:"
echo "  cd $REPO && npm install -D lint-staged prettier   # + npm install if pins changed"
echo "  (cd $ECO_ROOT && bash scripts/audit-ecosystem.sh)  # re-audit until green"
echo "  git -C $REPO status   # review, then commit yourself (nothing was committed)"
