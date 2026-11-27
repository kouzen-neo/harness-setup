#!/usr/bin/env bash
# Remove what install.sh added: the managed rule blocks, wrappers and folders it created.
# MCP registrations and backups are left alone (remove MCP servers with each CLI's `mcp remove`).
set -eo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT/lib/common.sh"
. "$ROOT/lib/harnesses.sh"

RULES_DIR="$HOME/.config/agent-rules"
SESSIONS_DIR="$HOME/.local/share/agent-session"
BIN_DIR="$HOME/.local/bin"
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help) echo "Usage: uninstall.sh [--dry-run]"; exit 0 ;;
    *) die "unknown option: $arg" ;;
  esac
done
export DRY_RUN

for h in $KNOWN_HARNESSES; do
  target=$(harness_rules_file "$h")
  if [ -f "$target" ] && grep -qxF "$MARK_BEGIN" "$target"; then
    if [ "$DRY_RUN" = 1 ]; then log "[dry-run] remove managed block from $target"; else remove_managed_block "$target"; log "removed rules block: $target"; fi
  fi
done
for w in claude-session agy-session opencode-session agent-sudo-on agent-sudo-off agent-sudo-none; do
  if [ -f "$BIN_DIR/$w" ] && grep -q 'managed by harness-setup' "$BIN_DIR/$w"; then run rm -f "$BIN_DIR/$w"; log "removed wrapper: $w"; fi
done
for dir in "$SESSIONS_DIR" "$RULES_DIR"; do
  if [ -f "$dir/$MANAGED_FILE" ]; then run rm -rf "$dir"; log "removed folder: $dir"; fi
done
log "Done. MCP servers and backups were left in place."
