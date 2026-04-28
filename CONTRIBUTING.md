# Contributing

## Building

```bash
docker compose build
```

### Build Args

| Arg            | Default | Description                                      |
| -------------- | ------- | ------------------------------------------------ |
| `OPENCODE_UID` | `1000`  | UID for the `opencode` user inside the container |

```bash
docker compose build --build-arg OPENCODE_UID=1001
```

## Publishing

Pushing to `main` triggers CI via GitVersion. The image is published to `ghcr.io/therealsamyak/opencode-setup-docker`.

Manually trigger via GitHub Actions or push a `v*` tag:

```bash
git tag v1.0.0
git push origin v1.0.0
```

## Architecture

### Named Volumes

- `opencode-data` — sessions
- `opencode-cache` — models, bun/npm/uv cache

### Installed Runtimes

node, bun, uv, python3, git, build-essential

### Entrypoint

`entrypoint.sh` handles:
1. Docker socket GID alignment with host
2. Seeding `auth.json` from `/home/opencode/seed/` to the data volume on first run
3. Copying `executor.jsonc` from config to `/workspace` if present
4. Starting the executor web dashboard on port 4788
5. Dropping privileges to the `opencode` user
