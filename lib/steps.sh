#!/usr/bin/env bash
# Installer steps. Expects ROOT, BACKUP_DIR and the option variables set by install.sh.

readonly SESSION_ADAPTERS="claude antigravity opencode"
readonly OPENCODE_CONFIGS="$HOME/.config/opencode/opencode.jsonc $HOME/.config/opencode/opencode.json"

rule_source() { # $1 path relative to rules/ ; an overlay file wins over the repo file
  if [ -n "${OVERLAY-}" ] && [ -f "$OVERLAY/rules/$1" ]; then echo "$OVERLAY/rules/$1"; else echo "$ROOT/rules/$1"; fi
}

list_topics() {
  local f dir
  for dir in "$ROOT/rules/topics" "${OVERLAY:+$OVERLAY/rules/topics}"; do
    [ -n "$dir" ] || continue
    for f in "$dir"/*.md; do [ -e "$f" ] && basename "$f" .md; done
  done | sort -u
}

wrapper_name() { # session wrapper command for a harness
  case "$1" in claude) echo claude-session ;; antigravity) echo agy-session ;; opencode) echo opencode-session ;; esac
}

wrapper_adapter() {
  case "$1" in claude) echo claude ;; antigravity) echo agy ;; opencode) echo opencode ;; esac
}

select_harnesses() {
  local h
  SELECTED=()
  case "$HARNESS_ARG" in
    all) for h in $KNOWN_HARNESSES; do SELECTED+=("$h"); done ;;
    detected) for h in $KNOWN_HARNESSES; do if harness_installed "$h"; then SELECTED+=("$h"); fi; done ;;
    *) while IFS= read -r h; do
         is_in_list "$h" $KNOWN_HARNESSES || die "unknown harness: $h (known: $KNOWN_HARNESSES)"
         SELECTED+=("$h")
       done < <(split_list "$HARNESS_ARG") ;;
  esac
  [ "${#SELECTED[@]}" -gt 0 ] || die "no harness selected: none of ($KNOWN_HARNESSES) was found; install one or pass --harness"
}

select_topics() {
  local t available
  TOPICS=()
  available=$(list_topics)
  if [ "$TOPIC_ARG" = all ]; then
    while IFS= read -r t; do TOPICS+=("$t"); done <<<"$available"
  else
    while IFS= read -r t; do
      grep -qx -- "$t" <<<"$available" || die "unknown topic: $t (available: $(echo $available))"
      TOPICS+=("$t")
    done < <(split_list "$TOPIC_ARG")
  fi
}

select_optionals() {
  local o
  OPTIONALS=()
  [ -n "$OPTIONAL_ARG" ] || return 0
  while IFS= read -r o; do
    [ -f "$(rule_source "optional/$o.md")" ] || die "unknown optional rule: $o"
    OPTIONALS+=("$o")
  done < <(split_list "$OPTIONAL_ARG")
}

compute_shell_note() {
  SHELL_NAME="${SHELL_NAME:-$(basename "${SHELL:-bash}")}"
  if [ "$SHELL_NAME" = fish ]; then
    SHELL_NOTE="The owner's login shell is fish: when giving commands to paste into their terminal, use fish syntax (\`set -x VAR value\`, \`read -s -x -g VAR\`, \`; and\` / \`; or\` instead of \`&&\` / \`||\`) or wrap them as \`bash -c '...'\`."
  else
    SHELL_NOTE="The owner's login shell is $SHELL_NAME: when giving commands to paste into their terminal, use that shell's syntax."
  fi
}

# Render CORE.md (with the topic index and the optional rules) into $CORE_TMP.
prepare_core() {
  local t when index="" opt="" o
  for t in "${TOPICS[@]}"; do
    when=$(sed -n '1s/^<!-- when: \(.*\) -->$/\1/p' "$(rule_source "topics/$t.md")")
    [ -n "$when" ] || when="Work related to $t"
    index="$index- $when: \`$t.md\`"$'\n'
  done
  for o in "${OPTIONALS[@]}"; do opt="$opt$(cat "$(rule_source "optional/$o.md")")"$'\n'; done
  compute_shell_note
  OWNER_LANGUAGE="${OWNER_LANGUAGE:-the language the owner writes in}"
  CORE_TMP=$(mktemp)
  TOPIC_INDEX="${index%$'\n'}" OPTIONAL_RULES="${opt%$'\n'}" RULES_DIR_SHOWN="$RULES_DIR" ALLOW_EMPTY="OPTIONAL_RULES" \
    render_template "$(rule_source CORE.md)" > "$CORE_TMP"
}

guard_managed_dir() { # $1 dir ; refuse to touch a folder this tool did not create; with --adopt it is backed up and replaced
  local dir="$1"
  [ -d "$dir" ] || return 0
  [ -f "$dir/$MANAGED_FILE" ] && return 0
  [ -z "$(find "$dir" -mindepth 1 -maxdepth 1 2>/dev/null | head -n 1)" ] && return 0
  if [ "$ADOPT" = 1 ]; then
    run mkdir -p "$BACKUP_DIR"
    run cp -R "$dir" "$BACKUP_DIR/$(basename "$dir").adopted"
    run rm -rf "$dir"
    return 0
  fi
  die "$dir already exists and was not created by harness-setup; move it, choose another path, or pass --adopt (it is backed up first)"
}

install_rules() {
  local t src
  guard_managed_dir "$RULES_DIR"
  run mkdir -p "$RULES_DIR"
  if [ -f "$RULES_DIR/$MANAGED_FILE" ]; then run find "$RULES_DIR" -maxdepth 1 -name '*.md' -delete; fi
  for t in "${TOPICS[@]}"; do
    src=$(rule_source "topics/$t.md")
    if [ "${DRY_RUN:-0}" = 1 ]; then log "[dry-run] render topic $t -> $RULES_DIR/$t.md"
    else RULES_DIR_SHOWN="$RULES_DIR" render_template "$src" > "$RULES_DIR/$t.md"; fi
  done
  run cp "$CORE_TMP" "$RULES_DIR/CORE.md"
  run touch "$RULES_DIR/$MANAGED_FILE"
  log "rules: $RULES_DIR (${#TOPICS[@]} topics)"
}

check_opencode_registration() { # $1 rules file
  local cfg
  for cfg in $OPENCODE_CONFIGS; do
    [ -f "$cfg" ] && grep -qF "$1" "$cfg" && return 0
  done
  warn "OpenCode only reads $1 if it is listed in the \"instructions\" array of opencode.jsonc; add it there"
}

install_core_files() {
  local block h target
  block=$(mktemp)
  { printf '%s\n' "$MARK_BEGIN"
    printf '%s\n' '<!-- managed by harness-setup: change the rules in the harness-setup folder, then run install.sh again -->'
    cat "$CORE_TMP"
    printf '%s\n' "$MARK_END"; } > "$block"
  for h in "${SELECTED[@]}"; do
    target=$(harness_rules_file "$h")
    write_managed_block "$target" "$block"
    log "core rules: $(harness_label "$h") -> $target"
    if [ "$h" = opencode ]; then check_opencode_registration "$target"; fi
  done
  rm -f "$block"
}

write_wrapper() { # $1 command name, $2 adapter
  local path="$BIN_DIR/$1"
  if [ -e "$path" ] && ! grep -q 'managed by harness-setup' "$path"; then
    if [ "$ADOPT" = 1 ]; then
      backup_file "$path"
    else
      warn "$path exists and is not managed by harness-setup; skipped (use --adopt to replace it, backed up first)"
      return 0
    fi
  fi
  if [ "${DRY_RUN:-0}" = 1 ]; then log "[dry-run] write wrapper $path"; return 0; fi
  printf '#!/usr/bin/env bash\n# managed by harness-setup\nexec python3 "%s/cli.py" %s "$@"\n' "$SESSIONS_DIR" "$2" > "$path"
  chmod +x "$path"
}

install_sessions() {
  local h
  [ "$NO_SESSIONS" = 1 ] && return 0
  guard_managed_dir "$SESSIONS_DIR"
  [ -n "$SESSIONS_DIR" ] || die "empty sessions dir"
  run rm -rf "$SESSIONS_DIR"
  run mkdir -p "$SESSIONS_DIR" "$BIN_DIR"
  run cp -R "$ROOT/sessions/agent-session/." "$SESSIONS_DIR/"
  run touch "$SESSIONS_DIR/$MANAGED_FILE"
  for h in "${SELECTED[@]}"; do
    is_in_list "$h" $SESSION_ADAPTERS || continue
    write_wrapper "$(wrapper_name "$h")" "$(wrapper_adapter "$h")"
    log "session wrapper: $(wrapper_name "$h")"
  done
  case ":$PATH:" in *":$BIN_DIR:"*) ;; *) warn "$BIN_DIR is not on PATH; add it to your shell profile" ;; esac
}

register_mcps() {
  local line name type rest h argv
  [ "$NO_MCP" = 1 ] && return 0
  [ -f "$MCPS_FILE" ] || die "MCP list not found: $MCPS_FILE"
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac
    IFS='|' read -r name type rest <<<"$line"
    rest="${rest/#\~/$HOME}"
    for h in "${SELECTED[@]}"; do
      harness_installed "$h" || continue
      if mcp_exists "$h" "$name"; then log "mcp $name: already registered in $h"; continue; fi
      if [ "$type" = http ]; then
        harness_mcp_add "$h" "$name" http "$rest" || true
      else
        read -r -a argv <<<"$rest"
        harness_mcp_add "$h" "$name" stdio "${argv[@]}" || true
      fi
    done
  done < "$MCPS_FILE"
}

show_plan() {
  local h
  log "Plan:"
  for h in "${SELECTED[@]}"; do
    log "  - $(harness_label "$h"): $(harness_rules_file "$h")$(harness_verified "$h" || echo ' (best effort, not verified)')"
  done
  log "  - topics: ${TOPICS[*]}"
  log "  - optional rules: ${OPTIONALS[*]:-none}"
  log "  - rules folder: $RULES_DIR"
  log "  - session wrappers: $([ "$NO_SESSIONS" = 1 ] && echo skipped || echo "$SESSIONS_DIR")"
  log "  - MCP servers from: $([ "$NO_MCP" = 1 ] && echo skipped || echo "$MCPS_FILE")"
  log "  - backups of changed files: $BACKUP_DIR"
}

show_next_steps() {
  log ""
  log "Done. Next steps (these are yours; the installer never handles credentials):"
  log "  1. Log in to each agent CLI yourself (for example: claude, agy, opencode, gh auth login, vercel login)."
  log "  2. Open a new agent session and ask it: \"What are your global rules?\" to confirm they load."
  log "  3. Check the install any time with: $ROOT/install.sh --check"
}

run_detect() {
  local h
  echo "os=$(uname -s)"
  echo "shell=$(basename "${SHELL:-unknown}")"
  echo "bash=${BASH_VERSION}"
  for h in $KNOWN_HARNESSES; do
    if harness_installed "$h"; then
      echo "harness.$h=installed"
      echo "harness.$h.version=$(harness_version "$h")"
    else
      echo "harness.$h=missing"
    fi
  done
  prereq_status
  echo "rules_dir.exists=$([ -d "$RULES_DIR" ] && echo yes || echo no)"
}

run_check() {
  local h target bad=0
  [ -f "$RULES_DIR/CORE.md" ] && echo "ok: $RULES_DIR/CORE.md" || { echo "MISSING: $RULES_DIR/CORE.md"; bad=1; }
  for h in $KNOWN_HARNESSES; do
    harness_installed "$h" || continue
    target=$(harness_rules_file "$h")
    if [ -f "$target" ] && grep -qxF "$MARK_BEGIN" "$target"; then echo "ok: $(harness_label "$h") rules ($target)"
    else echo "MISSING: $(harness_label "$h") rules block ($target)"; bad=1; fi
    if [ -n "$(wrapper_name "$h")" ]; then
      [ -x "$BIN_DIR/$(wrapper_name "$h")" ] && echo "ok: $(wrapper_name "$h")" || { echo "MISSING: $(wrapper_name "$h")"; bad=1; }
    fi
  done
  return $bad
}
