# Home Assistant Configuration Reference for AI Coding Assistants

This file provides the technical reference an AI assistant needs to write, debug,
and modify Home Assistant (HA) configuration files. The HA config directory is
mounted at `/homeassistant` inside the add-on container (equivalent to `/config`
in HA Core documentation).

---

## 0. MCP Tool Usage — READ THIS FIRST

You have Home Assistant MCP tools. Use MCP as the primary interaction layer for reads and actions.

### Core behavior rules
1. Prefer targeted queries (`domain`, `entity_id`, search terms). Avoid full dumps unless requested.
2. Resolve entity IDs before acting (`search_entities_tool` or `list_entities`).
3. For state-changing actions, always follow: discover -> act -> verify.
4. Verification is mandatory: call `get_entity` with `fields: ["state"]` after each action.
5. Never report success from tool status alone. Report success only from verified post-action state.
6. If action result is ambiguous, retry once, then stop and surface exact error + current state.
7. Use read tools first when uncertain (`domain_summary_tool`, `system_overview`, `list_automations`, `get_history`, `get_error_log`).
8. For Home Assistant action tools, do not send empty optional slots. Omit unset fields entirely (avoid `[]`, `""`, `null` placeholders).
9. For `HassTurnOn`/`HassTurnOff`, prefer minimal valid arguments first (often `name` only), then add `area`/`floor`/`domain` only if disambiguation is needed.
10. If `HassTurnOn`/`HassTurnOff` tool family is available, prefer it over legacy `entity_action`/`call_service_tool`.

### MCP tool reference
| Tool | Parameters | Notes |
|------|-----------|-------|
| `search_entities_tool` | `query` (str), `limit` (int, default 20) | Find likely entity IDs quickly |
| `get_entity` | `entity_id` (str), `fields` (list), `detailed` (bool) | **`fields` MUST be a list**: `["state"]` not `"state"` |
| `list_entities` | `domain` (str?), `search_query` (str?), `limit` (int), `fields` (list?), `detailed` (bool) | Best for domain-scoped discovery |
| `domain_summary_tool` | `domain` (str) | Fast domain health snapshot |
| `system_overview` | none | Broad system context |
| `list_automations` | none | Automation inventory and status |
| `get_history` | `entity_id` (str), `hours` (int, default 24) | Verify behavior over time |
| `get_error_log` | none | Check runtime failures |
| `get_version` | none | HA/core integration version checks |
| `call_service_tool` | `domain` (str), `service` (str), `data` (dict) | Primary general action method |
| `entity_action` | `entity_id` (str), `action` (str), `params` (dict?) | Simple on/off/toggle actions |

### Tool gotchas and error handling
- `get_entity` `fields` must be a list, not a string.
- Prefer `HassTurnOn`/`HassTurnOff` where available (cleaner action contract, less response-shape ambiguity).
- `entity_action` values are `"on"`, `"off"`, `"toggle"` (not `"turn_on"`/`"turn_off"`).
- In assistants that expose `HassTurnOn`/`HassTurnOff`, empty optional slots can trigger "invalid slot info" errors. Pass only populated fields.
- In some `hass-mcp` versions, action tools may return response-type validation errors even when HA applied the action.
- Treat those errors as ambiguous results, not automatic success or failure.
- Immediate follow-up check:
  `get_entity(entity_id=..., fields=["state"])`
- If state matches target: report success.
- If state does not match target: retry action once and re-check.
- If still not matched: report failure with exact error and observed state.

### Practical playbooks
1. Toggle device
   - Discover entity -> act (`call_service_tool` or `entity_action`) -> verify state.
2. Set a value (brightness/temperature/mode)
   - Discover entity -> call specific service with `data` -> verify changed state/attributes.
3. Debug "automation didn't run"
   - `list_automations` -> check related entity history (`get_history`) -> inspect `get_error_log`.

---

## 1. File Structure (`/homeassistant`)

```
/homeassistant/
  configuration.yaml          # Main config - top-level integration keys
  automations.yaml             # UI-created automations (list format)
  scripts.yaml                 # UI-created scripts (mapping format)
  scenes.yaml                  # UI-created scenes (list format)
  secrets.yaml                 # Sensitive values (passwords, API keys, tokens)
  home-assistant.log           # Runtime log (tail for debugging)
  .storage/                    # Internal state DB - DO NOT manually edit
  custom_components/           # Custom integrations (each in its own subdirectory)
    custom_domain/
      __init__.py
      manifest.json
      sensor.py / switch.py / ...
  www/                         # Static files served at /local/ in dashboards
  blueprints/
    automation/                # Automation blueprints
      homeassistant/           # Built-in blueprints
      custom_user/             # User-imported blueprints
    script/                    # Script blueprints
  themes/                      # Custom themes (YAML files)
  packages/                    # Package YAML files (if using packages)
  dashboards/                  # YAML dashboard files (if using YAML mode)
  tts/                         # Cached text-to-speech audio
```

### Key Rules
- **Never edit `.storage/`** -- this is HA's internal database. Corruption breaks the instance.
- **`secrets.yaml`** stores sensitive values. Reference with `!secret key_name` in any YAML file.
- **`custom_components/`** overrides built-in integrations when the domain name matches.
- **`www/`** files are served at URL path `/local/` (e.g., `www/icon.png` = `/local/icon.png`).

---

## 2. `configuration.yaml` Structure

### Common Top-Level Keys

```yaml
homeassistant:
  name: "My Home"
  latitude: 52.3731
  longitude: 4.8924
  elevation: 0
  unit_system: metric
  currency: EUR
  time_zone: "Europe/Amsterdam"
  country: NL
  language: en
  packages: !include_dir_named packages/   # Package system
  customize:                               # Per-entity overrides
    light.living_room:
      friendly_name: "Living Room Light"

default_config:          # Loads many default integrations (history, logbook, etc.)

logger:
  default: warning
  logs:
    homeassistant.components.mqtt: debug
    custom_components.mycomp: debug
    aiohttp: error
  filters:                           # Regex patterns to suppress matching log entries
    homeassistant.components.mqtt:
      - ".*Timeout.*"
    custom_components.mycomp:
      - "HTTP 429"

recorder:
  db_url: "sqlite:////homeassistant/home-assistant_v2.db"
  purge_keep_days: 10
  commit_interval: 5                 # Seconds between DB commits (increase to reduce SD wear)
  auto_purge: true                   # Auto-purge old data
  exclude:
    domains:
      - automation
      - updater
    entities:
      - sensor.noisy_sensor
    entity_globs:                    # Wildcard matching (* and ?)
      - sensor.weather_*
      - binary_sensor.update_*
    event_types:
      - call_service
  include:                           # If both include + exclude: include first, then exclude filters
    domains:
      - sensor
      - binary_sensor
    entities:
      - sensor.important_one

automation: !include automations.yaml
automation manual: !include_dir_merge_list automations/  # Hand-coded automations
script: !include scripts.yaml
scene: !include scenes.yaml
group: !include groups.yaml

# Integration-specific top-level keys
mqtt:
light:
switch:
sensor:
binary_sensor:
climate:
cover:
media_player:
input_boolean:
input_number:
input_select:
input_text:
input_datetime:
template:
rest_command:
shell_command:
notify:
```

