# Security

## What this repo never contains or does

- No credentials: no tokens, API keys, passwords, or device identifiers, in any file or example.
- The installer never reads credential files and never asks for a secret. Logging in to each CLI is always your own step.
- The env file you pass with `--env` is parsed as plain `KEY=value` lines; nothing in it is executed.
- MCP servers are registered from a list you control. Servers that need a key are configured by you by hand.

## What it changes on your machine

Only the paths listed in [INSTALL.md](INSTALL.md). Every existing file is backed up to `~/.local/state/harness-setup/backups/<timestamp>/` before it is changed, and `./uninstall.sh --dry-run` shows what removal would do.

## Before you publish your own copy

Your private values (name, domain, repo names) belong in your own env file and overlay, never in this repo. Run the scanner on the folder you are about to publish:

```bash
# words.txt: one word per line (your name, domain, email); keep it outside the repo
tools/scan-secrets.sh --forbid ~/words.txt
```

It flags credential-looking strings, personal paths such as `/home/<user>/`, and any word from your list.

## If you pasted a secret into an agent chat

Rotate it. Deleting local files does not remove it from the chat history.

## Delegated sessions

`yolo` and other auto-approval levels let another agent run commands without asking. Use them only in a project folder you trust, and keep the rule that you never delegate what the delegating agent may not do itself.
