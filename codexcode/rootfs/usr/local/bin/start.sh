#!/usr/bin/env bash
set -euo pipefail

export HA_TOKEN="${SUPERVISOR_TOKEN:-}"
export HA_URL="http://supervisor/core"

PERSIST_DIR="/homeassistant/.codexcode"
mkdir -p "${PERSIST_DIR}/config" /root/.config

cat > "${PERSIST_DIR}/CODEX.md" <<'EOF'
# Codex Code - Home Assistant Add-on

## Path Mapping

In this add-on container, paths are mapped differently than HA Core:
- `/homeassistant` = HA config directory (equivalent to `/config` in HA Core)
- `/config` may not exist; use `/homeassistant`

When users mention `/config/...`, translate to `/homeassistant/...`.

## Available Paths

| Path | Description | Access |
|------|-------------|--------|
| `/homeassistant` | HA configuration | read-write |
| `/share` | Shared folder | read-write |
| `/media` | Media files | read-write |
| `/ssl` | SSL certificates | read-only |
| `/backup` | Backups | read-only |

## Home Assistant Integration

Use `hass-mcp` and your client MCP configuration for Home Assistant integration.
For better performance, prefer domain-focused queries over full entity dumps.

## Action Reliability

When executing state-changing actions (turn on/off, set temperature, etc):
1. Call the action tool once.
2. Immediately read back the target entity state.
3. Treat the operation as successful if the readback matches the requested state.

Some MCP action calls may return strict schema/validation errors in Codex even when Home Assistant has already applied the change.

## Reading Home Assistant Logs

```bash
# View recent logs (ha CLI)
ha core logs 2>&1 | tail -100

# Filter by keyword
ha core logs 2>&1 | grep -i keyword

# Filter errors only
ha core logs 2>&1 | grep -iE "(error|exception)"

# Alternative: read log file directly
tail -100 /homeassistant/home-assistant.log
```
EOF

if [ ! -L /root/.codex ]; then
  rm -rf /root/.codex
  ln -s "${PERSIST_DIR}" /root/.codex
fi

if [ ! -L /root/.config/codex ]; then
  rm -rf /root/.config/codex
  ln -s "${PERSIST_DIR}/config" /root/.config/codex
fi

if [ ! -L /root/.codex.json ]; then
  touch "${PERSIST_DIR}/.codex.json"
  rm -f /root/.codex.json
  ln -s "${PERSIST_DIR}/.codex.json" /root/.codex.json
fi

OPTIONS_FILE="/data/options.json"
FONT_SIZE="$(jq -r '.terminal_font_size // 14' "${OPTIONS_FILE}")"
THEME="$(jq -r '.terminal_theme // "dark"' "${OPTIONS_FILE}")"
SESSION_PERSIST="$(jq -r '.session_persistence // true' "${OPTIONS_FILE}")"
ENABLE_MCP="$(jq -r '.enable_mcp // true' "${OPTIONS_FILE}")"
ENABLE_PLAYWRIGHT="$(jq -r '.enable_playwright_mcp // false' "${OPTIONS_FILE}")"
PLAYWRIGHT_HOST="$(jq -r '.playwright_cdp_host // ""' "${OPTIONS_FILE}")"

if [ -z "${PLAYWRIGHT_HOST}" ] && [ "${ENABLE_PLAYWRIGHT}" = "true" ]; then
  echo "[INFO] Auto-detecting Playwright Browser hostname..."
  PLAYWRIGHT_HOST="$(
    curl -s -H "Authorization: Bearer ${SUPERVISOR_TOKEN:-}" http://supervisor/addons \
      | jq -r '.data.addons[] | select(.slug | endswith("playwright-browser") or endswith("_playwright-browser")) | .hostname' \
      | head -1
  )"
  if [ -n "${PLAYWRIGHT_HOST}" ] && [ "${PLAYWRIGHT_HOST}" != "null" ]; then
    echo "[INFO] Found Playwright Browser: ${PLAYWRIGHT_HOST}"
  else
    echo "[WARN] Playwright Browser add-on not found, using default hostname"
    PLAYWRIGHT_HOST="playwright-browser"
  fi