### Include Directives

| Directive | Returns | Use Case |
|-----------|---------|----------|
| `!include file.yaml` | File contents at that position | Single file inclusion |
| `!include_dir_list dir/` | List from files (each file = one item) | Automations split per file |
| `!include_dir_named dir/` | Dict mapping filename to content | Groups, packages |
| `!include_dir_merge_list dir/` | Merged list from all files | Multiple automations per file |
| `!include_dir_merge_named dir/` | Merged dict from all files | Merging named configs |

Rules:
- Files **must** use `.yaml` extension (not `.yml`).
- Directory includes work **recursively** into subdirectories.
- Combine UI and manual automations with labeled keys:
  ```yaml
  automation ui: !include automations.yaml
  automation manual: !include_dir_merge_list automations/
  ```

### Packages

Packages bundle related config (entities, automations, scripts) into a single file:

```yaml
# configuration.yaml
homeassistant:
  packages: !include_dir_named packages/

# packages/kitchen.yaml
input_boolean:
  kitchen_occupied:
    name: "Kitchen Occupied"
automation:
  - alias: "Kitchen motion light"
    triggers:
      - trigger: state
        entity_id: binary_sensor.kitchen_motion
        to: "on"
    actions:
      - action: light.turn_on
        target:
          entity_id: light.kitchen
```

Restrictions:
- Platform-based integrations (light, switch) always merge.
- Entity-keyed integrations (input_boolean, input_number) require globally unique keys.
- `auth_providers` must stay in `configuration.yaml` (processed before packages load).

### Secrets

```yaml
# secrets.yaml
mqtt_password: "s3cret_passw0rd"
api_key: "abc123def456"

# configuration.yaml (or any included file)
mqtt:
  password: !secret mqtt_password
```

HA searches for `secrets.yaml` starting in the same directory as the referencing file, then walks up to the config root.

---

## 3. Entity Naming Conventions

### Format: `domain.object_id`

- Domain = predefined category (not user-definable)
- Object ID = lowercase alphanumeric + underscores (`[a-z0-9_]`)
- Must be globally unique

### Common Domains

| Domain | Purpose | Example Entity IDs |
|--------|---------|-------------------|
| `light` | Lighting control | `light.kitchen_ceiling`, `light.bedroom_lamp` |
| `switch` | Binary on/off devices | `switch.garden_pump`, `switch.heater` |
| `sensor` | Numeric/text measurements | `sensor.temperature_living`, `sensor.cpu_load` |
| `binary_sensor` | On/off state sensors | `binary_sensor.front_door`, `binary_sensor.motion_hall` |
| `climate` | HVAC / thermostats | `climate.living_room`, `climate.bedroom_ac` |
| `cover` | Blinds, garage doors, shades | `cover.garage_door`, `cover.kitchen_blinds` |
| `media_player` | Speakers, TVs, receivers | `media_player.living_room_tv`, `media_player.sonos` |
| `fan` | Fan speed control | `fan.ceiling_fan`, `fan.bathroom_exhaust` |
| `lock` | Door locks | `lock.front_door`, `lock.back_door` |
| `vacuum` | Robot vacuums | `vacuum.roborock`, `vacuum.roomba` |
| `camera` | Video feeds | `camera.front_porch`, `camera.baby_room` |
| `alarm_control_panel` | Security systems | `alarm_control_panel.home_alarm` |
| `device_tracker` | Presence detection | `device_tracker.phone_simon`, `device_tracker.laptop` |
| `person` | Person entities (groups trackers) | `person.simon`, `person.jane` |
| `weather` | Weather data | `weather.home`, `weather.openweathermap` |
| `update` | Software update availability | `update.home_assistant_core_update` |
| `automation` | Automations themselves | `automation.kitchen_motion_light` |
| `script` | Scripts themselves | `script.flash_lights` |
| `scene` | Scenes | `scene.movie_night` |
| `input_boolean` | Virtual toggle helper | `input_boolean.guest_mode` |
| `input_number` | Virtual number helper | `input_number.target_temperature` |
| `input_select` | Virtual dropdown helper | `input_select.house_mode` |
| `input_text` | Virtual text helper | `input_text.notification_message` |
| `input_datetime` | Virtual date/time helper | `input_datetime.alarm_time` |
| `input_button` | Virtual button helper | `input_button.reset_counter` |
| `counter` | Increment/decrement counter | `counter.visitors` |
| `timer` | Countdown timer | `timer.kitchen_timer` |
| `number` | Numeric control (integration) | `number.fan_speed` |
| `select` | Dropdown (integration) | `select.washer_mode` |
| `button` | Trigger action (integration) | `button.restart_device` |
| `text` | Text input (integration) | `text.display_message` |
| `siren` | Alarm sirens | `siren.indoor_alarm` |
| `valve` | Fluid flow control | `valve.sprinkler_zone_1` |
| `water_heater` | Water heater control | `water_heater.boiler` |
| `humidifier` | Humidity control | `humidifier.bedroom` |
| `lawn_mower` | Autonomous mowers | `lawn_mower.husqvarna` |
| `event` | Event entities | `event.doorbell_press` |
| `todo` | To-do lists | `todo.shopping_list` |
| `calendar` | Calendar entities | `calendar.family_events` |
| `remote` | IR/RF remote control | `remote.living_room` |
| `tts` | Text-to-speech | (service domain, not entities) |
| `notify` | Notifications | (service domain, not entities) |
| `zone` | Geographic zones | `zone.home`, `zone.work` |
| `sun` | Sun position | `sun.sun` |

### Common Entity Attributes by Domain

