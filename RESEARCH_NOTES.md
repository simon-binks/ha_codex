# Research Notes — CodexCode Addon Development

These are working notes for development. Delete before final release.

---

## hass-mcp v0.1.1 — Tool Inventory & Bug Status

**Repo**: https://github.com/voska/hass-mcp
**PyPI**: hass-mcp 0.1.1 (Aug 2025)
**Bug tracker**: Issue #29, PR #36 (unmerged)

### All 12 MCP Tools

| Tool | Status | Notes |
|------|--------|-------|
| `get_version` | ✅ Works | No params |
| `get_entity(entity_id, fields?, detailed?)` | ✅ Works | `fields` must be a LIST e.g. `["state"]` not a string `"state"` |
| `search_entities_tool(query, limit?)` | ✅ Works | limit default 20 |
| `list_entities(domain?, search_query?, limit?, fields?, detailed?)` | ✅ Works | limit default 100 |
| `domain_summary_tool(domain)` | ✅ Works | |
| `system_overview()` | ✅ Works | |
| `list_automations()` | ✅ Works | |
| `get_history(entity_id, hours?)` | ✅ Works | hours default 24 |
| `get_error_log()` | ✅ Works | |
| `entity_action(entity_id, action, params?)` | ❌ BROKEN | Returns list, declared as dict. "Unexpected response type". Action DOES execute on HA side despite error. |
| `call_service_tool(domain, service, data?)` | ❌ BROKEN | Same return-type bug. "dict_type validation error". Action DOES execute. |
| `restart_ha()` | ⚠️ Untested | Likely same return-type bug |

### Key Parameter Gotchas (observed in screenshot)
- `get_entity` `fields` param: must be `["state"]` (list), NOT `"state"` (string). Codex got this wrong first try.
- `entity_action` `action`: use `"on"` / `"off"` / `"toggle"`, NOT `"turn_on"`
- `call_service_tool` `data`: must be a dict object, not a JSON string

### Workarounds for broken action tools

**`ha` CLI does NOT work** — the `ha` command inside the addon container does NOT have a `service` subcommand. Running `ha service call ...` gives "unknown command". The `ha` CLI in the addon is the HA Supervisor CLI, not the full HA CLI.

**`curl` to REST API WORKS** — confirmed in screenshot:
```bash
curl -s -X POST http://supervisor/core/api/services/<domain>/<service> \
  -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"entity_id": "<entity_id>"}'
```

### What the screenshot showed (v1.5.3 in action)
1. User: "turn on the office fire"
2. Codex correctly used `search_entities_tool` to find entity ✅
3. Codex correctly avoided `entity_action` (read AGENTS.md) ✅
4. Codex planned to use `ha service call` — but it FAILED: "unknown command 'service' for 'ha'"
5. Codex fell back to `curl` — WORKED ✅
6. Codex tried `get_entity` with `fields: "state"` (string) — FAILED
7. Codex corrected to `fields: ["state"]` (list) — WORKED ✅
8. User: "now turn it off" — Codex went straight to curl — WORKED ✅
9. Codex verified with `get_entity` using correct list syntax — WORKED ✅

### Improvements needed in AGENTS.md
- REMOVE `ha service call` as a workaround — it doesn't work in the addon container
- Make `curl` the PRIMARY and ONLY action method
- Document `get_entity` `fields` must be a list
- Provide copy-paste curl templates

---

## Codex CLI — Config & Context

**Config**: TOML at `~/.codex/config.toml`
**Auth**: JSON at `~/.codex/auth.json`
**Context**: Auto-discovers `AGENTS.md` from `~/.codex/AGENTS.md`, `<git-root>/AGENTS.md`, `<cwd>/AGENTS.md`
**Size limit**: `project_doc_max_bytes` — must be a QUOTED STRING in TOML, e.g. `"65536"` not `65536`
**MCP config**: `[mcp_servers.<name>]` sections in config.toml
**Approval policy**: Global only (`untrusted`/`on-failure`/`on-request`/`never`) — no per-tool allowlists

---

## Addon Architecture

- HA addon = Docker container managed by HA Supervisor
- Config: `config.yaml`, `build.yaml`, `Dockerfile`, `apparmor.txt`
- Persistent storage: `/homeassistant/.codexcode/` (symlinked to `~/.codex`)
- Terminal: ttyd on port 7681 with ingress
- MCP launcher: `hass-mcp-launcher.sh` reads `${SUPERVISOR_TOKEN}` at runtime (not baked in)
- SUPERVISOR_TOKEN rotates on addon restart

---

## File Locations

- Repo root: `/Users/simon/Documents/GitHub/CodexAddon/codexcode/`
- Addon dir: `codexcode/codexcode/` (HA requires this nesting)
- Startup script: `codexcode/codexcode/rootfs/usr/local/bin/start.sh`
- Dockerfile: `codexcode/codexcode/Dockerfile`
- AGENTS.md source: `codexcode/codexcode/rootfs/usr/local/share/AGENTS.md`
- Config: `codexcode/codexcode/config.yaml`
- Changelog: `codexcode/codexcode/CHANGELOG.md`
