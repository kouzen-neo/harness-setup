#!/usr/bin/env bash
# Installer tests. Every test runs in a throwaway HOME with stub agent CLIs; nothing real is touched.
# Run: tests/run.sh
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

ok()   { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }
check() { # $1 description, rest: a command that must succeed
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$desc"; else fail "$desc"; fi
}

new_sandbox() {
  TMP=$(mktemp -d)
  export HOME="$TMP/home" CALLS="$TMP/calls.log" SHELL=/usr/bin/fish
  export HARNESS_SETUP_BACKUPS="$TMP/backups"
  mkdir -p "$HOME" "$TMP/bin"
  : > "$CALLS"
  for cli in claude agy opencode; do
    cat > "$TMP/bin/$cli" <<STUB
#!/usr/bin/env bash
echo "$cli \$*" >> "\$CALLS"
if [ "\$1 \$2" = "mcp list" ]; then grep "^$cli mcp add" "\$CALLS" | tr ' ' '\n'; fi
exit 0
STUB
    chmod +x "$TMP/bin/$cli"
  done
  export PATH="$TMP/bin:$ROOT/tests/emptybin:/usr/bin:/bin"
  cat > "$TMP/owner.env" <<ENV
OWNER_LANGUAGE=Indonesian
SHELL_NAME=fish
DOMAIN=example.test
DNS_PROVIDER=Cloudflare
VERCEL_TEAM=team-x
VAULT_PATH=~/Notes
VAULT_BACKUP_REPO=me/notes
ENV
}

inst() { "$ROOT/install.sh" --yes --env "$TMP/owner.env" "$@"; }
count_markers() { grep -cxF '<!-- harness-setup:begin -->' "$1"; }

mkdir -p "$ROOT/tests/emptybin"

# 1. detect
new_sandbox
check "detect lists installed harnesses" bash -c "'$ROOT/install.sh' --detect | grep -qx 'harness.claude=installed'"
check "detect lists missing harnesses" bash -c "'$ROOT/install.sh' --detect | grep -qx 'harness.codex=missing'"

# 2. dry run changes nothing
inst --dry-run >/dev/null 2>&1
check "dry-run writes no rules" test ! -e "$HOME/.claude/CLAUDE.md"
check "dry-run creates no rules folder" test ! -e "$HOME/.config/agent-rules"

# 3. real install, rendering, optional rules
inst --optional no-ai-attribution,english-for-repos >/dev/null 2>&1
for f in .claude/CLAUDE.md .gemini/AGENTS.md .config/opencode/instructions.md; do
  check "core rules written: $f" grep -qxF '<!-- harness-setup:begin -->' "$HOME/$f"
done
check "owner language rendered" grep -q 'Indonesian' "$HOME/.claude/CLAUDE.md"
check "fish note rendered" grep -q 'fish syntax' "$HOME/.claude/CLAUDE.md"
check "optional rules included" grep -q 'Co-Authored-By' "$HOME/.claude/CLAUDE.md"
check "topic index lists vercel topic" grep -q 'vercel-and-domains.md' "$HOME/.claude/CLAUDE.md"
check "topic file rendered with owner values" grep -q 'example.test' "$HOME/.config/agent-rules/vercel-and-domains.md"
check "no unresolved placeholders left in core" bash -c "! grep -q '{{' '$HOME/.claude/CLAUDE.md'"

# 4. idempotent
cp "$HOME/.claude/CLAUDE.md" "$TMP/first.md"
inst --optional no-ai-attribution,english-for-repos >/dev/null 2>&1
check "second run keeps one block" test "$(count_markers "$HOME/.claude/CLAUDE.md")" = 1
check "second run leaves the file identical" cmp -s "$HOME/.claude/CLAUDE.md" "$TMP/first.md"

# 5. wrappers and MCP
check "claude wrapper is executable" test -x "$HOME/.local/bin/claude-session"
check "agy wrapper is managed" grep -q 'managed by harness-setup' "$HOME/.local/bin/agy-session"
check "MCP registered once" test "$(grep -c 'claude mcp add' "$CALLS")" = 1
check "MCP uses the http recipe" grep -q 'claude mcp add --scope user --transport http context7 https://mcp.context7.com/mcp' "$CALLS"
check "check mode passes after install" "$ROOT/install.sh" --check

# 6. user content survives, backups, uninstall
new_sandbox
mkdir -p "$HOME/.config/opencode"
printf '# My own rule\n' > "$HOME/.config/opencode/instructions.md"
inst >/dev/null 2>&1
check "user content kept next to the block" grep -q 'My own rule' "$HOME/.config/opencode/instructions.md"
check "existing file was backed up" bash -c "ls '$HARNESS_SETUP_BACKUPS'/*/ | grep -q instructions.md"
"$ROOT/uninstall.sh" >/dev/null 2>&1
check "uninstall removes the block but keeps user content" bash -c "grep -q 'My own rule' '$HOME/.config/opencode/instructions.md' && ! grep -q 'harness-setup:begin' '$HOME/.config/opencode/instructions.md'"
check "uninstall removes created files" test ! -e "$HOME/.claude/CLAUDE.md"
check "uninstall removes the rules folder" test ! -e "$HOME/.config/agent-rules"
check "uninstall removes wrappers" test ! -e "$HOME/.local/bin/claude-session"