| Domain | Key Attributes |
|--------|---------------|
| `light` | `brightness` (0-255), `color_temp_kelvin`, `rgb_color` ([r,g,b]), `hs_color` ([h,s]), `xy_color`, `effect_list`, `effect`, `supported_color_modes`, `color_mode`, `min_color_temp_kelvin`, `max_color_temp_kelvin` |
| `climate` | `current_temperature`, `temperature` (target), `target_temp_high`, `target_temp_low`, `hvac_mode`, `hvac_modes` (list), `hvac_action` (heating/cooling/idle/off), `fan_mode`, `fan_modes`, `preset_mode`, `preset_modes`, `swing_mode`, `humidity`, `min_temp`, `max_temp` |
| `cover` | `current_position` (0-100), `current_tilt_position`, `is_opening`, `is_closing` |
| `media_player` | `media_title`, `media_artist`, `media_album_name`, `media_content_type`, `media_duration`, `media_position`, `source`, `source_list`, `volume_level` (0.0-1.0), `is_volume_muted`, `shuffle`, `repeat`, `group_members` |
| `fan` | `percentage` (0-100), `preset_mode`, `preset_modes`, `oscillating`, `direction` |
| `sensor` | `unit_of_measurement`, `device_class`, `state_class`, `last_reset` |
| `binary_sensor` | `device_class` (determines icon: motion, door, window, moisture, etc.) |
| `vacuum` | `battery_level`, `fan_speed`, `fan_speed_list`, `status` |
| `lock` | `is_locked`, `is_jammed` |
| `weather` | `temperature`, `humidity`, `pressure`, `wind_speed`, `wind_bearing`, `forecast` (list), `condition` |
| `person` | `source` (tracker entity), `latitude`, `longitude`, `gps_accuracy` |
| `sun` | `elevation`, `azimuth`, `next_rising`, `next_setting`, `rising` (bool) |
| `alarm_control_panel` | `code_format`, `changed_by`, `code_arm_required` |
| `device_tracker` | `source_type`, `latitude`, `longitude`, `gps_accuracy`, `battery` |
| `calendar` | `message` (current event), `start_time`, `end_time`, `all_day`, `description`, `location` |

Accessing attributes in templates:
```jinja2
{{ state_attr('light.kitchen', 'brightness') }}
{{ state_attr('climate.living_room', 'current_temperature') }}
{{ state_attr('media_player.tv', 'media_title') }}
{{ state_attr('cover.blinds', 'current_position') }}
```

### Naming Best Practices
- Use `area_device_function` pattern: `sensor.kitchen_thermostat_temperature`
- Avoid special characters and spaces
- Keep names short but descriptive

---

## 4. Automation Format

### Complete Schema

```yaml
# In automations.yaml (list format, UI-compatible)
- id: "unique_id_string"         # Required for UI editing and trace debugging
  alias: "Human-Readable Name"   # Display name
  description: "What this does"  # Optional documentation
  mode: single                   # single | restart | queued | parallel
  max: 10                        # Max concurrent runs (for queued/parallel)
  max_exceeded: warning          # Log level when max exceeded (or "silent")
  initial_state: true            # Force on/off at HA startup (optional)
  variables:                     # Template variables for conditions/actions
    my_var: "{{ states('sensor.temp') }}"
  trigger_variables:             # Limited template variables for triggers
    threshold: 25
  trace:
    stored_traces: 10            # Number of debug traces to keep
  triggers:                      # REQUIRED - what starts the automation
    - trigger: state
      entity_id: binary_sensor.motion
      to: "on"
  conditions:                    # Optional - must ALL be true to proceed
    - condition: state
      entity_id: input_boolean.enabled
      state: "on"
  actions:                       # REQUIRED - what to do
    - action: light.turn_on
      target:
        entity_id: light.hallway
```

### Automation Modes

| Mode | Behavior |
|------|----------|
| `single` | (default) Ignores new triggers while running. Logs warning. |
| `restart` | Stops current run, starts fresh from new trigger. |
| `queued` | Queues new runs. Executes in order after current run finishes. |
| `parallel` | Starts independent parallel runs. |

### Trigger Types

**State trigger** -- entity changes state:
```yaml
- trigger: state
  entity_id:
    - binary_sensor.motion_kitchen
    - binary_sensor.motion_hall
  from: "off"                    # Optional: filter specific transition
  to: "on"                       # Optional: filter specific transition
  for:                           # Optional: state must hold for duration
    minutes: 5
  attribute: brightness          # Optional: trigger on attribute change instead
  not_from:                      # Optional: exclude specific from states
    - "unavailable"
    - "unknown"
  not_to:                        # Optional: exclude specific to states
    - "unavailable"
```

**Numeric state trigger** -- value crosses threshold:
```yaml
- trigger: numeric_state
  entity_id: sensor.temperature
  above: 25                      # Optional: fire when value exceeds this
  below: 30                      # Optional: fire when value drops below this
  attribute: current_temperature # Optional: use attribute instead of state
  value_template: "{{ state.state | float * 9/5 + 32 }}"  # Optional: transform
  for: "00:05:00"                # Optional: must hold for duration
```

**Time trigger** -- fires at specific time:
```yaml
- trigger: time
  at:
    - "07:00:00"                 # Fixed time
    - input_datetime.alarm_time  # Entity providing time
    - entity_id: sensor.next_alarm
      offset: "-00:10:00"       # Offset from entity time
  weekday:                       # Optional: specific days only
    - mon
    - wed
    - fri
```

**Time pattern trigger** -- fires on recurring pattern:
```yaml
- trigger: time_pattern
  hours: "/2"                    # Every 2 hours
  minutes: "/15"                 # Every 15 minutes
  seconds: "/30"                 # Every 30 seconds
```

**MQTT trigger**:
```yaml
- trigger: mqtt
  topic: "home/sensor/temperature"
  payload: "on"                  # Optional: filter by payload
  value_template: "{{ value_json.state }}"  # Optional: extract from JSON
```

**Template trigger** -- fires when template evaluates to true:
```yaml
- trigger: template
  value_template: >
    {{ states('sensor.temperature') | float > 25
       and is_state('input_boolean.ac_enabled', 'on') }}
  for: "00:01:00"                # Optional: must remain true for duration
```

Other supported trigger platforms (usually UI-generated and integration-specific):
- `sun`
- `event`
- `homeassistant` (start/shutdown)
- `webhook`
- `zone`
- `device`
- `calendar`
- `conversation`
- `tag`
- `persistent_notification`
- `geo_location`

### Trigger Features
- Every trigger supports `id:` for referencing in conditions (`condition: trigger`)
- Every trigger supports `enabled: false` to disable without removing
- Every trigger supports `variables:` for trigger-scoped template variables
- The `trigger` variable is available in conditions/actions with context about what fired

### Trigger Variable Namespace

