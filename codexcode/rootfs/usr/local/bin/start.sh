#!/usr/bin/env bash
set -euo pipefail

export HA_TOKEN="${SUPERVISOR_TOKEN:-}"
export HA_URL="http://supervisor/core"

PERSIST_DIR="/homeassistant/.codexcode"
CONFIG_TOML="${PERSIST_DIR}/config.toml"
mkdir -p "${PERSIST_DIR}" /root/.config

# ---------------------------------------------------------------------------
# Deploy HA context for Codex CLI auto-discovery (~/.codex/AGENTS.md)
# This gives Codex comprehensive HA knowledge (automations, templates,
# services, entities, MQTT, dashboards, debugging patterns, etc.)
# ---------------------------------------------------------------------------
cp /usr/local/share/ha-reference.md "${PERSIST_DIR}/AGENTS.md"
echo "[INFO] Deployed AGENTS.md (HA reference context for Codex)"

# Session prompt for the codex-ha alias (not auto-discovered — used explicitly)
cat > "${PERSIST_DIR}/SESSION_PROMPT.txt" <<'DOCEOF'
You have a comprehensive Home Assistant reference loaded via AGENTS.md.
Use Home Assistant MCP with these priorities:
- Avoid full entity dumps unless explicitly asked.
- Prefer targeted domain/entity queries.
- For actions, always verify final entity state and report success/failure from readback state.
- Refer to your AGENTS.md context for YAML syntax, service calls, templates, and automation patterns.
DOCEOF

# ---------------------------------------------------------------------------
# Symlink Codex CLI state to persistent storage
#   ~/.codex  →  config.toml, auth.json, log/, skills/
# ---------------------------------------------------------------------------
if [ ! -L /root/.codex ]; then
  rm -rf /root/.codex
  ln -s "${PERSIST_DIR}" /root/.codex
fi

# ---------------------------------------------------------------------------
# Read add-on options (single jq call instead of six)
# ---------------------------------------------------------------------------
OPTIONS_FILE="/data/options.json"
eval "$(jq -r '
  "FONT_SIZE="   + (.terminal_font_size // 14 | tostring),
  "THEME="       + (.terminal_theme // "dark"),
  "SESSION_PERSIST=" + (.session_persistence // true | tostring),
  "ENABLE_MCP="  + (.enable_mcp // true | tostring),
  "ENABLE_PLAYWRIGHT=" + (.enable_playwright_mcp // false | tostring),
  "PLAYWRIGHT_HOST="  + (.playwright_cdp_host // ""),
  "AUTO_UPDATE_CODEX=" + (.auto_update_codex // false | tostring)
' "${OPTIONS_FILE}")"

# ---------------------------------------------------------------------------
# Auto-detect Playwright Browser hostname (if needed)
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# Auto-update Codex CLI (if enabled)
# ---------------------------------------------------------------------------
if [ "${AUTO_UPDATE_CODEX}" = "true" ]; then
  echo "[INFO] Checking for Codex updates..."
  npm update -g @openai/codex 2>/dev/null || echo "[WARN] Codex update check failed, continuing..."
fi

# ---------------------------------------------------------------------------
# Write MCP config directly to config.toml
#
# This replaces the old approach of shelling out to `codex mcp add/remove`
# which spawned multiple Node.js processes and was slow + fragile.
#
# The HA MCP launcher reads SUPERVISOR_TOKEN at runtime so the token
# is always fresh (fixes stale-token errors after addon restarts).
# ---------------------------------------------------------------------------
MCP_HA_CWD="${PERSIST_DIR}/mcp/homeassistant"
mkdir -p "${MCP_HA_CWD}"

# Launcher script — reads SUPERVISOR_TOKEN at runtime, never bakes it in
# and prefers Home Assistant MCP implementations that expose HassTurnOn/HassTurnOff.
cat > "${MCP_HA_CWD}/ha-mcp-launcher.sh" <<'LAUNCHEREOF'
#!/usr/bin/env bash
export HA_URL="http://supervisor/core"
export HA_TOKEN="${SUPERVISOR_TOKEN}"

# Prefer newer HA MCP servers first (tool families like HassTurnOn/HassTurnOff),
# then fall back to hass-mcp for compatibility.
if command -v homeassistant-mcp >/dev/null 2>&1; then
  exec homeassistant-mcp
elif command -v home-assistant-mcp >/dev/null 2>&1; then
  exec home-assistant-mcp
elif command -v ha-mcp >/dev/null 2>&1; then
  exec ha-mcp
elif command -v hass-mcp >/dev/null 2>&1; then
  exec hass-mcp
else
  echo "[ERROR] No Home Assistant MCP server binary found (tried: homeassistant-mcp, home-assistant-mcp, ha-mcp, hass-mcp)" >&2
  exit 127
fi
LAUNCHEREOF
chmod 700 "${MCP_HA_CWD}/ha-mcp-launcher.sh"

# Build config.toml — preserve auth.json and any user customisations
# by merging MCP sections on top of existing config
{
  # Preserve any existing non-MCP config lines (model, approval_policy, etc.)
  if [ -f "${CONFIG_TOML}" ]; then
    # Strip old mcp_servers sections — we regenerate them below
    # Fix project_doc_max_bytes: must be a quoted string, not a bare integer
    sed '/^\[mcp_servers\./,/^$/d; /^\[mcp_servers\]/d' "${CONFIG_TOML}" \
      | sed 's/^project_doc_max_bytes = [0-9][0-9]*/project_doc_max_bytes = "65536"/' \
      | sed '/^$/N;/^\n$/d'  # collapse double blank lines
  fi

  # Ensure project_doc_max_bytes is set (AGENTS.md is ~60KB, default limit is 32KB)
  if ! grep -q 'project_doc_max_bytes' "${CONFIG_TOML}" 2>/dev/null; then
    echo 'project_doc_max_bytes = "65536"'
  fi

  echo ""

  if [ "${ENABLE_MCP}" = "true" ]; then
    cat <<MCPEOF

[mcp_servers.homeassistant]
command = "${MCP_HA_CWD}/ha-mcp-launcher.sh"
args = []
startup_timeout_sec = 15.0
tool_timeout_sec = 30.0

[mcp_servers.homeassistant.env]
SUPERVISOR_TOKEN = "${SUPERVISOR_TOKEN:-}"
MCPEOF
  fi

  if [ "${ENABLE_PLAYWRIGHT}" = "true" ]; then
    cat <<MCPEOF

[mcp_servers.playwright]
command = "npx"
args = ["-y", "@playwright/mcp", "--cdp-endpoint", "http://${PLAYWRIGHT_HOST}:9222"]
startup_timeout_sec = 15.0
tool_timeout_sec = 30.0
MCPEOF
  fi
} > "${CONFIG_TOML}.tmp"

mv "${CONFIG_TOML}.tmp" "${CONFIG_TOML}"

# Log what was configured (to stdout, not into the config file)
if [ "${ENABLE_MCP}" = "true" ]; then
  echo "[INFO] MCP 'homeassistant' configured (token passed at runtime via launcher)"
else
  echo "[INFO] MCP disabled"
fi
if [ "${ENABLE_PLAYWRIGHT}" = "true" ]; then
  echo "[INFO] MCP 'playwright' configured (CDP: http://${PLAYWRIGHT_HOST}:9222)"
else
  echo "[INFO] Playwright MCP disabled"
fi

# ---------------------------------------------------------------------------
# Terminal theme
# ---------------------------------------------------------------------------
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
