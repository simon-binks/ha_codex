# Changelog

All notable changes to this add-on are documented here.

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