All triggers provide these universal variables:
```jinja2
{{ trigger.platform }}      {# Trigger type: "state", "mqtt", "time", etc. #}
{{ trigger.id }}            {# The trigger's id: field value #}
{{ trigger.idx }}           {# Numeric index (0-based) of which trigger fired #}
{{ trigger.alias }}         {# The trigger's alias field #}
```

Per-platform variables:

| Platform | Key Variables |
|----------|--------------|
| `state` / `numeric_state` | `trigger.entity_id`, `trigger.from_state`, `trigger.to_state`, `trigger.for`, `trigger.above`, `trigger.below` |
| `event` | `trigger.event.event_type`, `trigger.event.data` (dict) |
| `mqtt` | `trigger.topic`, `trigger.payload`, `trigger.payload_json` (parsed dict), `trigger.qos` |
| `webhook` | `trigger.webhook_id`, `trigger.json` (parsed body), `trigger.data` (form data), `trigger.query` (query params) |
| `time` | `trigger.now` (datetime that triggered) |
| `zone` | `trigger.entity_id`, `trigger.from_state`, `trigger.to_state`, `trigger.zone`, `trigger.event` |
| `template` | `trigger.entity_id` (entity that caused re-eval), `trigger.from_state`, `trigger.to_state` |

For less-common platforms (`calendar`, `conversation`, `tag`, `sun`, `homeassistant`, `persistent_notification`, `geo_location`), inspect an existing automation trace/YAML to view exact `trigger.*` fields.

### Condition Types

All conditions listed must be true (implicit AND). Conditions evaluate **current** state, not the state at trigger time.

Most-used condition types:
- `state`
- `numeric_state`
- `time`
- `template`
- `trigger`
- Logical blocks: `and`, `or`, `not`
- Also supported: `sun`, `zone`

```yaml
# State condition
- condition: state
  entity_id: device_tracker.simon
  state: "home"
  for:
    minutes: 10

# Numeric state condition
- condition: numeric_state
  entity_id: sensor.temperature
  above: 17
  below: 25

# Time condition
- condition: time
  after: "22:00:00"
  before: "06:00:00"
  weekday: [sat, sun]

# Template condition
- condition: template
  value_template: "{{ states('sensor.battery') | int(0) > 20 }}"

# Trigger condition (which trigger fired)
- condition: trigger
  id: motion_trigger

# Logical composition
- condition: and
  conditions:
    - condition: state
      entity_id: light.kitchen
      state: "on"
    - condition: numeric_state
      entity_id: sensor.lux
      below: 100

# Shorthand template condition
conditions: "{{ state_attr('sun.sun', 'elevation') < 4 }}"
```

---

## 5. Script Format

Scripts are reusable action sequences. They differ from automations: no triggers,
accept input parameters via `fields`, called manually or by other automations.

### Schema

```yaml
# In scripts.yaml (mapping format) or configuration.yaml under script:
script:
  flash_light:
    alias: "Flash a Light"
    description: "Flashes a light on and off multiple times"
    icon: mdi:flash
    mode: restart                # single | restart | queued | parallel
    max: 10
    fields:                      # Input parameters (shown in UI service call)
      target_light:
        name: "Light"
        description: "Which light to flash"
        required: true
        selector:
          entity:
            domain: light
      count:
        name: "Flash Count"
        description: "Number of flashes"
        default: 3
        selector:
          number:
            min: 1
            max: 20
    variables:
      flash_count: "{{ count | int(3) }}"
    sequence:                    # The action sequence (like 'actions' in automations)
      - action: light.turn_on
        target:
          entity_id: "{{ target_light }}"
      - repeat:
          count: "{{ flash_count }}"
          sequence:
            - delay:
                milliseconds: 500
            - action: light.toggle
              target:
                entity_id: "{{ target_light }}"
```

### Key Differences from Automations

| Aspect | Automation | Script |
|--------|-----------|--------|
| Trigger | Has `triggers:` (event-driven) | No triggers (called explicitly) |
| Parameters | No input fields | Has `fields:` for input parameters |
| Action key | `actions:` | `sequence:` |
| Format in YAML | List (in automations.yaml) | Mapping keyed by script ID |
| Entity created | `automation.name` | `script.name` |
| Calling | Triggered by events | `action: script.script_name` or `action: script.turn_on` |

### Script Flow Controls (usable in both automations and scripts)

Service-call syntax is shared with automations and documented in Section 6 (`action` + `target` + `data`).
This section focuses on script/sequence control primitives.

```yaml
# Delay
- delay: "00:00:30"

# Wait for condition
- wait_template: "{{ is_state('binary_sensor.door', 'off') }}"
  timeout: "00:05:00"
  continue_on_timeout: true

# Wait for trigger
- wait_for_trigger:
    - trigger: state
      entity_id: binary_sensor.door
      to: "off"
  timeout: "00:05:00"

# if/then/else
- if:
    - condition: state
      entity_id: light.kitchen
      state: "on"
  then:
    - action: light.turn_off
      target:
        entity_id: light.kitchen
  else:
    - action: light.turn_on
      target:
        entity_id: light.kitchen

# choose/default
- choose:
    - conditions: "{{ is_state('input_select.mode', 'movie') }}"
      sequence:
        - action: scene.turn_on
          target:
            entity_id: scene.movie_mode
  default:
    - action: scene.turn_on
      target:
        entity_id: scene.default

# repeat (count / while / for_each)
- repeat:
    count: 5
    sequence:
      - action: light.toggle
        target:
          entity_id: light.kitchen
      - delay:
          seconds: 1

# parallel branches
- parallel:
    - action: light.turn_on
      target:
        entity_id: light.kitchen
    - action: media_player.media_play
      target:
        entity_id: media_player.speaker

# variables + stop + continue_on_error
- variables:
    my_var: "{{ states('sensor.temp') | float(0) }}"
- action: notify.notify
  data:
    message: "Attempt notification"
  continue_on_error: true
- stop: "Done"
```

---

## 6. Service Call Format

### Modern Format (2024+)

```yaml
action: domain.service_name
target:
  entity_id: domain.object_id          # Single entity
  # OR
  entity_id:                            # Multiple entities
    - light.kitchen
    - light.bedroom
  # OR
  area_id: kitchen                      # All entities in area
  # OR
  device_id: "abc123"                   # All entities on device
data:
  parameter: value
```

### Universal Services (work on any toggleable entity)

```yaml
action: homeassistant.turn_on
action: homeassistant.turn_off
action: homeassistant.toggle
action: homeassistant.update_entity     # Force state refresh
```

