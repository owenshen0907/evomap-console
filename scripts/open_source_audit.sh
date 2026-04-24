#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

printf 'Running open-source audit in %s\n' "$ROOT"

python3 -m json.tool App/Assets.xcassets/Contents.json >/dev/null
python3 -m json.tool App/Assets.xcassets/AppIcon.appiconset/Contents.json >/dev/null

if rg -n --hidden \
  -g '!.git/**' \
  -g '!*.png' \
  -g '!*.jpg' \
  -g '!*.jpeg' \
  -g '!*.icns' \
  -g '!scripts/open_source_audit.sh' \
  -e 'sk-[A-Za-z0-9_-]{20,}' \
  -e "node_secret[\"\x27 ]*[:=][\"\x27 ][A-Za-z0-9_-]{12,}" \
  -e "api[_-]?key[\"\x27 ]*[:=][\"\x27 ][A-Za-z0-9_-]{12,}" \
  -e '/Users/[^ /]+' \
  -e 'claim/[A-Z0-9]{4,}-[A-Z0-9]{4,}' \
  .; then
  printf '\nPotential secret or personal path found. Review before publishing.\n' >&2
  exit 1
fi

printf 'Open-source audit passed.\n'
