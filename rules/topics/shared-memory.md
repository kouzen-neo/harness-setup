<!-- when: Notes vault and shared agent memory (read at the start of work, write durable facts) -->
# Notes vault and shared agent memory

The owner's notes vault is `{{VAULT_PATH}}` (a git repo, backed up to the private repo `{{VAULT_BACKUP_REPO}}`). If a vault MCP server is registered in your tool, use it; otherwise edit the files directly with the same layout. All agents share these notes so each can see what the others learned.

**Reading**
- At the start of work on a known project: check the vault is present, read `AI Index.md`, then `Shared/Agent Memory/INDEX.md` and any note relevant to the task, then the project note.
- Search the vault for facts across notes before asking the owner something it may already record.

**Writing shared memory**
- Save durable facts as `Shared/Agent Memory/<short-kebab-name>.md` and add one line to `Shared/Agent Memory/INDEX.md` (`- [[name]] - hook`). Read a note before overwriting it, and update an existing note instead of making a duplicate.
- Note format: frontmatter with `name`, `description` (one line), `agent` (which agent wrote it), `type` (user, feedback, project, or reference), and `updated` (YYYY-MM-DD). Body in English, one fact per note. For feedback and project notes add **Why:** and **How to apply:** lines. Link related notes with `[[name]]`.
- Save: owner preferences and corrections, project decisions and constraints, pointers to external resources, and status the other agents need. Do not save what the repo, git history, or the instruction files already record, or anything that only matters to the current conversation. Delete notes that turn out to be wrong.
- Never write into an agent's own exported memory folder (for example `Memory/`); it may be a one-way export that can be restored back into that agent.
- After a release, deploy, merge, or decision, update the matching project note and log it if the vault has a log.

**Limits**
- Notes never contain secrets (keys, tokens, passwords, private keys, device IDs, personal data), because the vault is copied to a remote backup.
- Never push the vault, change its remote, or make its repo public. Ask before creating notes outside `Shared/Agent Memory/`.
