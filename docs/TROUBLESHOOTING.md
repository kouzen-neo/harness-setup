# Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| `no harness selected` | None of the supported CLIs is on `PATH`. Install one, or pass `--harness claude` (and so on) explicitly. |
| `<dir> already exists and was not created by harness-setup` | The rules or sessions folder exists. Move it, choose `--rules-dir`, or pass `--adopt` (backed up, then replaced). |
| `claude-session: command not found` | `~/.local/bin` is not on `PATH`. Add it to your shell profile. |
| The agent does not seem to follow the rules | Open a new session, ask "What are your global rules?". For OpenCode make sure the rules file is listed in `instructions` in `opencode.jsonc`. For Codex CLI check the version. |
| MCP server missing in an agent | The CLI was not installed when you ran the installer, or `mcp add` failed. Run `<cli> mcp list`, then `<cli> mcp add --help` and adjust `lib/harnesses.sh` if its flags differ. |
| `start` says "choose a model first" | By design. List models with `<wrapper> models` and pass `--model`. |
| A turn fails with an authentication error | Log in to that agent's CLI again; sessions cannot log in for you. |
| `{{...}}` or `<NAME is not set: ask the owner>` appears in a rules file | The value is missing from your env file. Add it and run the installer again. |
| Duplicate rules in Antigravity and Gemini CLI | Both read `~/.gemini/`. Select only the one you use (see [HARNESSES.md](HARNESSES.md)). |
| Something looks wrong after an install | The previous version of every changed file is in `~/.local/state/harness-setup/backups/`. `./uninstall.sh` removes only what the installer added. |
