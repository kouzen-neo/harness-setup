# Install

## Prerequisites

Required (the installer stops without them):

- `git`
- `python3` 3.9 or newer (the session wrappers use only the standard library; developed on 3.14)
- `bash` (the scripts avoid bash-4-only features so macOS's default bash works; tested on bash 5)

Optional:

- `node` and `npm`: for MCP servers started with `npx`
- `uv`, `gh`, `jq`: used by some workflows and topics
- the CLIs the topics talk about: Vercel CLI, Android CLI and `adb`, `kdeconnect-cli`

You install the agent CLIs yourself, as each vendor documents, and you log in yourself. This repo does not install them and never handles credentials.

## Steps

```bash
git clone https://github.com/kouzen-neo/harness-setup.git ~/Documents/harness-setup && cd ~/Documents/harness-setup
./install.sh --detect                      # read-only: shows what is installed
mkdir -p ~/.config/harness-setup
cp config/example.env ~/.config/harness-setup/owner.env   # keep this file OUT of the repo
chmod 600 ~/.config/harness-setup/owner.env                # then edit it with your values
./install.sh --dry-run --env ~/.config/harness-setup/owner.env
./install.sh --env ~/.config/harness-setup/owner.env
./install.sh --check
```

Then open a new agent session and ask "What are your global rules?".

## Options

| Option | Meaning |
|---|---|
| `--harness LIST` | `claude,antigravity,opencode,codex,gemini`, or `detected` (default) or `all` |
| `--topics LIST` | rule topics to install (default: all) |
| `--optional LIST` | optional rule snippets, e.g. `no-ai-attribution,english-for-repos` |
| `--env FILE` | owner values (`KEY=value` lines; nothing in it is executed) |
| `--mcps FILE` | MCP servers to register (`name|type|command-or-url`) |
| `--overlay DIR` | private rules that replace or extend the repo's (see [RULES.md](RULES.md)) |
| `--rules-dir DIR` | where the detailed rule files go (default `~/.config/agent-rules`) |
| `--adopt` | take over an existing unmanaged folder or wrapper: it is backed up, then replaced |
| `--no-sessions` | skip the session wrappers |
| `--sudo-helpers` | install `agent-sudo-on`, `agent-sudo-off`, `agent-sudo-none` into the bin folder: short commands (any shell) that manage `/etc/sudoers.d/90-agent` so agents can run `sudo -n` without a password. You run them yourself and type your own password at the sudo prompt; nothing is stored. |
| `--no-mcp` | skip MCP registration |
| `--vault` | also set up the notes vault (clone or update `VAULT_BACKUP_REPO` into `VAULT_PATH`, or create a starter vault); see [OBSIDIAN.md](OBSIDIAN.md) |
| `--dry-run` | print what would happen, change nothing |
| `--yes` | do not ask for confirmation |
| `--detect`, `--check` | read-only reports |

## What it writes

- `~/.config/agent-rules/` (or `--rules-dir`): `CORE.md` and one file per topic.
- One **managed block** in each selected agent's global rules file. Anything else in that file is kept, and the block is replaced on the next run instead of duplicated.
- `~/.local/share/agent-session/` and the wrappers in `~/.local/bin/` (only for the selected agents).
- MCP servers, through each CLI's own `mcp add` command (skipped when a server with that name already exists).
- Backups of every file it changes: `~/.local/state/harness-setup/backups/<timestamp>/`.

## Update

```bash
git pull
./install.sh --env ~/.config/harness-setup/owner.env --yes
```

Re-running is safe: managed blocks are replaced, nothing is duplicated.

## Uninstall

```bash
./uninstall.sh --dry-run
./uninstall.sh
```

This removes the managed blocks (your own text in those files stays), the wrappers, and the folders the installer created. MCP servers and backups are left alone; remove servers with each CLI's `mcp remove`.
