# opencode-server

opencode-ai server + executor in a container. Runs `opencode serve` on port 4096 with an executor dashboard on port 4788.

## Quick Start

Save this as `compose.yml` and run `docker compose up -d`:

```yaml
services:
  opencode-server:
    image: ghcr.io/therealsamyak/opencode-setup-docker:latest
    container_name: opencode-server
    ports:
      - "4096:4096"
      - "4788:4788"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./config:/home/opencode/.config/opencode:ro
      - /path/to/repos:/repos:rw
    environment:
      - OPENAI_API_KEY=${OPENAI_API_KEY}
    restart: unless-stopped
```

Create `config/opencode.jsonc`:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": ["oh-my-openagent@latest"],
  "mcp": {
    "executor": {
      "type": "remote",
      "url": "http://localhost:4788/mcp",
      "enabled": true,
    },
  },
}
```

Then:

```bash
# Set your provider's API key (see https://models.dev/ for others)
export OPENAI_API_KEY=sk-...
docker compose up -d
```

Web UI: http://localhost:4096

### Clone instead

```bash
git clone https://github.com/therealsamyak/opencode-setup-docker.git
cd opencode-setup-docker
cp .env.example .env.local
# Edit .env.local — set the API key env var for your AI provider
docker compose up -d
```

## Configuration

The image ships a minimal example `config/opencode.jsonc`. Any files you mount to `/home/opencode/.config/opencode/` override the defaults.

```yaml
services:
  opencode-server:
    volumes:
      - ./my-config:/home/opencode/.config/opencode:ro
```

opencode loads any of these files it finds in the config directory:

| File                     | Purpose                                        |
| ------------------------ | ---------------------------------------------- |
| `opencode.jsonc`         | Core config — plugins, MCP servers, settings   |
| `oh-my-openagent.jsonc`  | Model overrides per agent/category              |
| `AGENTS.md`              | Custom instructions for the agent               |
| `executor.jsonc`         | MCP sources for the executor tool               |
| `command/*.md`           | Slash commands / skills                         |

You can provide any subset. The container only uses what's present.

### Plugins

[opencode](https://opencode.ai) supports plugins to extend agent capabilities:

| Plugin                                                                                           | Description                                                    |
| ------------------------------------------------------------------------------------------------ | -------------------------------------------------------------- |
| [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent)                               | Agent harness — model overrides, temperature, categories        |
| [@tarquinen/opencode-dcp](https://github.com/Tarquinen/opencode-dynamic-context-pruning)         | Dynamic context pruning — manages token usage intelligently     |

Install in `opencode.jsonc`:

```jsonc
{
  "plugin": ["oh-my-openagent@latest", "@tarquinen/opencode-dcp@latest"],
}
```

## Adding Repos

Mount repos, SSH keys, and auth into the container:

```yaml
services:
  opencode-server:
    volumes:
      - /path/to/repos:/repos:rw
      - ~/.ssh:/home/opencode/.ssh:ro
      - /path/to/auth.json:/home/opencode/seed/auth.json:ro
```

`entrypoint.sh` seeds `auth.json` into a named volume on first run.

## Environment Variables

### AI Provider

Visit [models.dev](https://models.dev/) to find the env var for your provider. Set it in `.env.local` — opencode will pick it up automatically.

| Provider   | Env Var             |
| ---------- | ------------------- |
| OpenAI     | `OPENAI_API_KEY`    |
| Anthropic  | `ANTHROPIC_API_KEY` |
| Google     | `GOOGLE_API_KEY`    |
| Groq       | `GROQ_API_KEY`      |

### General

| Variable                | Default                | Description                          |
| ----------------------- | ---------------------- | ------------------------------------ |
| `GH_TOKEN`              |                        | GitHub token for gh CLI auth         |
| `OPENCODE_SERVER_URL`   | `opencode-server:4096` | Server URL (hostname:port)           |
| `EXECUTOR_HOSTNAME`     |                        | Additional allowed host for executor |
| `EXECUTOR_ALLOWED_IP`   |                        | Allowed IP for executor access       |
| `DOCKER_NETWORK`        | `opencode-network`     | External Docker network name         |

## License

MIT
