# Codex Code for Home Assistant

Run a Codex/OpenAI-oriented development terminal directly in your Home Assistant sidebar with access to your configuration files.

## Overview

This add-on provides:
- Ingress web terminal (ttyd)
- Optional tmux-backed session persistence
- Home Assistant API environment wiring (`SUPERVISOR_TOKEN`, `HA_TOKEN`, `HA_URL`)
- Optional MCP-related toggles for manual client configuration
- Multi-architecture images (amd64, aarch64, armv7, armhf, i386)

This scaffold intentionally avoids vendor-specific CLI startup commands so you can use your preferred OpenAI-compatible tooling.

## Quick Start

1. Install the add-on and start it.
2. Open the add-on Web UI from the Home Assistant sidebar.
3. Use the terminal to run your preferred coding assistant CLI.

## Features

- **Web Terminal**: Browser terminal in Home Assistant ingress
- **Config Access**: Read/write Home Assistant configuration under `/homeassistant`
- **Session Persistence**: Optional tmux session reuse across reconnects
- **Theme Controls**: Dark/light theme and terminal font size options
- **MCP Toggle**: Keep MCP support optional without hard-coding client commands

## Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `enable_mcp` | Enable MCP mode (client-side configuration still required) | true |
| `enable_playwright_mcp` | Enable Playwright MCP mode hints | false |
| `playwright_cdp_host` | Optional Playwright CDP host override | "" |
| `terminal_font_size` | Font size (10-24) | 14 |
| `terminal_theme` | `dark` or `light` | dark |
| `working_directory` | Startup directory | /homeassistant |
| `session_persistence` | Use tmux for persistent sessions | true |
| `auto_update_codex` | Try to update globally installed Codex package (if present) | false |

## File Locations

| Path | Description | Access |
|------|-------------|--------|
| `/homeassistant` | HA configuration directory | read-write |
| `/share` | Shared folder | read-write |
| `/media` | Media folder | read-write |
| `/ssl` | SSL certificates | read-only |
| `/backup` | Backups | read-only |

## Session Persistence

When `session_persistence` is enabled, the add-on uses tmux and attaches to session `codex`.

- Session survives browser refreshes
- You can detach/reattach to keep work running
- Scrollback is increased for long-running tasks

## Security Notes

- The add-on receives Home Assistant supervisor context via built-in add-on APIs.
- Credentials for third-party CLIs are managed by those CLIs, not by add-on options.
- Access is constrained to mapped Home Assistant paths inside the container.

## Troubleshooting

### Terminal does not load

1. Confirm the add-on is running.
2. Refresh the ingress page.
3. Check add-on logs for ttyd startup failures.

### Session does not persist

1. Set `session_persistence` to `true`.
2. Restart the add-on.
3. Reconnect to the ingress terminal.

### MCP integration is unavailable

1. Ensure `enable_mcp` is `true`.
2. Configure MCP in your chosen CLI/client manually.
3. Restart the add-on after changing options.

### MCP action reported failed but HA state changed

Some `hass-mcp` action responses can fail strict response validation in Codex even when Home Assistant applied the action successfully.

Workaround:
1. Ask Codex to verify state after each action.
2. Use prompts like: `Turn on switch.sad_lamp, then read back its state and confirm success only if it is on.`
3. Prefer domain-focused queries (`light`, `switch`, `climate`) for faster responses.

## Support

- [GitHub Issues](https://github.com/robsonfelix/robsonfelix-hass-addons/issues)
- [Home Assistant Community](https://community.home-assistant.io/)
