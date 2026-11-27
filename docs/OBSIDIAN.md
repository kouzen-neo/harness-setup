# Notes vault and Obsidian

A notes vault is a folder of markdown files. You read and edit it in [Obsidian](https://obsidian.md); your coding agents read and write the same files. It is how every agent sees what the others learned (the `shared-memory` rule topic).

You do not need an MCP server for this: without one, agents edit the markdown files directly. An MCP server that searches and writes notes is optional; register one through your MCP list if you have it.

## 1. Install Obsidian

The installer never installs Obsidian for you (`./install.sh --detect` reports `obsidian=installed|missing`). Pick one:

- Download it from the official site: <https://obsidian.md>
- Linux: Flatpak `md.obsidian.Obsidian`, or the `obsidian` package on Arch (AUR)
- macOS: Homebrew cask `obsidian`
- Windows: winget package `Obsidian.Obsidian`

Package names change; if one is not found, use the official download.

## 2. Create the vault

Put the location (and, optionally, a backup repo) in your env file, then run the installer with `--vault`:

```text
VAULT_PATH=~/Documents/Notes
VAULT_BACKUP_REPO=your-github-name/your-notes-repo
```

```bash
./install.sh --dry-run --vault --env ~/.config/harness-setup/owner.env
./install.sh --vault --env ~/.config/harness-setup/owner.env
```

What `--vault` does depends on what is at `VAULT_PATH`:

| Situation | Result |
|---|---|
| Folder missing or empty, `VAULT_BACKUP_REPO` set | clones the repo there (`owner/name` uses `gh` and needs `gh auth login`; a full git URL uses `git`) |
| Folder missing or empty, no backup repo | creates a **starter vault** from `templates/vault/` |
| Already a git clone | fast-forwards it (`git pull --ff-only`); a vault with uncommitted changes is not touched |
| Has files, not a git clone | left alone; copy `AI Index.md` and `Shared/Agent Memory/INDEX.md` from `templates/vault/` by hand |

It never pushes and never overwrites a file.

## 3. Open it in Obsidian

Open Obsidian, choose **Open folder as vault**, and select `VAULT_PATH`. Notes that agents create appear on their own, because Obsidian watches the folder.

## 4. Layout

```text
AI Index.md                    entry point for agents; links the projects
Shared/Agent Memory/INDEX.md   one line per shared note
Shared/Agent Memory/<name>.md  one fact per note
<project>/...                  your own project notes
```

A shared note looks like this:

```markdown
---
name: prefers-small-commits
description: The owner wants one commit per purpose
agent: claude
type: feedback
updated: 2026-01-31
---

Keep commits small and focused.

**Why:** easier to review and revert.
**How to apply:** never mix cleanup into a feature commit.
```

and gets one line in the index: `- [[prefers-small-commits]] - one commit per purpose`.

## 5. Back it up with git

```bash
cd "$VAULT_PATH"
git init
git add -A && git commit -m "Initial vault"
gh repo create your-notes-repo --private --source . --push
```

- Keep the repo **private**. Notes should never contain secrets, but they are personal.
- The starter `.gitignore` keeps per-device Obsidian state (`workspace.json`, cache, trash) out of the repo.
- On another machine, set `VAULT_BACKUP_REPO` and run `./install.sh --vault`; later runs fast-forward it.

## 6. How the agents use it

The `shared-memory` topic tells every agent to read `AI Index.md` and `Shared/Agent Memory/INDEX.md` at the start of work, write durable facts as one note each, update the index, never write secrets, and never push the vault. See [RULES.md](RULES.md) to change the rule or add your own.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Obsidian shows an empty vault | You opened the wrong folder; open `VAULT_PATH` itself, not its parent |
| Agents do not seem to know the vault | `VAULT_PATH` is missing or wrong in the env file; fix it and run the installer again |
| `vault ... has uncommitted changes; not pulling` | Commit or stash your changes, then run again |
| `vault not cloned: log in yourself` | Run `gh auth login`, or set `VAULT_BACKUP_REPO` to a full git URL |
