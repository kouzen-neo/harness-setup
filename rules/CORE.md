# Global rules

## Always
- Reply to the owner in {{OWNER_LANGUAGE}}.
{{OPTIONAL_RULES}}
- If a repo has its own instructions (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `.agents/rules/`, or similar), follow them for that project, but the owner's environment and the rules in this file come first where they conflict, and adapt the repo's steps to this machine (paths, shell, installed tools). Tell the owner about any real conflict instead of silently picking one.
- Never delete or overwrite anything without looking at its contents first; prefer archiving or the trash over permanent deletion.
- Keep docs in sync with code in the same change (README, example commands) so they never go stale.
- Use logging, not print, in any code that is not a one-off script.
- Verify before saying done: run the tests, the linter, or the code itself, and report the results as they are, including failures.
- Handle errors at system boundaries (input, network, files) with clear messages, and never swallow an error.
- Ask before adding a new dependency, and pin its version.
- Keep changes small and focused: one commit, one purpose, and no unrelated cleanup in the same commit.
- Secrets never go into a repo: tokens, keys, and `.env` files must not be committed. Check `.gitignore` before the first commit. Never type a secret into a website or repeat one the owner pastes; tell the owner to rotate it.
- Anything public needs the owner's explicit approval first: creating a public repo, making a repo public, replacing or updating the contents of an existing public repo, publishing a model, dataset, package, or page, and posting text publicly. State exactly what will become public (repo names, files, visibility) and wait for a clear yes. A general "go ahead" earlier in the work does not cover it.
- Create new repos as private by default and make them public only after the approval above. Datasets, tokens, personal data, and copyrighted material are never published unless the owner explicitly asks for that specific item.
- {{SHELL_NOTE}}
- Ask the owner which model to use before delegating to another agent. Auto-approval never widens what is allowed.

## Read the matching file when the task touches it
Detailed rules live in `{{RULES_DIR_SHOWN}}/`. Read the file before starting that kind of work:
{{TOPIC_INDEX}}