# 7. safety
new_sandbox
mkdir -p "$HOME/.config/agent-rules" && echo mine > "$HOME/.config/agent-rules/own.md"
check "unmanaged rules folder is refused" bash -c "! '$ROOT/install.sh' --yes --env '$TMP/owner.env' >/dev/null 2>&1"
check "unmanaged folder untouched after refusal" test -f "$HOME/.config/agent-rules/own.md"
check "adopt backs it up and proceeds" bash -c "'$ROOT/install.sh' --yes --adopt --env '$TMP/owner.env' >/dev/null 2>&1 && ls '$HARNESS_SETUP_BACKUPS'/*/ | grep -q adopted"
new_sandbox
printf 'DOMAIN=$(touch %s/pwned)\nbad line\n' "$TMP" > "$TMP/evil.env"
"$ROOT/install.sh" --yes --env "$TMP/evil.env" >/dev/null 2>&1
check "env file is never executed" test ! -e "$TMP/pwned"
check "unresolved owner value is shown as ask-the-owner" bash -c "grep -q 'is not set: ask the owner' '$HOME/.config/agent-rules/android-phone.md' || grep -q 'VERCEL_TEAM is not set' '$HOME/.config/agent-rules/vercel-and-domains.md'"
check "unknown harness fails" bash -c "! '$ROOT/install.sh' --yes --harness nope >/dev/null 2>&1"
check "unknown topic fails" bash -c "! '$ROOT/install.sh' --yes --topics nope >/dev/null 2>&1"

# 8. overlay wins over the repo files
new_sandbox
mkdir -p "$TMP/overlay/rules/topics"
printf '<!-- when: Private topic -->\n# Private\nOVERLAY-MARKER\n' > "$TMP/overlay/rules/topics/new-project.md"
inst --overlay "$TMP/overlay" >/dev/null 2>&1
check "overlay topic replaces the repo topic" grep -q 'OVERLAY-MARKER' "$HOME/.config/agent-rules/new-project.md"
check "overlay description is used in the index" grep -q 'Private topic' "$HOME/.claude/CLAUDE.md"

# 10. adopting an old setup: stale files are replaced, wrappers are backed up
new_sandbox
mkdir -p "$HOME/.config/agent-rules" "$HOME/.local/bin"
echo old > "$HOME/.config/agent-rules/old-topic.md"
printf '#!/bin/sh\necho old wrapper\n' > "$HOME/.local/bin/claude-session"; chmod +x "$HOME/.local/bin/claude-session"
inst --adopt >/dev/null 2>&1
check "adopt removes the stale old topic" test ! -e "$HOME/.config/agent-rules/old-topic.md"
check "adopt keeps a backup of the old folder" bash -c "ls -d '$HARNESS_SETUP_BACKUPS'/*/agent-rules.adopted >/dev/null"
check "adopt replaces an unmanaged wrapper" grep -q 'managed by harness-setup' "$HOME/.local/bin/claude-session"
check "adopt backs up the replaced wrapper" bash -c "ls '$HARNESS_SETUP_BACKUPS'/*/ | grep -q claude-session"
inst --topics code-quality >/dev/null 2>&1
check "re-install with fewer topics removes dropped topic files" test ! -e "$HOME/.config/agent-rules/vercel-and-domains.md"
new_sandbox
check "detect prints a version line for installed CLIs" bash -c "'$ROOT/install.sh' --detect | grep -q '^harness.claude.version='"

# 11. regression: a long `mcp list` that names the server first must still be seen as "already registered"
new_sandbox
cat > "$TMP/bin/claude" <<STUB
#!/usr/bin/env bash
echo "claude \$*" >> "\$CALLS"
if [ "\$1 \$2" = "mcp list" ]; then echo "context7 connected"; seq 1 200000; fi
exit 0
STUB
inst --harness claude >/dev/null 2>&1
check "an existing server is not registered again (long list, early match)" bash -c "! grep -q 'claude mcp add' '$CALLS'"

# 9. secret scanner
SCAN="$ROOT/tools/scan-secrets.sh"
new_sandbox
mkdir -p "$TMP/clean" "$TMP/dirty"
printf 'nothing secret here\n' > "$TMP/clean/a.txt"
fake_token="hf_$(printf 'a%.0s' $(seq 1 24))"
printf 'key = %s\n' "$fake_token" > "$TMP/dirty/b.txt"
printf 'path %s/someone/project\n' "/ho""me" > "$TMP/dirty/c.txt"
printf 'MyPrivateName\n' > "$TMP/words.txt"
printf 'written by MyPrivateName\n' > "$TMP/dirty/d.txt"
check "scanner passes a clean folder" "$SCAN" "$TMP/clean"
check "scanner flags a credential-like string" bash -c "! '$SCAN' '$TMP/dirty' >/dev/null 2>&1"
check "scanner flags a personal path" bash -c "'$SCAN' '$TMP/dirty' 2>&1 | grep -q 'personal path'"
mkdir -p "$TMP/onlyword" && cp "$TMP/dirty/d.txt" "$TMP/onlyword/"
check "scanner exits non-zero on a forbidden word" bash -c "! '$SCAN' --forbid '$TMP/words.txt' '$TMP/onlyword' >/dev/null 2>&1"
check "scanner ignores forbidden words that are absent" "$SCAN" --forbid "$TMP/words.txt" "$TMP/clean"
check "scanner finds the forbidden word where it is" bash -c "'$SCAN' --forbid '$TMP/words.txt' '$TMP/dirty' 2>&1 | grep -q 'forbidden word'"
check "the repo itself is clean" "$SCAN"

rmdir "$ROOT/tests/emptybin" 2>/dev/null
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
