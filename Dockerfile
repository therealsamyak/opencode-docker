FROM node:24-slim

ARG OPENCODE_UID=1000
ARG TARGETARCH

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    gh \
    tmux \
    openssh-client \
    ca-certificates \
    curl \
    build-essential \
    python3 \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# cloudflared (stable)
RUN mkdir -p --mode=0755 /usr/share/keyrings && \
    curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg -o /usr/share/keyrings/cloudflare-main.gpg && \
    echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared bookworm main' > /etc/apt/sources.list.d/cloudflared.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends cloudflared && \
    rm -rf /var/lib/apt/lists/*

# Chromium deps (agent-browser)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libxcb-shm0 \
    libx11-xcb1 \
    libx11-6 \
    libxcb1 \
    libxext6 \
    libxrandr2 \
    libxcomposite1 \
    libxcursor1 \
    libxdamage1 \
    libxfixes3 \
    libxi6 \
    libgtk-3-0 \
    libpangocairo-1.0-0 \
    libpango-1.0-0 \
    libatk1.0-0 \
    libcairo-gobject2 \
    libcairo2 \
    libgdk-pixbuf-2.0-0 \
    libxrender1 \
    libasound2 \
    libfreetype6 \
    libfontconfig1 \
    libdbus-1-3 \
    libnss3 \
    libnspr4 \
    libatk-bridge2.0-0 \
    libdrm2 \
    libxkbcommon0 \
    libatspi2.0-0 \
    libcups2 \
    libxshmfence1 \
    libgbm1 \
    fonts-noto-color-emoji \
    fonts-noto-cjk \
    fonts-freefont-ttf \
    && rm -rf /var/lib/apt/lists/*

COPY --from=oven/bun /usr/local/bin/bun /usr/local/bin/bun
COPY --from=oven/bun /usr/local/bin/bunx /usr/local/bin/bunx

COPY --from=ghcr.io/astral-sh/uv /uv /usr/local/bin/uv
COPY --from=ghcr.io/astral-sh/uv /uvx /usr/local/bin/uvx

COPY --from=docker:cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker:cli /usr/local/libexec/docker/cli-plugins/docker-compose /usr/local/libexec/docker/cli-plugins/docker-compose

RUN userdel -r node 2>/dev/null; useradd -m -s /bin/bash -u ${OPENCODE_UID} opencode && \
    mkdir -p /home/opencode/.local/share/opencode \
             /home/opencode/.cache/opencode \
             /home/opencode/.config/opencode \
             /home/opencode/seed \
             /workspace && \
    chown -R opencode:opencode /home/opencode /workspace

COPY config/ /home/opencode/.config/opencode/
RUN chown -R opencode:opencode /home/opencode/.config/opencode

COPY entrypoint.sh /home/opencode/entrypoint.sh
RUN chmod +x /home/opencode/entrypoint.sh

# Ensure PATH includes local bin before running as non-root
ENV PATH="/home/opencode/.bun/bin:/home/opencode/.local/bin:/home/opencode/.local/share/pnpm:${PATH}"
ENV EXECUTOR_DATA_DIR=/home/opencode/.executor

# Everything below runs as non-root
USER opencode

RUN curl -fsSL https://raw.githubusercontent.com/dmtrKovalenko/fff.nvim/main/install-mcp.sh | bash

RUN bun add -g opencode-ai executor typescript-language-server typescript lefthook agent-browser && \
    bun pm -g trust opencode-ai executor lefthook || true

# pnpm - install via official standalone script (bun add -g pnpm produces broken binary)
RUN curl -fsSL https://get.pnpm.io/install.sh | ENV="/home/opencode/.bashrc" SHELL="/bin/bash" bash -

# Symlink agent-browser into /usr/local/bin so login shells (agent-spawned) can find it
USER root
RUN ln -s /home/opencode/.bun/bin/agent-browser /usr/local/bin/agent-browser && \
    ln -s /home/opencode/.local/share/pnpm/pnpm /usr/local/bin/pnpm

RUN if [ "$TARGETARCH" = "arm64" ]; then \
      apt-get update && apt-get install -y --no-install-recommends chromium && rm -rf /var/lib/apt/lists/*; \
    else \
      /home/opencode/.bun/bin/agent-browser install --with-deps; \
    fi

WORKDIR /workspace

EXPOSE 4096 4788

ENTRYPOINT ["/home/opencode/entrypoint.sh"]
CMD ["opencode", "serve", "--hostname", "0.0.0.0", "--port", "4096"]
