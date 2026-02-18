# Changelog

All notable changes to this add-on are documented here.

## [1.5.1] - 2026-02-18

### Fixed
- `project_doc_max_bytes` in config.toml now written as a TOML string (`"65536"`) — Codex CLI rejects bare integers for this key.

## [1.5.0] - 2026-02-18

### Added
- Comprehensive Home Assistant reference context (~60KB `AGENTS.md`) auto-loaded by Codex CLI. Covers: file structure, configuration.yaml, entity naming, all automation trigger/condition/action types, full service call reference by domain, Jinja2 template syntax, scenes, input helpers, template sensors, dashboard/Lovelace cards, MQTT patterns, Zigbee2MQTT entity conventions, ESPHome patterns, blueprints, shell/REST commands, and debugging patterns.
- `project_doc_max_bytes = 65536` added to config.toml to accommodate the full reference.

### Changed
- Replaced runtime-generated `CODEX.md` and `HA_TUNING.md` with a single baked-in `AGENTS.md` deployed from the container image — faster startup, richer content.
- Updated `SESSION_PROMPT.txt` to reference `AGENTS.md` context.

## [1.4.0] - 2026-02-16

### Changed
- Write MCP config directly to `config.toml` instead of spawning `codex mcp add/remove` CLI commands — eliminates multiple Node.js process spawns during startup for faster boot.
- Read all add-on options in a single `jq` call instead of seven separate invocations.
- Load session prompt once at shell startup instead of subshelling on every `codex-ha` alias invocation.
- Removed redundant `npm list -g` check before auto-update — `npm update` already handles missing packages gracefully.
- Removed unused symlinks (`/root/.codex.json`, `/root/.config/codex`) that don't match actual Codex CLI config paths.

### Fixed
- MCP launcher now reads `SUPERVISOR_TOKEN` at runtime instead of baking in the token at startup — fixes stale-token HTTP 500 errors after addon restarts.
- `SUPERVISOR_TOKEN` is passed via `[mcp_servers.homeassistant.env]` in config.toml so it is available to child processes.
- MCP config regeneration now preserves existing user customisations (model, approval_policy, etc.) in `config.toml`.

## [1.3.8] - 2026-02-14

### Changed
- Added `codex-ha` alias for Home Assistant-tuned Codex sessions.
- Startup now generates `/homeassistant/.codexcode/HA_TUNING.md` with Codex-specific MCP usage rules.
- Startup now generates `/homeassistant/.codexcode/SESSION_PROMPT.txt` used by `codex-ha` for faster, targeted HA workflows.
- Added README guidance for reducing latency and improving HA task reliability in Codex.

## [1.3.7] - 2026-02-14

### Fixed
- Added device-auth login path for Codex to avoid ingress `localhost` callback failures.

### Changed
- Added `codex-login` shell alias (`codex login --device-auth`) for first-time sign-in.
- Documented callback-login troubleshooting and device auth workflow in README and startup guidance.

## [1.3.6] - 2026-02-12

### Changed
- Added explicit Home Assistant action reliability guidance to startup `CODEX.md`.
- Documented Codex strict validation behavior for `hass-mcp` action calls in README troubleshooting.
- Added recommended "write then verify state" workflow for state-changing actions.

## [1.3.5] - 2026-02-12

### Fixed
- Home Assistant MCP launcher now exports `HA_URL` and `HA_TOKEN` directly before starting `hass-mcp`.
- Removed dependency on `.env` file parsing for MCP authentication bootstrap.

### Changed
- Added startup guidance to prefer domain-focused MCP queries for better performance.

## [1.3.4] - 2026-02-12

### Fixed
- Allowed execute permission for add-on managed MCP launcher scripts under `/homeassistant/.codexcode/mcp/**`.
- Fixes `Permission denied (os error 13)` when starting the Home Assistant MCP client.

## [1.3.3] - 2026-02-12

### Fixed
- Corrected Codex MCP registration for Home Assistant.
- Removed incompatible `--cwd` usage from `codex mcp add`.
- Added startup launcher script so `hass-mcp` runs from the add-on managed MCP directory with the correct `.env`.

## [1.3.1] - 2026-02-12

### Fixed
- Restored automatic MCP bootstrap at startup for Codex CLI.
- Home Assistant MCP now uses an isolated add-on managed `.env` under `/homeassistant/.codexcode/mcp/homeassistant`.
- Optional Playwright MCP registration now bootstraps automatically when enabled.

## [1.3.0] - 2026-02-12

### Changed
- Renamed add-on metadata and branding from Claude Code to Codex Code.
- Renamed startup option `auto_update_claude` to `auto_update_codex`.
- Renamed AppArmor profile from `claudecode` to `codexcode`.

### Fixed
- Translation keys now match the active option schema (`auto_update_codex`).
- Updated localized descriptions to Codex/OpenAI-oriented wording.

### Refactored
- Moved long inline Docker startup logic into `/usr/local/bin/start.sh`.
- Simplified container startup command to `CMD ["/usr/local/bin/start.sh"]`.

### Removed
- Removed Claude CLI installation from the image build.
- Removed Claude-specific startup command invocations and aliases.
