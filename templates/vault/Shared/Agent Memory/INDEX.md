# Agent Memory index

Shared long-term memory for all coding agents. Each agent reads this index at the start of work and adds one line per note it writes. Notes live in this folder.

Format of an index line: `- [[note-name]] - one-line hook`

Note format: frontmatter with `name`, `description`, `agent`, `type` (user, feedback, project, or reference), and `updated`; one fact per note; link related notes with `[[name]]`.
