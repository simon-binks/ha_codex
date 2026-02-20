# Changelog

All notable changes to this add-on are documented here.

## [1.5.17] - 2026-02-20

### Changed
- Replaced `logo.png` and `icon.png` with the official Codex desktop app icon asset.

## [1.5.16] - 2026-02-20

### Changed
- Updated add-on branding assets: replaced `logo.png` and `icon.png` with Codex-branded imagery.

## [1.5.15] - 2026-02-20

### Changed
- Updated bundled Codex CLI install to `@openai/codex@0.104.0` in the image build.
- Pins CLI version in Dockerfile to avoid stale cached layers keeping older Codex versions.

## [1.5.14] - 2026-02-20

### Changed
- Reduced routine HA action overhead by treating successful Hass* action responses as sufficient verification for simple on/off commands.
- Instructed agents to avoid `GetLiveContext` for routine single-device toggles unless action output is ambiguous or deeper validation is explicitly requested.
- Added explicit rule to skip MCP capability inventory calls (`list_mcp_resources`, tool catalog checks) unless the user asks for MCP inspection.
- Updated startup session prompt to favor one-call Hass* control flow and suppress unnecessary preflight checks.

## [1.5.13] - 2026-02-20

### Changed
- Switched Home Assistant MCP primary server to HTTP MCP at `http://supervisor/core/api/mcp` using `SUPERVISOR_TOKEN` bearer auth.
- Added dual-server setup: `homeassistant` (HTTP primary) + `homeassistant_legacy` (`hass-mcp` fallback/extra capability).
- Updated startup MCP generation/logging to reflect primary HTTP + legacy fallback wiring.
- Updated `AGENTS.md` to explicitly prioritize `homeassistant` (Hass* tools) and only use `homeassistant_legacy` for missing capabilities.

## [1.5.12] - 2026-02-20

### Changed
- Tightened `AGENTS.md` MCP action rules to force a minimal legacy flow for routine on/off commands: at most one search, one action, one verification.
- Added explicit instruction to suppress planning narration for routine HA control requests and return concise outcomes.
- Updated startup `SESSION_PROMPT.txt` guidance to execute routine MCP commands directly without verbose preambles.

## [1.5.11] - 2026-02-19

### Fixed
- Restored Home Assistant MCP startup compatibility by reinstalling `hass-mcp` in the image.
- Restored launcher fallback to `hass-mcp` when Hass* MCP binaries (`homeassistant-mcp`, `home-assistant-mcp`, `ha-mcp`) are not present.
- Fixes MCP client startup/handshake failures introduced in 1.5.10 on systems without a Hass* MCP binary installed.

## [1.5.10] - 2026-02-19

### Changed
- Removed `hass-mcp` as an installed dependency from the add-on image.
- Updated Home Assistant MCP launcher to support only Hass* MCP backends (`homeassistant-mcp`, `home-assistant-mcp`, `ha-mcp`) and fail fast if none are present.
- Removed legacy `hass-mcp` guidance from `AGENTS.md` and aligned action guidance with the Hass* toolset.
- Updated README troubleshooting and AppArmor wording to reflect Home Assistant MCP-only behavior.

## [1.5.9] - 2026-02-19

### Changed
- Added MCP action fast-path guidance in `AGENTS.md` to reduce latency for routine control requests.
- Instructed single-discovery default (`search -> act -> verify`) and to avoid extra entity scans unless the first result is ambiguous.
- Added query-size guidance to avoid broad `limit: 100` discovery calls for simple on/off commands.

## [1.5.8] - 2026-02-19

### Changed
- Updated Home Assistant MCP launcher to prefer newer HA MCP binaries that expose `HassTurnOn`/`HassTurnOff`, with compatibility fallback to `hass-mcp`.
- Renamed launcher script wiring to `ha-mcp-launcher.sh` and updated generated Codex MCP config to use it.
- Updated `AGENTS.md` action guidance to explicitly prioritize `HassTurnOn`/`HassTurnOff` when available.

## [1.5.7] - 2026-02-19

### Changed
- Updated `AGENTS.md` MCP action guidance to avoid sending empty optional slots (`[]`, `\"\"`, `null`) to Home Assistant tools.
- Added explicit rule to prefer minimal `HassTurnOn`/`HassTurnOff` calls (e.g., `name` only) and only add extra fields for disambiguation.
- Documented `invalid slot info` as a slot-formatting issue and instructed retry with populated fields only.

## [1.5.6] - 2026-02-19

### Changed
- Refined and de-duplicated `AGENTS.md` to keep MCP-first Home Assistant workflows while reducing prompt bloat.
- Reworked MCP guidance into a clear discover -> act -> verify flow with explicit ambiguous-result handling.
- Trimmed repetitive reference sections (services, Lovelace cards, triggers/conditions, MQTT/Zigbee2MQTT/ESPHome/Blueprint selectors) while retaining core HA configuration knowledge.

## [1.5.5] - 2026-02-19

### Changed
- AGENTS.md now instructs Codex to use MCP `call_service_tool` and `entity_action` for all HA actions — the tools execute successfully despite reporting errors.
- Added "ignore the error, verify with get_entity" workflow so Codex stays on MCP instead of falling back to curl.
- Removed curl-based workaround as primary method (was causing Codex to bypass MCP entirely).

## [1.5.4] - 2026-02-19

### Fixed
- Removed `ha service call` workaround from AGENTS.md — `ha` CLI inside the addon does not support `service` subcommand.
- `curl` to HA REST API is now the only documented action method, with copy-paste templates.
- Documented `get_entity` `fields` parameter must be a list (`["state"]` not `"state"`).
- Added parameter table for all working MCP tools with types and gotchas.
- Added explicit 3-step workflow: search → curl → verify.

## [1.5.3] - 2026-02-19

### Added
- MCP tool usage guide in AGENTS.md — documents which hass-mcp tools work reliably and which are broken (`entity_action`, `call_service_tool` have upstream return-type bugs in hass-mcp v0.1.1).
- Workaround instructions for device control via `ha` CLI and REST API `curl` commands.
- Recommended workflow: use MCP for reads, `ha service call` for actions, MCP to verify state.

## [1.5.2] - 2026-02-18

### Fixed
- Existing `config.toml` with bare-integer `project_doc_max_bytes` is now corrected on every startup via sed — fixes persistent TOML parse error on devices that ran v1.5.0.

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
