ARG BUILD_FROM
FROM ${BUILD_FROM}

# Labels
LABEL maintainer="Robson Felix"
LABEL org.opencontainers.image.title="Claude Code for Home Assistant"
LABEL org.opencontainers.image.description="Claude Code CLI with web terminal and HA integration"
LABEL org.opencontainers.image.source="https://github.com/robsonfelix/robsonfelix-hass-addons"
LABEL org.opencontainers.image.licenses="MIT"

# Environment setup
ENV \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TERM=xterm-256color

# Install system dependencies including ttyd from Alpine packages
RUN apk add --no-cache \
    bash \
    curl \
    git \
    jq \
    nodejs \
    npm \
    openssh-client \
    libstdc++ \
    ncurses \
    vim \
    nano \
    tmux \
    coreutils \
    findutils \
    grep \
    sed \
    gawk \
    ca-certificates \
    openssl \
    ripgrep \
    ttyd \
    && update-ca-certificates

# Install Claude Code via npm
RUN npm install -g @anthropic-ai/claude-code

# Install hass-mcp for Home Assistant integration
RUN pip3 install --no-cache-dir --break-system-packages hass-mcp

# Create necessary directories
RUN mkdir -p \
    /data \
    /homeassistant \
    /root/.claude \
    /root/.config/claude-code \
    /root/.local/bin

# Set up PATH
ENV PATH="/root/.local/bin:${PATH}"

# Create run script inline to avoid permission issues
RUN cat > /run.sh << 'RUNSCRIPT'
#!/bin/bash
set -e

CONFIG_PATH="/data/options.json"
ENABLE_MCP=$(jq -r '.enable_mcp // true' "$CONFIG_PATH")
TERMINAL_FONT_SIZE=$(jq -r '.terminal_font_size // 14' "$CONFIG_PATH")
TERMINAL_THEME=$(jq -r '.terminal_theme // "dark"' "$CONFIG_PATH")
WORKING_DIR=$(jq -r '.working_directory // "/homeassistant"' "$CONFIG_PATH")
SESSION_PERSISTENCE=$(jq -r '.session_persistence // true' "$CONFIG_PATH")

export HOME=/root
export TERM=xterm-256color
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export SUPERVISOR_TOKEN="${SUPERVISOR_TOKEN:-}"
export HASS_SERVER="http://supervisor/core"
export HASS_TOKEN="${SUPERVISOR_TOKEN}"

mkdir -p /root/.claude
if [[ "${ENABLE_MCP}" == "true" ]]; then
    cat > /root/.claude/settings.json << EOF
{"mcpServers":{"homeassistant":{"command":"hass-mcp","env":{"HASS_TOKEN":"${SUPERVISOR_TOKEN}","HASS_HOST":"http://supervisor/core"}}}}
EOF
fi

[[ ! -d "${WORKING_DIR}" ]] && WORKING_DIR="/homeassistant"
cd "${WORKING_DIR}" || cd /homeassistant

if [[ "${TERMINAL_THEME}" == "dark" ]]; then
    TTYD_THEME="background=#1e1e2e,foreground=#cdd6f4,cursor=#f5e0dc"
else
    TTYD_THEME="background=#eff1f5,foreground=#4c4f69,cursor=#dc8a78"
fi

if [[ "${SESSION_PERSISTENCE}" == "true" ]]; then
    SHELL_CMD="tmux new-session -A -s claude"
else
    SHELL_CMD="bash --login"
fi

exec ttyd --port 7681 --writable --ping-interval 30 --max-clients 5 \
    -t "fontSize=${TERMINAL_FONT_SIZE}" \
    -t "fontFamily=Monaco,Consolas,monospace" \
    -t "theme=${TTYD_THEME}" \
    ${SHELL_CMD}
RUNSCRIPT

RUN chmod 755 /run.sh

# Set working directory
WORKDIR /homeassistant

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -sf http://localhost:7681/ || exit 1

# Skip s6-overlay, use direct execution
ENTRYPOINT []
CMD ["/bin/bash", "/run.sh"]
