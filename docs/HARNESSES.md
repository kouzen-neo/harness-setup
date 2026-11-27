# Agents (harnesses)

Each agent has a global rules file it loads in every session. The installer writes a managed block into it.

| Agent | Command | Rules file | MCP command the installer uses | Status |
|---|---|---|---|---|
| Claude Code | `claude` | `~/.claude/CLAUDE.md` | `claude mcp add --scope user ...` | verified on a real install |
| Antigravity CLI | `agy` | `~/.gemini/AGENTS.md` | `agy mcp add ...` | verified on a real install |
| OpenCode | `opencode` | `~/.config/opencode/instructions.md` | `opencode mcp add --global ...` | verified on a real install |
| Codex CLI | `codex` | `${CODEX_HOME:-~/.codex}/AGENTS.md` | `codex mcp add ...` | best effort, not verified |
| Gemini CLI | `gemini` | `~/.gemini/GEMINI.md` | `gemini mcp add --scope user ...` | best effort, not verified |

"Verified" means it was run against a real install of that CLI. For the others the paths come from public documentation and community write-ups, and the MCP flags are an educated guess: run `<cli> mcp add --help` and adjust `lib/harnesses.sh` if they differ. The installer prints the plan first, so you can see what it will do.

## Notes per agent

- **OpenCode** only reads the file if it is listed in the `instructions` array of `opencode.jsonc`. The installer cannot edit that file safely (it allows comments), so it warns you to add the path.
- **Antigravity and Gemini CLI** both use `~/.gemini/`. Selecting both writes two files there (`AGENTS.md` and `GEMINI.md`). Which one wins when both exist is not confirmed in the documentation, so select only the one you use if you see duplicate rules.
- **Codex CLI**: one report says a specific 0.77.0 build did not load `~/.codex/AGENTS.md`; check your version if the rules do not load.
- **MCP**: if a CLI is not installed, its registration is skipped. If a server with the same name exists, it is left alone.

## Other tools

Many other tools (for example GitHub Copilot CLI, Cursor, Aider, Amp, Kilo Code) read an `AGENTS.md` placed in a repository. This installer does not manage their global files, because their global locations are not confirmed. To use the same rules there, copy the managed block from one of the files above into the repo's `AGENTS.md`.

## Sources

- [Custom instructions with AGENTS.md (Codex)](https://developers.openai.com/codex/guides/agents-md)
- [Antigravity rules](https://antigravity.google/docs/rules.md)
- [AI harness compatibility matrix](https://codylindley.github.io/ai-harness-engineering-compatibility-matrix/)
- [AI coding config files guide](https://deployhq.com/blog/ai-coding-config-files-guide)

Check the vendor documentation before relying on any path marked best effort.