### Common Services by Domain

This is intentionally compact. Keep this as a quick map; use Developer Tools -> Actions in HA UI for integration-specific fields.

| Domain | Most-used services |
|--------|--------------------|
| `light` | `turn_on`, `turn_off`, `toggle` |
| `switch` | `turn_on`, `turn_off`, `toggle` |
| `climate` | `set_temperature`, `set_hvac_mode`, `set_fan_mode`, `set_preset_mode`, `turn_on`, `turn_off` |
| `cover` | `open_cover`, `close_cover`, `stop_cover`, `set_cover_position` |
| `media_player` | `turn_on`, `turn_off`, `media_play`, `media_pause`, `volume_set`, `play_media`, `select_source` |
| `fan` | `turn_on`, `turn_off`, `set_percentage`, `set_preset_mode`, `oscillate`, `set_direction` |
| `lock` | `lock`, `unlock` |
| `vacuum` | `start`, `pause`, `stop`, `return_to_base`, `locate`, `set_fan_speed` |
| `scene` | `turn_on` |
| `script` | `script_name`, `turn_on` |
| `notify` | `notify`, `mobile_app_*` |
| `input_*`, `counter`, `timer` | `set_value`, `select_option`, `set_datetime`, `increment`, `decrement`, `start`, `cancel` |

Representative examples:

```yaml
# Light
action: light.turn_on
target:
  entity_id: light.kitchen
data:
  brightness_pct: 80
  color_temp_kelvin: 3000

# Climate
action: climate.set_temperature
target:
  entity_id: climate.living_room
data:
  temperature: 21
  hvac_mode: heat

# Media player
action: media_player.play_media
target:
  entity_id: media_player.living_room
data:
  media_content_id: "http://example.com/song.mp3"
  media_content_type: "music"

# Script
action: script.turn_on
target:
  entity_id: script.flash_light
data:
  variables:
    target_light: light.kitchen

# Input helper
action: input_number.set_value
target:
  entity_id: input_number.target_temp
data:
  value: 42
```

---

## 7. Template Syntax (Jinja2)

HA uses Jinja2 templates throughout YAML configs. Templates are enclosed in
`{{ }}` for expressions and `{% %}` for statements.

### Core State Functions

```jinja2
{# Get entity state as string (ALWAYS returns string) #}
{{ states('sensor.temperature') }}

{# Get entity attribute #}
{{ state_attr('light.kitchen', 'brightness') }}
{{ state_attr('climate.living_room', 'current_temperature') }}
{{ state_attr('climate.living_room', 'hvac_modes') }}

{# Boolean state checks #}
{{ is_state('light.kitchen', 'on') }}
{{ is_state('person.simon', ['home', 'work']) }}  {# Match any in list #}

{# Boolean attribute check #}
{{ is_state_attr('climate.ac', 'hvac_mode', 'cool') }}

{# Check if entity has a valid value (not unknown/unavailable) #}
{{ has_value('sensor.temperature') }}
```

### Type Conversion (CRITICAL - states are always strings)

```jinja2
{# Convert to float (with default for unavailable/unknown) #}
{{ states('sensor.temperature') | float(0) }}

{# Convert to int #}
{{ states('sensor.humidity') | int(0) }}

{# Safe numeric comparison #}
{% if states('sensor.temperature') | float(0) > 25 %}
  Too hot!
{% endif %}

{# Check if value is actually numeric before using #}
{% if is_number(states('sensor.temperature')) %}
  {{ states('sensor.temperature') | float + 5 }}
{% endif %}
```

### Time Functions

```jinja2
{# Current time #}
{{ now() }}
{{ now().hour }}
{{ now().minute }}
{{ now().day }}
{{ now().month }}
{{ now().year }}
{{ now().weekday() }}           {# 0=Monday, 6=Sunday #}
{{ now().isoformat() }}
{{ now().timestamp() }}         {# Unix timestamp #}

{# UTC time #}
{{ utcnow() }}

{# Time comparisons #}
{{ now() > today_at("22:00") }}
{{ now() < today_at("06:00") }}

{# Time math #}
{{ now() - timedelta(hours=1) }}
{{ now() + timedelta(days=7, hours=3) }}

{# Convert to timestamp #}
{{ as_timestamp(now()) }}
{{ as_timestamp(states.binary_sensor.door.last_changed) }}

{# Parse datetime string #}
{{ as_datetime('2024-01-15T10:30:00') }}

{# Human-readable relative time ("2 hours ago") #}
{{ relative_time(states.binary_sensor.motion.last_changed) }}
{{ time_since(states.sensor.temp.last_changed, precision=2) }}

{# Time until future event #}
{{ time_until(state_attr('calendar.events', 'start_time')) }}
```

### Entity and Area Functions

```jinja2
{# Expand groups into entity list #}
{% for light in expand('group.all_lights') %}
  {{ light.entity_id }}: {{ light.state }}
{% endfor %}

{# Get all entities in an area #}
{% for entity in area_entities('kitchen') %}
  {{ entity }}
{% endfor %}

{# Get all entities on a device #}
{{ device_entities('device_id_here') }}

{# Device info #}
{{ device_attr('device_id', 'manufacturer') }}
{{ device_attr('device_id', 'model') }}
{{ device_attr('device_id', 'name') }}
{{ device_id('sensor.temp') }}        {# Get device ID from entity #}
{{ device_name('device_id') }}

{# Area info #}
{{ area_id('Kitchen') }}
{{ area_name('area_id_here') }}
{{ area_devices('kitchen') }}
```

### Common Patterns

