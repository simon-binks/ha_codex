# Robson Felix's Home Assistant Add-ons

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Custom add-ons for Home Assistant.

## Add-ons

### Claude Code

Run [Claude Code](https://docs.anthropic.com/en/docs/claude-code), Anthropic's AI coding assistant, directly inside Home Assistant to create automations, debug configurations, and manage your smart home with natural language.

#### Features

- **Web Terminal**: Access Claude Code from your Home Assistant sidebar via ttyd
- **Full Config Access**: Read and write Home Assistant configuration files
- **hass-mcp Integration**: Claude can directly interact with your HA entities and services
- **Session Persistence**: Optional tmux support to maintain sessions across page refreshes
- **Multi-Architecture**: Supports amd64, aarch64, armv7, armhf, and i386
- **Secure Authentication**: Claude Code handles its own authentication - no API keys stored in Home Assistant

#### Quick Start

Once installed, open the Claude Code panel from your sidebar and try:

```bash
claude "List all my automations"
claude "Create an automation to turn on lights at sunset"
claude "Check my configuration.yaml for errors"
```

## Installation

1. Add this repository to your Home Assistant add-on store:

   [![Add Repository](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Frobsonfelix%2Frobsonfelix-hass-addons)

   Or manually:
   - Go to **Settings** > **Add-ons** > **Add-on Store**
   - Click the menu (three dots) > **Repositories**
   - Add: `https://github.com/robsonfelix/robsonfelix-hass-addons`

2. Find and install the desired add-on

3. Start the add-on and open the Web UI

## Requirements

- Home Assistant OS or Supervised installation

## Documentation

See [claudecode/DOCS.md](claudecode/DOCS.md) for Claude Code documentation.

## Support

- [Report Issues](https://github.com/robsonfelix/robsonfelix-hass-addons/issues)

## License

MIT License - see [LICENSE](LICENSE) for details.
