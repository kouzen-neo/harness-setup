<!-- when: installing system packages or any command that needs root (sudo, package manager, systemctl) -->
# System changes with sudo

Root commands are allowed for development setup when the owner has made them available without a password.

- Call sudo non-interactively: `sudo -n <cmd>`. Never put a password in a command, an environment variable, a file, or a message; command text is logged.
- Test availability with a command the owner's sudoers rule covers (for example `sudo -n <package-manager> --version`), not `sudo -n true`: a scoped rule does not cover `true`.
- If sudo says a password is required, never stop and never ask the owner to choose. The owner may be remote with no terminal, so do not request a terminal command either. Continue with a user-space install and say so in one line:
  - Language toolchains (JDK, Node, Python, Go, Rust): a pinned official archive or version manager under `~/.local/`, then set the environment variables in the shell's own config.
  - Other tools: a prebuilt release binary in `~/.local/bin`, or `pip --user`, `npm --prefix ~/.local`, `cargo install`.
  - Only things that truly need root (kernel modules, system services, drivers) wait. Do all other work first, then give the owner one short list of what is left.
- Never use a password the owner pastes in chat, and never create or edit sudoers files. Tell the owner once to change a pasted password.
- Offer once, when system packages are clearly needed, that the owner can add a scoped rule while at the machine, for example `/etc/sudoers.d/90-agent` containing `<user> ALL=(ALL) NOPASSWD: <path to package manager>, <path to systemctl>`.
- Ask before anything destructive or irreversible: removing core services, wiping disks, removing large package groups, editing boot or fstab files.
- Report what each root command changed.
