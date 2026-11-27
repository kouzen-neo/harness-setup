#!/usr/bin/env bash
# Shared helpers: logging, command running, env parsing, template rendering, managed blocks, backups.
# Written for bash 3.2+ (macOS default) as well as modern bash.

readonly MARK_BEGIN="<!-- harness-setup:begin -->"
readonly MARK_END="<!-- harness-setup:end -->"
readonly MANAGED_FILE=".harness-setup-managed"

log()  { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

# Run a command, or only print it in dry-run mode.
run() {
  if [ "${DRY_RUN:-0}" = 1 ]; then log "[dry-run] $*"; else "$@"; fi
}

# Load KEY=value lines into shell variables without executing anything from the file.
load_env() {
  local file="$1" line key val
  [ -f "$file" ] || die "env file not found: $file"
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac
    key="${line%%=*}"
    val="${line#*=}"
    if ! [[ "$key" =~ ^[A-Z][A-Z0-9_]*$ ]]; then
      warn "ignoring invalid line in $file: ${line:0:40}"
      continue
    fi
    val="${val%\"}"; val="${val#\"}"; val="${val%\'}"; val="${val#\'}"
    val="${val/#\~/$HOME}"
    printf -v "$key" '%s' "$val"
  done < "$file"
}

# Replace every literal occurrence of {{NAME}} on stdin with VAL (no regex, no & expansion).
replace_literal() {
  NAME="$1" VAL="$2" awk '
    BEGIN { n = "{{" ENVIRON["NAME"] "}}"; v = ENVIRON["VAL"] }
    { s = $0; out = ""
      while ((i = index(s, n)) > 0) { out = out substr(s, 1, i - 1) v; s = substr(s, i + length(n)) }
      print out s }'
}

# Print a template with {{NAME}} replaced by the variable NAME, or by a visible "ask the owner" marker.
render_template() {
  local file="$1" text name val
  text=$(cat "$file")
  for name in $(grep -o '{{[A-Z][A-Z0-9_]*}}' "$file" | sort -u | tr -d '{}'); do
    val="${!name-}"
    if [ -z "$val" ]; then
      case " ${ALLOW_EMPTY-} " in
        *" $name "*) val="" ;;
        *) val="<$name is not set: ask the owner>" ;;
      esac
    fi
    text=$(printf '%s\n' "$text" | replace_literal "$name" "$val")
  done
  printf '%s\n' "$text"
}

backup_file() {
  [ -e "$1" ] || return 0
  run mkdir -p "$BACKUP_DIR"
  run cp -p "$1" "$BACKUP_DIR/${1//\//_}"
}

# Put a block (a file already wrapped in the begin/end markers) into a target file, keeping all other content.
write_managed_block() {
  local target="$1" block="$2" tmp
  run mkdir -p "$(dirname "$target")"
  backup_file "$target"
  if [ "${DRY_RUN:-0}" = 1 ]; then log "[dry-run] write managed block to $target"; return 0; fi
  if [ -f "$target" ] && grep -qxF "$MARK_BEGIN" "$target"; then
    tmp=$(mktemp)
    awk -v b="$MARK_BEGIN" -v e="$MARK_END" -v f="$block" '
      $0 == b { while ((getline line < f) > 0) print line; skip = 1; next }
      $0 == e { skip = 0; next }
      !skip   { print }' "$target" > "$tmp"
    mv "$tmp" "$target"
  else
    { if [ -s "$target" ]; then printf '\n'; fi; cat "$block"; } >> "$target"
  fi
}

# Remove the managed block; delete the file if nothing else is left in it.
remove_managed_block() {
  local target="$1" tmp
  [ -f "$target" ] || return 0
  grep -qxF "$MARK_BEGIN" "$target" || return 0
  tmp=$(mktemp)
  awk -v b="$MARK_BEGIN" -v e="$MARK_END" '
    $0 == b { skip = 1; next }
    $0 == e { skip = 0; next }
    !skip   { print }' "$target" > "$tmp"
  if grep -q '[^[:space:]]' "$tmp"; then mv "$tmp" "$target"; else rm -f "$tmp" "$target"; fi
}

# Split a comma list into lines; "all" and "detected" are handled by the caller.
split_list() { printf '%s\n' "$1" | tr ',' '\n' | sed '/^$/d'; }

is_in_list() { # $1 item, rest: list entries
  local item="$1"; shift
  local x
  for x in "$@"; do [ "$x" = "$item" ] && return 0; done
  return 1
}