```jinja2
{# Count entities in a specific state #}
{{ states.light | selectattr('state', 'eq', 'on') | list | count }}

{# List all lights that are on #}
{% for light in states.light if light.state == 'on' %}
  {{ light.name }}
{% endfor %}

{# Get battery levels below threshold #}
{% for sensor in states.sensor
   if 'battery' in sensor.entity_id
   and sensor.state | int(100) < 20 %}
  {{ sensor.name }}: {{ sensor.state }}%
{% endfor %}

{# Immediate if (ternary) #}
{{ iif(is_state('light.kitchen', 'on'), 'Yes', 'No') }}
{{ is_state('light.kitchen', 'on') | iif('Lit', 'Dark') }}

{# Default value for undefined/none #}
{{ states('sensor.temp') | default('N/A') }}
{{ state_attr('light.kitchen', 'brightness') | default(0) }}

{# Rounding #}
{{ states('sensor.temperature') | float | round(1) }}

{# Clamping values #}
{{ states('sensor.raw') | float | max(0) | min(100) }}

{# String operations #}
{{ states('sensor.name') | lower }}
{{ states('sensor.name') | upper }}
{{ states('sensor.name') | replace('_', ' ') | title }}
{{ states('sensor.name') | truncate(20) }}
{{ states('sensor.name') | slugify }}

{# Regex #}
{{ 'text123' | regex_search('[0-9]+') }}
{{ 'hello world' | regex_replace(find='world', replace='HA') }}

{# JSON handling #}
{{ value_json.temperature }}              {# In value_template #}
{{ states('sensor.data') | from_json }}
{{ {'key': 'value'} | to_json }}

{# List/math operations #}
{{ [10, 20, 30] | average }}
{{ [10, 20, 30] | median }}
{{ [10, 20, 30] | min }}
{{ [10, 20, 30] | max }}
{{ [10, 20, 30] | sum }}
{{ range(1, 11) | list }}

{# Set operations #}
{{ [1,2,3] | intersect([2,3,4]) }}       {# [2, 3] #}
{{ [1,2,3] | union([3,4,5]) }}           {# [1, 2, 3, 4, 5] #}

{# Hash / encode #}
{{ 'text' | base64_encode }}
{{ 'dGV4dA==' | base64_decode }}
{{ 'text' | md5 }}
{{ 'text' | sha256 }}
{{ 'text' | urlencode }}
```

### Template Rules
- Single-line templates MUST be quoted: `"{{ states('sensor.temp') }}"`
- Multi-line templates use `>` or `|` block scalars (no quotes needed)
- States are ALWAYS strings. Always convert with `| float(0)` or `| int(0)` before math.
- Use `has_value()` or check for `'unavailable'`/`'unknown'` to avoid errors.
- Avoid `states.domain.entity.state` syntax; use `states('domain.entity')` function.

---

## 8. Scenes

```yaml
# scenes.yaml (list format)
- id: "movie_night"
  name: "Movie Night"
  icon: mdi:movie
  entities:
    light.living_room:
      state: "on"
      brightness: 50
      color_temp_kelvin: 2700
    light.ceiling:
      state: "off"
    media_player.tv:
      state: "on"
      source: "HDMI 1"
    cover.blinds:
      state: "closed"
```

Rules:
- Boolean states (`on`/`off`) must be **quoted** as strings: `state: "on"` (otherwise YAML parses `on` as `true`).
- Scenes only support `scene.turn_on` (there is no `scene.turn_off`).
- Attributes available depend on the entity domain.

---

## 9. Input Helpers (YAML Configuration)

```yaml
# In configuration.yaml or a package file
input_boolean:
  guest_mode:
    name: "Guest Mode"
    initial: false
    icon: mdi:account-group

input_number:
  target_temperature:
    name: "Target Temperature"
    min: 16
    max: 30
    step: 0.5
    unit_of_measurement: "°C"
    mode: slider                   # slider | box
    icon: mdi:thermometer

input_select:
  house_mode:
    name: "House Mode"
    options:
      - "Home"
      - "Away"
      - "Night"
      - "Vacation"
    initial: "Home"
    icon: mdi:home

input_text:
  welcome_message:
    name: "Welcome Message"
    initial: "Welcome home!"
    min: 0
    max: 255
    mode: text                     # text | password
    pattern: "[a-zA-Z0-9 ]*"      # Optional regex validation
    icon: mdi:message

input_datetime:
  morning_alarm:
    name: "Morning Alarm"
    has_date: false
    has_time: true
    initial: "07:00:00"
    icon: mdi:alarm

input_button:
  reset_counter:
    name: "Reset Counter"
    icon: mdi:restart

counter:
  daily_visitors:
    name: "Daily Visitors"
    initial: 0
    step: 1
    minimum: 0
    maximum: 1000
    restore: true
    icon: mdi:counter

timer:
  kitchen_timer:
    name: "Kitchen Timer"
    duration: "00:10:00"
    restore: true
    icon: mdi:timer
```

---

## 10. Template Sensors and Binary Sensors

### Modern Format (use this)

```yaml
# In configuration.yaml or package
template:
  # State-based (updates whenever referenced entities change)
  - sensor:
      - name: "Average Indoor Temperature"
        unique_id: avg_indoor_temp
        unit_of_measurement: "°C"
        device_class: temperature
        state_class: measurement
        state: >
          {% set temps = [
            states('sensor.kitchen_temp') | float(0),
            states('sensor.bedroom_temp') | float(0),
            states('sensor.living_temp') | float(0)
          ] | reject('equalto', 0) | list %}
          {{ (temps | average) | round(1) if temps else 'unavailable' }}
        availability: >
          {{ has_value('sensor.kitchen_temp')
             or has_value('sensor.bedroom_temp')
             or has_value('sensor.living_temp') }}
        attributes:
          sensor_count: >
            {{ [has_value('sensor.kitchen_temp'),
                has_value('sensor.bedroom_temp'),
                has_value('sensor.living_temp')] | select | list | count }}

  - binary_sensor:
      - name: "Someone Home"
        unique_id: someone_home
        device_class: presence
        state: >
          {{ states.person | selectattr('state', 'eq', 'home') | list | count > 0 }}
        delay_off:
          minutes: 10

  # Trigger-based (updates only on specific triggers, more efficient)
  - triggers:
      - trigger: state
        entity_id: sensor.power_meter
    sensor:
      - name: "Power Cost Today"
        unique_id: power_cost_today
        unit_of_measurement: "$"
        state: "{{ (trigger.to_state.state | float(0) * 0.12) | round(2) }}"
```

### Common device_class Values

**Sensors**: `temperature`, `humidity`, `pressure`, `illuminance`, `battery`, `power`, `energy`, `voltage`, `current`, `frequency`, `gas`, `co2`, `pm25`, `pm10`, `signal_strength`, `timestamp`, `duration`, `speed`, `wind_speed`, `moisture`, `weight`

**Binary sensors**: `battery`, `cold`, `connectivity`, `door`, `garage_door`, `gas`, `heat`, `light`, `lock`, `moisture`, `motion`, `moving`, `occupancy`, `opening`, `plug`, `power`, `presence`, `problem`, `running`, `safety`, `smoke`, `sound`, `tamper`, `update`, `vibration`, `window`

### Common state_class Values
- `measurement` -- current reading (temperature, power)
- `total` -- monotonically increasing total (energy, gas)
- `total_increasing` -- total that only increases (utility meter)

---

## 11. Dashboard / Lovelace

### Configuration

