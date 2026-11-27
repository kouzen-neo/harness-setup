# Instructions for agents: installing harness-setup

You are an AI coding agent. The owner asked you to install this repository on their machine. Follow this file exactly.

## Hard rules

- Never ask the owner to paste a password, token, or API key into the chat, and never type one anywhere. Tell the owner to log in to each CLI themselves.
- Never read credential files (`token`, `.env`, key files, `~/.ssh`, browser profiles).
- Never push, publish, or create a remote repo during this task.
- Never delete or overwrite anything yourself. The installer backs up every file it changes; use its `--adopt` flag only after the owner says yes.
- Keep values the owner gives you in a file **outside this repo** (`~/.config/harness-setup/owner.env`, mode 600). Never write them into this repo.
- Reply in the owner's language. Everything you write into files stays English.

## Step 1: look around (read-only)

Run `./install.sh --detect`. It prints `key=value` lines: the OS, shell, which agent CLIs are installed, which tools are present, and whether a rules folder already exists. Missing `git` or `python3` means stop and tell the owner what to install (see `docs/INSTALL.md`).

## Step 2: ask the owner

Ask in small groups, give a recommended default for each, and skip what the detection already answered. Do not decide for the owner.

1. **Agents.** Show the detected agent CLIs and ask which to configure. Supported: Claude Code, Antigravity, OpenCode, Codex CLI, Gemini CLI (the last two are best effort). Pass the answer as `--harness`.
2. **Reply language** (`OWNER_LANGUAGE`) and **shell** (`SHELL_NAME`; default from detection).
3. **Topics.** List the files in `rules/topics/` with their one-line `when:` description and ask which to install (default: all). Only ask about the Vercel topic if the owner deploys to Vercel, and about the Android topic if they work with a phone.
4. **Optional rules** (`rules/optional/`): "no AI attribution in commits and public text", and "everything in repos is English". Ask for each.
5. **Owner values**, only for the topics chosen: `DOMAIN`, `DNS_PROVIDER`, `VERCEL_TEAM` (Vercel topic); `VAULT_PATH`, `VAULT_BACKUP_REPO` (shared-memory topic).
6. **MCP servers.** The default list registers Context7. Ask whether to add others: name, type (`stdio` or `http`), and the command or URL. Servers that need a key are set up by the owner by hand, not by you.
7. **Session wrappers.** Ask whether to install `agy-session`, `claude-session`, `opencode-session` (default: yes for the selected agents).
8. **Existing setup.** If detection says a rules folder already exists, ask: use another folder (`--rules-dir`) or take it over (`--adopt`, backed up first)?

## Step 3: write the owner file

Create `~/.config/harness-setup/owner.env` with the answers (`KEY=value` lines, see `config/example.env`) and `chmod 600` it. If the owner wants custom MCP servers, create `~/.config/harness-setup/mcps.conf` the same way (see `config/mcps.example.conf`).

## Step 4: dry run, confirm, install

1. Run `./install.sh --dry-run --env ~/.config/harness-setup/owner.env` with the chosen flags (`--harness`, `--topics`, `--optional`, `--mcps`, `--rules-dir`, `--adopt`, `--no-sessions`).
2. Show the owner the plan it prints and wait for a clear yes.
3. Run the same command with `--yes` instead of `--dry-run`.
4. Run `./install.sh --check` and report what it says, including failures.

## Step 5: finish

Tell the owner, in a short list:

- what was installed and where (the plan lists every path), and where the backups are;
- which logins are still theirs to do (each agent CLI, `gh auth login`, `vercel login`, and any MCP server that needs one);
- how to confirm it works: open a new agent session and ask "What are your global rules?";
- how to remove it: `./uninstall.sh`.

## If this repository is out of date

Tools change faster than a repository. Treat this file as the procedure, and treat the scripts, docs, and examples as a snapshot that may lag behind the machine in front of you.

- `./install.sh --detect` prints a version line for each agent CLI (`harness.<name>.version`). If a CLI is newer than you expect, or an installer step fails or prints something unexpected, stop and look at reality first: run `<cli> --help` and `<cli> mcp add --help`, and read the vendor's current documentation for the rules file location.
- If a command, flag, or file location has changed, adapt the step you run for the owner, say clearly what differed from the repository, and carry on with the corrected step. Never guess, and never write to a path you could not confirm.
- Do not edit the repository's files on your own to make it work. At the end, give the owner a short "drift report" (what was outdated, what you did instead, what to change in the repo) so they can decide. Apply a repository fix only if the owner says yes, and never push it.
- This does not relax any hard rule above: no credentials, nothing deleted by you, nothing published.

## If something fails

Report the exact error and stop. Do not retry with broader permissions, do not edit the installer to get around a refusal, and do not delete files to make room. `docs/TROUBLESHOOTING.md` lists the common causes.
