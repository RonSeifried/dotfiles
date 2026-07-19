#!/usr/bin/env bash
# Recoverable snapshot of the repository, including uncommitted work.
set -eu
# Archives can contain uncommitted work. Keep them private even when the user's
# normal umask is permissive.
umask 077
repo=${DOTFILES_REPO:-$HOME/dev/personal/dotfiles}
target=${DOTFILES_BACKUP_DIR:-$HOME/Backups/dotfiles}
if [[ -z "$target" || "$target" == "/" || "$target" == "$HOME" ]]; then
    printf 'Refusing unsafe backup target: %s\n' "$target" >&2
    exit 2
fi
mkdir -p "$target"
stamp=$(date '+%Y-%m-%d_%H-%M-%S')
archive="$target/dotfiles-$stamp.tar.zst"
# Preserve useful uncommitted work, but never sweep common credential stores,
# agent-local state, or generated caches into the convenience archive.
tar --zstd \
    --exclude=.git \
    --exclude='.cache' \
    --exclude='.claude' \
    --exclude='.codex' \
    --exclude='.agents' \
    --exclude='.askai-env' \
    --exclude='.env' \
    --exclude='.env.*' \
    --exclude='*.key' \
    --exclude='*.pem' \
    --exclude='*.p12' \
    --exclude='*.pfx' \
    --exclude='*.secret' \
    --exclude='.config/zed/settings.json' \
    -cf "$archive" -C "${repo%/*}" "${repo##*/}"
bundle_tmp="$target/.dotfiles-git.bundle.tmp"
git -C "$repo" bundle create "$bundle_tmp" --all
mv -f "$bundle_tmp" "$target/dotfiles-git.bundle"
ln -sfn "$archive" "$target/latest.tar.zst"

# Eight weekly working-tree snapshots plus one current Git bundle cap normal
# storage use. Targets are resolved first and only explicit files are removed.
mapfile -t archives < <(find "$target" -maxdepth 1 -type f -name 'dotfiles-*.tar.zst' -printf '%T@ %p\n' | sort -nr | cut -d' ' -f2-)
if (( ${#archives[@]} > 8 )); then
    for old in "${archives[@]:8}"; do rm -- "$old"; done
fi
notify-send -a "Desktop Health" "Dotfiles backup complete" "$(basename "$archive")" -i drive-harddisk \
    >/dev/null 2>&1 || true
printf '%s\n' "$archive"
