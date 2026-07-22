#!/bin/bash
set -e

# Align docker group GID with host socket
if [ -S /var/run/docker.sock ]; then
  DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)
  if getent group "$DOCKER_GID" > /dev/null 2>&1; then
    EXISTING_GROUP=$(getent group "$DOCKER_GID" | cut -d: -f1)
    usermod -aG "$EXISTING_GROUP" opencode 2>/dev/null || true
  else
    groupadd --gid "$DOCKER_GID" docker-host 2>/dev/null || true
    usermod -aG docker-host opencode 2>/dev/null || true
  fi
fi

DATA_DIR="/home/opencode/.local/share/opencode"
SEED_DIR="/home/opencode/seed"

for f in "$SEED_DIR"/*; do
  [ -f "$f" ] || continue
  target="$DATA_DIR/$(basename "$f")"
  if [ ! -f "$target" ]; then
    cp "$f" "$target"
  fi
done

CONFIG_DIR="/home/opencode/.config/opencode"

# Fix ownership of the cache dir. Named volumes can be polluted by a different
# UID (e.g. from an older image), which leaves opencode unable to refresh
# models.json. The refresh writes a temp file next to the target then renames,
# so the directory itself must be owned by the opencode user.
chown -R opencode:opencode /home/opencode/.cache/opencode 2>/dev/null || true

# Set git identity globally (as opencode user) from env
GIT_SETUP=""
if [ -n "$GH_USERNAME" ]; then
  GIT_SETUP="git config --global user.name \"$GH_USERNAME\";"
fi
if [ -n "$GH_EMAIL" ]; then
  GIT_SETUP="$GIT_SETUP git config --global user.email \"$GH_EMAIL\";"
fi

# Drop privileges to opencode user
if [ -n "$GH_TOKEN" ]; then
  exec runuser -u opencode -- /bin/bash -c "$GIT_SETUP gh auth setup-git && exec $*"
else
  exec runuser -u opencode -- /bin/bash -c "$GIT_SETUP exec $*"
fi
