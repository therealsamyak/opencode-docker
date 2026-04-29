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
if [ -f "$CONFIG_DIR/executor.jsonc" ] && [ ! -f "/workspace/executor.jsonc" ]; then
  cp "$CONFIG_DIR/executor.jsonc" "/workspace/executor.jsonc"
fi

# Derive hostname from OPENCODE_SERVER_URL (format: "hostname:port" or "hostname")
SERVER_HOSTNAME="${OPENCODE_SERVER_URL%%:*}"
ALL_HOSTS="${SERVER_HOSTNAME:-opencode-server} $ALLOWED_HOSTS"

ALLOWED_ARGS=""
CORS_ARGS=""
for h in $ALL_HOSTS; do
  [ -n "$h" ] || continue
  ALLOWED_ARGS="$ALLOWED_ARGS --allowed-host $h"
  CORS_ARGS="$CORS_ARGS --cors $h"
done

# Start executor web dashboard in background
executor web --port 4788 --hostname 0.0.0.0 $ALLOWED_ARGS &
EXECUTOR_PID=$!

# Ensure executor is cleaned up on exit
trap "kill $EXECUTOR_PID 2>/dev/null" EXIT TERM INT

# Drop privileges to opencode user (CORS_ARGS injected into opencode serve)
if [ -n "$GH_TOKEN" ]; then
  exec runuser -u opencode -- /bin/bash -c "gh auth setup-git && exec $* $CORS_ARGS"
else
  exec runuser -u opencode -- "$@" $CORS_ARGS
fi
