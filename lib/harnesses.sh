#!/usr/bin/env bash
# One place that knows each harness: its command, its global rules file, and how it registers an MCP server.

readonly KNOWN_HARNESSES="claude antigravity opencode codex gemini"

harness_label() {
  case "$1" in
    claude) echo "Claude Code" ;;
    antigravity) echo "Antigravity CLI" ;;
    opencode) echo "OpenCode" ;;
    codex) echo "Codex CLI" ;;
    gemini) echo "Gemini CLI" ;;
    *) return 1 ;;
  esac
}

harness_binary() {
  case "$1" in
    claude) echo claude ;;
    antigravity) echo agy ;;
    opencode) echo opencode ;;
    codex) echo codex ;;
    gemini) echo gemini ;;
    *) return 1 ;;
  esac
}

harness_rules_file() {
  case "$1" in
    claude) echo "$HOME/.claude/CLAUDE.md" ;;
    antigravity) echo "$HOME/.gemini/AGENTS.md" ;;
    opencode) echo "$HOME/.config/opencode/instructions.md" ;;
    codex) echo "${CODEX_HOME:-$HOME/.codex}/AGENTS.md" ;;
    gemini) echo "$HOME/.gemini/GEMINI.md" ;;
    *) return 1 ;;
  esac
}

# Harnesses whose behaviour was checked against a real install of the CLI (the others are best effort).
harness_verified() {
  case "$1" in claude|antigravity|opencode) return 0 ;; *) return 1 ;; esac
}

harness_installed() { command -v "$(harness_binary "$1")" >/dev/null 2>&1; }

# First line of `<cli> --version`, or "unknown". Lets an agent notice when a CLI is newer than these instructions.
harness_version() { "$(harness_binary "$1")" --version 2>/dev/null | head -n 1 || true; }

# Capture the list first: with `pipefail`, `grep -q` closing the pipe early would make a successful match look like a failure.
mcp_exists() { # $1 harness, $2 server name
  local listing
  listing=$("$(harness_binary "$1")" mcp list 2>/dev/null || true)
  grep -qw -- "$2" <<<"$listing"
}

# $1 harness, $2 server name, $3 type (stdio|http), rest: command and args (stdio) or the URL (http)
harness_mcp_add() {
  local h="$1" name="$2" type="$3"
  shift 3
  case "$h:$type" in
    claude:stdio)      run claude mcp add --scope user "$name" -- "$@" ;;
    claude:http)       run claude mcp add --scope user --transport http "$name" "$1" ;;
    antigravity:stdio) run agy mcp add "$name" "$@" ;;
    antigravity:http)  run agy mcp add "$name" "$1" ;;
    opencode:stdio)    run opencode mcp add --global "$name" -- "$@" ;;
    opencode:http)     run opencode mcp add --global --url "$1" "$name" ;;
    codex:stdio)       run codex mcp add "$name" -- "$@" ;;
    codex:http)        run codex mcp add "$name" --url "$1" ;;
    gemini:stdio)      run gemini mcp add --scope user "$name" "$@" ;;
    gemini:http)       run gemini mcp add --scope user --transport http "$name" "$1" ;;
    *) warn "no MCP recipe for $h ($type)"; return 1 ;;
  esac
}