```yaml
# configuration.yaml - enable YAML-managed dashboards
lovelace:
  mode: yaml                      # storage (UI) | yaml
  resources:                      # Custom cards JS/CSS
    - url: /local/my-card.js
      type: module
  dashboards:
    dashboard-rooms:
      mode: yaml
      filename: dashboards/rooms.yaml
      title: "Rooms"
      icon: mdi:floor-plan
      show_in_sidebar: true
      require_admin: false
```

### Dashboard File Structure

```yaml
# dashboards/rooms.yaml
title: "My Home"
views:
  - title: "Living Room"
    path: living-room              # URL path segment
    icon: mdi:sofa
    theme: default
    type: masonry                  # masonry (default) | sidebar | panel | sections
    badges:
      - entity: person.simon
      - entity: sensor.temperature
    cards:
      - type: entities
        title: "Controls"
        entities:
          - entity: light.living_room
          - entity: switch.tv_power
          - entity: climate.living_room

  - title: "Security"
    path: security
    icon: mdi:shield-home
    cards:
      - type: alarm-panel
        entity: alarm_control_panel.home
```

### Common Card Types

Use this as a high-signal starter set. Additional card types (`glance`, `history-graph`, `map`, `picture-elements`, `area`, stacks) follow the same structure.

**Entities card**:
```yaml
- type: entities
  title: "Kitchen"
  entities:
    - light.kitchen
    - sensor.kitchen_temp
    - switch.coffee_maker
```

**Tile card**:
```yaml
- type: tile
  entity: light.bedroom
  features:
    - type: light-brightness
```

**Button card**:
```yaml
- type: button
  entity: script.goodnight
  tap_action:
    action: call-service
    service: script.goodnight
```

**Thermostat card**:
```yaml
- type: thermostat
  entity: climate.living_room
```

**Conditional card**:
```yaml
- type: conditional
  conditions:
    - condition: state
      entity: input_boolean.guest_mode
      state: "on"
  card:
    type: entities
    entities:
      - light.guest_room
      - climate.guest_room
```

**Grid card**:
```yaml
- type: grid
  columns: 3
  cards:
    - type: tile
      entity: light.kitchen
    - type: tile
      entity: light.bedroom
```

**Custom card**:
```yaml
- type: "custom:mushroom-light-card"
  entity: light.kitchen
```

---

## 12. MQTT Integration Patterns

### Manual Entity Configuration

Manual MQTT entities are useful when auto-discovery is unavailable or when you need explicit topics/templates.

Core field patterns:
- Read-only entities: `state_topic` (+ `value_template` if JSON payload)
- Controllable entities: `state_topic` + `command_topic`
- Use `unique_id` for stable UI management
- Use `device_class` / `state_class` where applicable

```yaml
# configuration.yaml
mqtt:
  # Read-only sensor
  - sensor:
      name: "Living Room Temperature"
      unique_id: mqtt_living_temp
      state_topic: "home/living_room/temperature"
      unit_of_measurement: "°C"
      device_class: temperature
      state_class: measurement
      value_template: "{{ value_json.temperature }}"

  # Controllable switch
  - switch:
      name: "Garden Pump"
      unique_id: mqtt_garden_pump
      state_topic: "home/garden/pump/state"
      command_topic: "home/garden/pump/set"
      payload_on: "ON"
      payload_off: "OFF"
      state_on: "ON"
      state_off: "OFF"
      optimistic: false

  # Controllable light (JSON schema)
  - light:
      name: "RGB Strip"
      unique_id: mqtt_rgb_strip
      schema: json
      state_topic: "home/rgb/state"
      command_topic: "home/rgb/set"
      brightness: true
      color_mode: true
      supported_color_modes:
        - rgb
        - color_temp

  # Controllable climate
  - climate:
      name: "Bedroom AC"
      unique_id: mqtt_bedroom_ac
      mode_state_topic: "home/bedroom/ac/mode/state"
      mode_command_topic: "home/bedroom/ac/mode/set"
      temperature_state_topic: "home/bedroom/ac/temp/state"
      temperature_command_topic: "home/bedroom/ac/temp/set"
      current_temperature_topic: "home/bedroom/ac/current_temp"
      modes:
        - "off"
        - "cool"
        - "heat"
```

### MQTT Discovery

Devices that support MQTT discovery auto-create entities without YAML config.

Discovery topic format:
```
<discovery_prefix>/<component>/<node_id>/<object_id>/config
```

Default prefix: `homeassistant`. Example:
```
homeassistant/sensor/garden/temperature/config
```

Payload is JSON matching the YAML config fields. The `~` character in topic values
expands to the `base_topic` defined in the payload.

### MQTT Actions in Automations

```yaml
# Publish MQTT message
- action: mqtt.publish
  data:
    topic: "home/command"
    payload: '{"state": "ON"}'
    qos: 1
    retain: false

# Publish with template
- action: mqtt.publish
  data:
    topic: "home/{{ device }}/set"
    payload_template: >
      {{ states('input_number.target') | int }}
```

---

## 13. Zigbee2MQTT Entity Patterns

With MQTT discovery enabled, Zigbee2MQTT entities are auto-created in HA.

### Naming pattern

Format is usually:
`domain.device_friendly_name_property`

Common outputs:
- Motion: `binary_sensor.<name>_occupancy`, plus battery/illuminance sensors
- Contact: `binary_sensor.<name>_contact`
- Buttons/remotes: `sensor.<name>_action`
- Plugs: `switch.<name>` plus power/energy sensors
- Lights: `light.<name>`

Exact suffixes depend on the device converter and exposed features.

### Triggering button events

Prefer the created action sensor:
```yaml
triggers:
  - trigger: state
    entity_id: sensor.ikea_button_action
    to: "toggle"
```

Direct MQTT trigger is also valid when needed:
```yaml
triggers:
  - trigger: mqtt
    topic: "zigbee2mqtt/Button Name/action"
    payload: "single"
```

---

## 14. ESPHome Entity Patterns

ESPHome devices auto-register entities via native API or MQTT.

### Entity ID Convention

Typical format:
`domain.device_name_component_name`

The node `name`/`friendly_name` is usually prefixed to each component.

Common mappings:
- `sensor`, `binary_sensor`, `switch`, `light`, `fan`, `climate`, `cover`
- `number`, `select`, `button`
- `text_sensor` usually appears under HA `sensor`

### Accessing ESPHome Services

Most interactions happen through normal entity services (Section 6), because ESPHome components surface as regular HA entities.

Some custom ESPHome actions may also expose service names in this form:
```yaml
action: esphome.node_name_service_name
data:
  parameter: value
```

---

## 15. Blueprints

