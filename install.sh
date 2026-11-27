#!/usr/bin/env bash
# harness-setup installer: global rules, session wrappers and MCP servers for your coding-agent CLIs.
# Run `./install.sh --help` for options. Nothing here reads or writes credentials.
set -eo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$ROOT/lib/common.sh"
. "$ROOT/lib/harnesses.sh"
. "$ROOT/lib/prereqs.sh"
. "$ROOT/lib/steps.sh"

readonly DEFAULT_RULES_DIR="$HOME/.config/agent-rules"
readonly DEFAULT_SESSIONS_DIR="$HOME/.local/share/agent-session"
readonly DEFAULT_BIN_DIR="$HOME/.local/bin"
readonly DEFAULT_BACKUP_ROOT="$HOME/.local/state/harness-setup/backups"

usage() {
  cat <<USAGE
Usage: install.sh [options]

  --harness LIST     comma list of: $KNOWN_HARNESSES; or "detected" (default) or "all"
  --topics LIST      comma list of rule topics, or "all" (default)
  --optional LIST    optional rule snippets to add (see rules/optional/)
  --env FILE         owner values as KEY=value lines (see config/example.env)
  --mcps FILE        MCP servers to register (see config/mcps.example.conf)
  --overlay DIR      private folder whose rules/ files replace or extend the repo's
  --rules-dir DIR    where the detailed rule files go (default: $DEFAULT_RULES_DIR)
  --adopt            take over an existing unmanaged folder (it is backed up first)
  --no-sessions      do not install the session wrappers
  --no-mcp           do not register MCP servers
  --dry-run          show what would happen, change nothing
  --yes              do not ask for confirmation
  --detect           print what this machine has (for agents), then exit
  --check            verify an existing install, then exit
USAGE
}

parse_args() {
  HARNESS_ARG=detected; TOPIC_ARG=all; OPTIONAL_ARG=""; ENV_FILE=""; MCPS_FILE="$ROOT/config/mcps.example.conf"
  OVERLAY=""; RULES_DIR="$DEFAULT_RULES_DIR"; SESSIONS_DIR="$DEFAULT_SESSIONS_DIR"; BIN_DIR="$DEFAULT_BIN_DIR"
  ADOPT=0; NO_SESSIONS=0; NO_MCP=0; DRY_RUN=0; ASSUME_YES=0; MODE=install
  while [ $# -gt 0 ]; do
    case "$1" in
      --harness) HARNESS_ARG="${2:?--harness needs a value}"; shift ;;
      --topics) TOPIC_ARG="${2:?--topics needs a value}"; shift ;;
      --optional) OPTIONAL_ARG="${2:?--optional needs a value}"; shift ;;
      --env) ENV_FILE="${2:?--env needs a file}"; shift ;;
      --mcps) MCPS_FILE="${2:?--mcps needs a file}"; shift ;;
      --overlay) OVERLAY="${2:?--overlay needs a folder}"; shift ;;
      --rules-dir) RULES_DIR="${2:?--rules-dir needs a folder}"; shift ;;
      --adopt) ADOPT=1 ;;
      --no-sessions) NO_SESSIONS=1 ;;
      --no-mcp) NO_MCP=1 ;;
      --dry-run) DRY_RUN=1 ;;
      --yes) ASSUME_YES=1 ;;
      --detect) MODE=detect ;;
      --check) MODE=check ;;
      -h|--help) usage; exit 0 ;;
      *) usage >&2; die "unknown option: $1" ;;
    esac
    shift
  done
  RULES_DIR="${RULES_DIR/#\~/$HOME}"
  [ -z "$OVERLAY" ] || [ -d "$OVERLAY" ] || die "overlay folder not found: $OVERLAY"
  BACKUP_DIR="${HARNESS_SETUP_BACKUPS:-$DEFAULT_BACKUP_ROOT}/$(date +%Y%m%d-%H%M%S)"
  export DRY_RUN
}

confirm() {
  [ "$DRY_RUN" = 1 ] || [ "$ASSUME_YES" = 1 ] || {
    printf 'Proceed? [y/N] '
    read -r answer
    [ "$answer" = y ] || [ "$answer" = Y ] || die "cancelled"
  }
}

main() {
  parse_args "$@"
  [ -z "$ENV_FILE" ] || load_env "$ENV_FILE"
  case "$MODE" in
    detect) run_detect; return 0 ;;
    check) run_check; return $? ;;
  esac
  check_required_tools
  select_harnesses; select_topics; select_optionals
  show_plan
  confirm
  prepare_core
  install_rules
  install_core_files
  install_sessions
  register_mcps
  rm -f "$CORE_TMP"
  show_next_steps
}

main "$@"
