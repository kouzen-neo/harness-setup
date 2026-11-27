#!/usr/bin/env bash
# Optional notes-vault step (Obsidian, or any folder of markdown notes).
# Clones or fast-forwards the private backup repo, or creates a starter vault when there is none.
# Never pushes, never overwrites, never touches a folder that already has files and is not a git clone.

readonly VAULT_TEMPLATE_DIR="templates/vault"

vault_is_empty() { [ ! -e "$1" ] || [ -z "$(find "$1" -mindepth 1 -maxdepth 1 2>/dev/null | head -n 1)" ]; }

pull_vault() { # $1 path of an existing git clone
  local path="$1"
  if [ -n "$(git -C "$path" status --porcelain)" ]; then
    warn "vault at $path has uncommitted changes; not pulling"
  elif [ -z "$(git -C "$path" remote)" ]; then
    log "vault: $path has no remote; nothing to pull"
  else
    log "vault: updating $path (fast-forward only)"
    run git -C "$path" pull --ff-only
  fi
}

clone_vault() { # $1 repo (URL or owner/name), $2 path
  local repo="$1" path="$2"
  case "$repo" in
    *://*|git@*)
      log "vault: cloning $repo into $path"
      run git clone "$repo" "$path" ;;
    *)
      if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
        log "vault: cloning $repo into $path"
        run gh repo clone "$repo" "$path"
      else
        warn "vault not cloned: log in yourself with \`gh auth login\`, then run: gh repo clone $repo \"$path\""
      fi ;;
  esac
}

create_starter_vault() { # $1 path
  local path="$1"
  log "vault: creating a starter vault at $path"
  run mkdir -p "$path"
  run cp -R "$ROOT/$VAULT_TEMPLATE_DIR/." "$path/"
}

sync_vault() {
  local path="${VAULT_PATH-}" repo="${VAULT_BACKUP_REPO-}"
  [ -n "$path" ] || { warn "--vault needs VAULT_PATH in the env file; vault step skipped"; return 0; }
  if [ -d "$path/.git" ]; then
    pull_vault "$path"
  elif vault_is_empty "$path"; then
    if [ -n "$repo" ]; then clone_vault "$repo" "$path"; else create_starter_vault "$path"; fi
  else
    warn "$path already has files and is not a git clone; left alone"
  fi
}

detect_obsidian() { # prints installed|missing
  if command -v obsidian >/dev/null 2>&1 \
     || { command -v flatpak >/dev/null 2>&1 && flatpak list --app 2>/dev/null | grep -q 'md.obsidian.Obsidian'; } \
     || [ -d "/Applications/Obsidian.app" ]; then
    echo installed
  else
    echo missing
  fi
}
