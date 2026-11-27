<!-- when: installing system packages or any command that needs root (sudo, package manager, systemctl) -->
# System changes with sudo

Root commands are allowed for development setup when the owner has made them available without a password.

- Call sudo non-interactively: `sudo -n <cmd>`. Never put a password in a command, an environment variable, a file, or a message; command text is logged.
- Test availability with a command the owner's sudoers rule covers (for example `sudo -n <package-manager> --version`), not `sudo -n true`: a scoped rule does not cover `true`.
- If sudo says a password is required, do NOT start a user-space install yet. First offer the owner, once and in one short message, these choices:
  1. Full access during development: the owner runs `echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/90-agent` (or the helper `agent-sudo-on` if it is installed; it works in any shell) and removes the file when the project ends.
  2. Add only the commands the task needs to a scoped rule (list the exact paths).
  3. Continue without root, using a user-space install.
  Do the work that needs no root while waiting. If the owner picks 3, does not answer for the rest of the task, or is remote and cannot run commands, continue with a user-space install and say so in one line:
  - Language toolchains (JDK, Node, Python, Go, Rust): a pinned official archive or version manager under `~/.local/`, then set the environment variables in the shell's own config.
  - Other tools: a prebuilt release binary in `~/.local/bin`, or `pip --user`, `npm --prefix ~/.local`, `cargo install`.
  - Only things that truly need root (kernel modules, system services, drivers) wait; give the owner one short list at the end.
  Offer the choices only once per project; do not repeat them.
- When the project is nearly finished and `/etc/sudoers.d/90-agent` exists with broad access, remind the owner once to run `agent-sudo-off` or `agent-sudo-none` (or remove the file), and to change any password that was pasted in chat.
- Never use a password the owner pastes in chat, and never create or edit sudoers files. Tell the owner once to change a pasted password.
- Ask before anything destructive or irreversible: removing core services, wiping disks, removing large package groups, editing boot or fstab files.
- Report what each root command changed.