### Blueprint File Structure

```yaml
# blueprints/automation/my_blueprints/motion_light.yaml
blueprint:
  name: "Motion-activated Light"
  description: "Turn on a light when motion is detected"
  domain: automation                  # automation | script
  author: "Your Name"
  source_url: "https://github.com/..."  # Optional: enables import by URL
  homeassistant:
    min_version: "2024.6.0"
  input:
    motion_entity:
      name: "Motion Sensor"
      description: "Binary sensor for motion detection"
      selector:
        entity:
          domain: binary_sensor
          device_class: motion
    light_target:
      name: "Light"
      selector:
        target:
          entity:
            domain: light
    no_motion_wait:
      name: "Wait Time"
      description: "Time to leave the light on after last motion"
      default: 120
      selector:
        number:
          min: 0
          max: 3600
          unit_of_measurement: seconds

triggers:
  - trigger: state
    entity_id: !input motion_entity
    from: "off"
    to: "on"

actions:
  - action: light.turn_on
    target: !input light_target
  - wait_for_trigger:
      - trigger: state
        entity_id: !input motion_entity
        from: "on"
        to: "off"
  - delay: !input no_motion_wait
  - action: light.turn_off
    target: !input light_target
```

### Common Selectors

Use the smallest selector that matches intent. Most blueprint inputs only need a subset of these.

```yaml
selector:
  # Pick one or more entities
  entity:
    domain: light
    multiple: true

  # Target selector (entity/device/area)
  target:
    entity:
      domain: light

  # Numeric input
  number:
    min: 0
    max: 100
    step: 1
    unit_of_measurement: "%"

  # Toggle
  boolean:

  # Text input
  text:
    multiline: false
    type: text

  # Enumerated choices
  select:
    options:
      - "Home"
      - "Away"
      - "Night"

  # Common time/date selectors
  time:
  date:
  datetime:
  duration:
```

Additional selectors exist (`device`, `area`, `object`, `action`, `trigger`, `condition`, `template`, `color_*`, `icon`, `theme`, `location`, `media`) and are best chosen per blueprint use case.

---

## 16. Add-on vs. Integration

| Aspect | Integration | Add-on |
|--------|------------|--------|
| **What it is** | Python code running inside HA Core | Separate Docker container |
| **Location** | `custom_components/` or built-in | Managed by Supervisor |
| **Communication** | Direct access to HA internals | Via REST API, MQTT, or websocket |
| **Creates entities** | Directly | Only via an integration bridge |
| **Configuration** | `configuration.yaml` or UI config flow | Own config panel + `options.json` |
| **Lifecycle** | Starts/stops with HA Core | Independent start/stop |
| **Examples** | MQTT integration, Zigbee (ZHA) | Zigbee2MQTT, Node-RED, ESPHome dashboard, Codex Code |
| **Availability** | All installation methods | Only HA OS and Supervised |

Key patterns:
- Many tools have BOTH: e.g., ESPHome add-on (dashboard/compiler) + ESPHome integration (connects devices to HA).
- Zigbee2MQTT add-on (runs Z2M) + MQTT integration (bridges entities to HA).
- Add-ons communicate with HA via the Supervisor API (`http://supervisor/core/api`).

---

## 17. Shell Commands and REST Commands

```yaml
# Shell commands (run system commands)
shell_command:
  backup_config: "tar -czf /share/backup.tar.gz /homeassistant/"
  restart_service: "systemctl restart my_service"
  custom_script: "bash /homeassistant/scripts/my_script.sh {{ value }}"

# REST commands (make HTTP requests)
rest_command:
  send_webhook:
    url: "https://example.com/api/webhook"
    method: POST
    headers:
      Authorization: "Bearer !secret api_token"
      Content-Type: "application/json"
    payload: '{"message": "{{ message }}"}'
    timeout: 10
    verify_ssl: true

  turn_on_device:
    url: "http://192.168.1.100/api/{{ command }}"
    method: GET
```

Usage in automations:
```yaml
actions:
  - action: shell_command.backup_config
  - action: rest_command.send_webhook
    data:
      message: "Motion detected at {{ now().strftime('%H:%M') }}"
```

---

## 18. Common Debugging Patterns

### Check configuration validity
```bash
ha core check
```

### Read logs
```bash
# Recent logs
tail -200 /homeassistant/home-assistant.log

# Filter errors
grep -iE "(error|exception|warning)" /homeassistant/home-assistant.log | tail -50

# Via ha CLI
ha core logs 2>&1 | tail -100
```

### Enable verbose crash debugging
```yaml
# configuration.yaml -- helps identify integrations causing crashes/restarts
homeassistant:
  debug: true
```

### Common YAML mistakes
- **Indentation**: Always use 2 spaces, never tabs.
- **Unquoted `on`/`off`**: YAML interprets bare `on`/`off`/`yes`/`no` as booleans. Quote state strings.
- **Template formatting**: See Section 7 template rules (single-line quoted, multi-line block scalars).
- **Service call structure**: See Section 6 (`action` + `target` + `data`) instead of ad-hoc payload layout.
- **Automation key names**: Use modern plural keys (`triggers`, `conditions`, `actions`) for consistency.
- **Duplicate keys**: YAML silently drops duplicate keys. Use packages or includes to avoid.
- **Float comparison**: `states()` returns strings. Cast first (`| float(0)` / `| int(0)`).
- **Unavailable entities**: Check `has_value()` before using state values in templates.
- **Include format mismatch**: Files included via `!include` must NOT contain the parent key. E.g., a file included as `automation: !include automations.yaml` should contain a list starting with `- id:`, NOT `automation:` at the top.
- **UTF-8 encoding**: All YAML files must be UTF-8 encoded. Non-UTF-8 characters cause codec errors.
- **`.yml` vs `.yaml`**: Directory include directives only pick up `.yaml` files, not `.yml`.

### Reload without restart
Many config sections can be reloaded without a full restart via Developer Tools or:
```yaml
# Reload automations
action: automation.reload

# Reload scripts
action: script.reload

# Reload scenes
action: scene.reload

# Reload groups
action: group.reload

# Reload input_* helpers
action: input_boolean.reload
action: input_number.reload
action: input_select.reload
action: input_text.reload
action: input_datetime.reload

# Reload template entities
action: template.reload

# Reload MQTT manually configured entities
action: mqtt.reload

# Reload rest_command / shell_command
action: rest_command.reload
action: shell_command.reload
```

Changes to `configuration.yaml` top-level keys, custom_components, or core settings
require a full restart: `ha core restart` or via the UI.
