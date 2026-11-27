# Rules

## How it is organised

- `rules/CORE.md`: the short "always" list. A copy goes into every selected agent's global rules file, so it is loaded in every session. Keep it short.
- `rules/topics/*.md`: detailed rules, one file per subject. They are installed into the rules folder, and the core file lists them as "read this file when the task touches X". The agent reads a topic only when needed, so the always-loaded part stays small.
- `rules/optional/*.md`: single bullets you can switch on with `--optional`. They are inserted into the "Always" list.

The first line of every topic is `<!-- when: ... -->`. The installer uses it to build the topic index in the core file.

## Templates

Rule files can contain `{{NAME}}` placeholders. At install time each one is replaced by the value of `NAME` from your `--env` file. A placeholder without a value is replaced by a visible `<NAME is not set: ask the owner>`, so the agent asks you instead of guessing.

| Placeholder | Used for |
|---|---|
| `OWNER_LANGUAGE` | the language the agent replies in |
| `SHELL_NAME` | which shell syntax the agent uses when it gives you commands (default: your `$SHELL`) |
| `DOMAIN`, `DNS_PROVIDER`, `VERCEL_TEAM` | the Vercel and subdomain topic |
| `VAULT_PATH`, `VAULT_BACKUP_REPO` | the shared-memory topic |

The env file is read as plain `KEY=value` lines. Nothing in it is executed.

## Your own rules (overlay)

Keep personal or private rules outside this repo and point to them with `--overlay DIR`. Files under `DIR/rules/` take priority:

```text
DIR/rules/CORE.md                  replaces the core file
DIR/rules/topics/<topic>.md        replaces a topic, or adds a new one
DIR/rules/optional/<name>.md       replaces or adds an optional rule
```

Anything not in the overlay comes from this repo.

## Writing a new topic

1. Create `rules/topics/<name>.md` (or in your overlay).
2. First line: `<!-- when: Short description of when to read it -->`.
3. Write short, concrete bullets: what to do and what to ask the owner.
4. Run `./install.sh --dry-run`, then install.

## Adopting an existing setup

If the rules folder already exists and was not created by this installer, it is not touched. Pass `--adopt` (it is backed up, then replaced) or choose another folder with `--rules-dir`.
