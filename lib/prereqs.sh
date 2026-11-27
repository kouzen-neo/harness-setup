#!/usr/bin/env bash
# Prerequisite checks. Required tools stop the installer; optional ones only change what can be installed.

readonly REQUIRED_TOOLS="git python3"
readonly OPTIONAL_TOOLS="node npm uv gh jq"

prereq_status() { # prints "name=found|missing" for every tool
  local t
  for t in $REQUIRED_TOOLS $OPTIONAL_TOOLS; do
    if command -v "$t" >/dev/null 2>&1; then echo "tool.$t=found"; else echo "tool.$t=missing"; fi
  done
}

check_required_tools() {
  local t missing=""
  for t in $REQUIRED_TOOLS; do
    command -v "$t" >/dev/null 2>&1 || missing="$missing $t"
  done
  [ -z "$missing" ] || die "missing required tools:$missing (install them first, see docs/INSTALL.md)"
}