fi

AUTO_UPDATE_CODEX="$(jq -r '.auto_update_codex // false' "${OPTIONS_FILE}")"
if [ "${AUTO_UPDATE_CODEX}" = "true" ]; then
  if npm list -g @openai/codex >/dev/null 2>&1; then
    echo "[INFO] Checking for Codex updates..."
    npm update -g @openai/codex >/dev/null 2>&1 || echo "[WARN] Codex update check failed, continuing..."
  else
    echo "[INFO] auto_update_codex enabled, but @openai/codex is not globally installed"
  fi
fi

if [ "${ENABLE_MCP}" = "true" ]; then
  if command -v codex >/dev/null 2>&1 && codex mcp list >/dev/null 2>&1; then
    MCP_HA_CWD="${PERSIST_DIR}/mcp/homeassistant"
    mkdir -p "${MCP_HA_CWD}"
    cat > "${MCP_HA_CWD}/hass-mcp-launcher.sh" <<EOF
#!/usr/bin/env bash
cd "${MCP_HA_CWD}"
export HA_URL="${HA_URL}"
export HA_TOKEN="${HA_TOKEN}"
exec hass-mcp
EOF
    chmod 700 "${MCP_HA_CWD}/hass-mcp-launcher.sh"

    codex mcp remove homeassistant >/dev/null 2>&1 || true
    if codex mcp add homeassistant -- "${MCP_HA_CWD}/hass-mcp-launcher.sh" >/dev/null 2>&1; then
      echo "[INFO] Codex MCP 'homeassistant' configured"
    else
      echo "[WARN] Failed to configure Codex MCP 'homeassistant'"
    fi
  else
    echo "[WARN] Codex CLI MCP commands unavailable; skipping MCP bootstrap"
  fi
else
  if command -v codex >/dev/null 2>&1; then
    codex mcp remove homeassistant >/dev/null 2>&1 || true
  fi
  echo "[INFO] MCP disabled"
fi

if [ "${ENABLE_PLAYWRIGHT}" = "true" ]; then
  if command -v codex >/dev/null 2>&1 && codex mcp list >/dev/null 2>&1; then
    codex mcp remove playwright >/dev/null 2>&1 || true
    if codex mcp add playwright -- npx -y @playwright/mcp --cdp-endpoint "http://${PLAYWRIGHT_HOST}:9222" >/dev/null 2>&1; then
      echo "[INFO] Codex MCP 'playwright' configured (CDP: http://${PLAYWRIGHT_HOST}:9222)"
    else
      echo "[WARN] Failed to configure Codex MCP 'playwright'"
    fi
  else
    echo "[INFO] Playwright MCP endpoint hint: http://${PLAYWRIGHT_HOST}:9222"
  fi
else
  if command -v codex >/dev/null 2>&1; then
    codex mcp remove playwright >/dev/null 2>&1 || true
  fi
  echo "[INFO] Playwright MCP disabled"
fi

if [ "${THEME}" = "dark" ]; then
  COLORS="background=#1e1e2e,foreground=#cdd6f4,cursor=#f5e0dc"
else
  COLORS="background=#eff1f5,foreground=#4c4f69,cursor=#dc8a78"
fi

if [ "${SESSION_PERSIST}" = "true" ]; then
  SHELL_CMD=(tmux new-session -A -s codex)
else
  SHELL_CMD=(bash --login)
fi

cd /homeassistant
exec ttyd --port 7681 --writable --ping-interval 30 --max-clients 5 \
  -t "fontSize=${FONT_SIZE}" \
  -t "fontFamily=Monaco,Consolas,monospace" \
  -t "scrollback=20000" \
  -t "theme=${COLORS}" \
  "${SHELL_CMD[@]}"
