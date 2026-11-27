#!/usr/bin/env bash
# Scan a folder for credential-looking strings, personal paths, and owner-specific words that must not appear in a public repo.
# Usage: tools/scan-secrets.sh [--forbid FILE] [DIR]
#   --forbid FILE   one literal word or phrase per line (your name, domain, email); keep that file OUTSIDE the repo
#   DIR             folder to scan (default: the repo root)
# Exit code 0 = clean, 1 = something found.
set -eo pipefail

readonly CREDENTIAL_PATTERNS=(
  'AQ\.[A-Za-z0-9_-]{20,}'
  'AIza[0-9A-Za-z_-]{30,}'
  'hf_[A-Za-z0-9]{20,}'
  'gh[pousr]_[A-Za-z0-9]{20,}'
  'sk-[A-Za-z0-9]{20,}'
  'xox[bap]-[A-Za-z0-9-]{10,}'
  '-----BEGIN [A-Z ]*PRIVATE KEY-----'
  'Bearer [A-Za-z0-9._-]{20,}'
  '(api[_-]?key|token|secret|password)[[:space:]]*[:=][[:space:]]*["'"'"']?[A-Za-z0-9_./+-]{16,}'
)
readonly PERSONAL_PATH_PATTERNS=('/home/[a-z][a-z0-9_-]*/' '/Users/[A-Za-z][A-Za-z0-9_-]*/')

FORBID_FILE=""
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
while [ $# -gt 0 ]; do
  case "$1" in
    --forbid) FORBID_FILE="${2:?--forbid needs a file}"; shift ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) DIR="$1" ;;
  esac
  shift
done

found=0
scan() { # $1 label, $2 grep mode (-E or -F), $3 pattern
  local hits
  hits=$(grep -rIn "$2" --exclude-dir=.git --exclude-dir=__pycache__ --exclude=scan-secrets.sh -e "$3" "$DIR" 2>/dev/null || true)
  if [ -n "$hits" ]; then
    printf 'FOUND (%s): %s\n%s\n' "$1" "$3" "$hits" >&2
    found=1
  fi
}

for p in "${CREDENTIAL_PATTERNS[@]}"; do scan "credential-like" -E "$p"; done
for p in "${PERSONAL_PATH_PATTERNS[@]}"; do scan "personal path" -E "$p"; done
if [ -n "$FORBID_FILE" ]; then
  [ -f "$FORBID_FILE" ] || { echo "forbid file not found: $FORBID_FILE" >&2; exit 2; }
  while IFS= read -r word || [ -n "$word" ]; do
    [ -n "$word" ] || continue
    scan "forbidden word" -F "$word"
  done < "$FORBID_FILE"
fi

if [ "$found" -eq 0 ]; then echo "clean: no credentials, personal paths, or forbidden words in $DIR"; fi
exit "$found"
