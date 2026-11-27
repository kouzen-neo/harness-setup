# harness-setup

One shared set of rules, session wrappers, and MCP servers for your coding-agent CLIs, installed with one bash script.

Instead of keeping a different instruction file in every tool, you keep **one short core file per agent** that points to **detailed topic files** the agent reads only when the task needs them. The same repo also gives the agents a common way to open sessions in each other, and registers the MCP servers you choose in all of them.

## What you get

- **Global rules** for each agent: a short "always" list plus topic files (code quality, new projects, library docs, shared notes, agent control, Vercel and domains, Android and phone).
- **Session wrappers** (`agy-session`, `claude-session`, `opencode-session`) with the same verbs, so one agent can start and message another. No default model on purpose: you choose.
- **MCP registration** from a plain list (`name|type|command-or-url`).
- **Safe by design**: managed blocks (your own rules stay), backups before every change, dry-run, check, and uninstall. The installer never reads or writes credentials.

## Quick start

```bash
git clone https://github.com/kouzen-neo/harness-setup.git ~/Documents/harness-setup && cd ~/Documents/harness-setup
./install.sh --detect            # what this machine has
./install.sh --dry-run           # what would change
./install.sh                     # install (asks before changing anything)
./install.sh --check             # verify later
```

Put your own values (language, shell, domain, ...) in a private file and pass it with `--env`; see [docs/INSTALL.md](docs/INSTALL.md).

## Let an agent install it for you

Open your agent in any folder and paste:

```text
Clone https://github.com/kouzen-neo/harness-setup.git into ~/Documents/harness-setup (if that folder already exists, run git pull there instead),
read AGENTS.md in it, and install harness-setup on this machine for me.
Ask me the questions it lists before you change anything, show me the dry-run, and wait for my OK.
Never ask me to paste a password, token, or API key into the chat.
```

[AGENTS.md](AGENTS.md) tells the agent exactly what to ask and what it must not do.

## Supported agents

| Agent | Rules file the installer manages | Status |
|---|---|---|
| Claude Code | `~/.claude/CLAUDE.md` | verified on a real install |
| Antigravity CLI (`agy`) | `~/.gemini/AGENTS.md` | verified on a real install |
| OpenCode | `~/.config/opencode/instructions.md` (must be listed in `opencode.jsonc`) | verified on a real install |
| Codex CLI | `~/.codex/AGENTS.md` | best effort, not verified |
| Gemini CLI | `~/.gemini/GEMINI.md` | best effort, not verified |

Details, MCP commands, and other tools that read a repo-level `AGENTS.md`: [docs/HARNESSES.md](docs/HARNESSES.md).

## Requirements

`git`, `python3` (3.9+), and `bash`. Optional: `node`/`npm` (for `npx`-based MCP servers), `uv`, `gh`, `jq`. You install the agent CLIs yourself, as each vendor documents, and log in yourself. See [docs/INSTALL.md](docs/INSTALL.md).

## Customize

- **Owner values**: copy `config/example.env`, fill it in, keep it out of the repo, pass `--env FILE`.
- **MCP servers**: copy `config/mcps.example.conf`, edit, pass `--mcps FILE`.
- **Private rules**: a private folder with `rules/` files (an overlay) replaces or extends the repo's rules: `--overlay DIR`.
- **Optional rules**: `--optional no-ai-attribution,english-for-repos`.
- **Topics**: `--topics code-quality,new-project` installs only some.

More in [docs/RULES.md](docs/RULES.md).

## Documentation

| | |
|---|---|
| [docs/INSTALL.md](docs/INSTALL.md) | prerequisites, options, update, uninstall |
| [docs/HARNESSES.md](docs/HARNESSES.md) | per-agent paths and MCP commands |
| [docs/RULES.md](docs/RULES.md) | how the rules, templates, overlays, and topics work |
| [docs/SESSIONS.md](docs/SESSIONS.md) | the session wrappers |
| [docs/SECURITY.md](docs/SECURITY.md) | what is and is not stored |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | common problems |

## Development

```bash
tests/run.sh                                              # installer tests (sandboxed HOME, stub CLIs)
(cd sessions/agent-session && python3 -m unittest discover -s tests -t .)   # wrapper tests
tools/scan-secrets.sh --forbid ~/private-words.txt        # run before publishing
```

## Layout

```text
install.sh  uninstall.sh      entry points
lib/                          bash helpers (harnesses, steps, rendering)
rules/                        CORE.md, topics/, optional/ (templates with {{PLACEHOLDERS}})
config/                       example.env, mcps.example.conf
sessions/agent-session/       Python session wrappers and their tests
tests/  tools/                installer tests, secret scanner
docs/  AGENTS.md              documentation, instructions for agents
```

## License

MIT, see [LICENSE](LICENSE).
