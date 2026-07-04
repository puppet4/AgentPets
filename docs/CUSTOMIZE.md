# Customization Guide

AgentPets keeps its editable state in:

1. `~/Library/Application Support/AgentPets/pet.json`
2. `~/Library/Application Support/AgentPets/packs/`

Both are hot-reloaded. Save the file, and the floating pet/menu state updates without a restart.

## `pet.json`

```json
{
  "version": 1,
  "activePack": "claude-pixel",
  "followActiveAgent": true,
  "packsDir": "~/Library/Application Support/AgentPets/packs",
  "fps": 12,
  "showLabel": true,
  "labelMaxChars": 24,
  "autoForeground": true,
  "minStateDurationMs": 300,
  "successHoldSeconds": 3,
  "errorHoldSeconds": 4,
  "foregroundOnEvents": [
    "SessionStart",
    "UserPromptSubmit",
    "Notification",
    "PreCompact"
  ],
  "stateSpriteMap": {
    "idle": "idle",
    "listening": "listening",
    "thinking": "thinking",
    "working": "working",
    "searching": "working",
    "editing": "working",
    "running": "working",
    "reading": "working",
    "success": "success",
    "error": "error",
    "compacting": "compacting",
    "offline": "offline"
  },
  "stateLabelPolicy": {
    "showOn": ["working", "thinking", "error", "searching", "editing", "running", "reading"]
  },
  "language": "zh"
}
```

## Common changes

### Follow the active agent automatically

When `followActiveAgent` is `true`, AgentPets switches between `claude-pixel` and `codex-pixel` based on the currently detected Claude/Codex task.

If you manually choose a pack from Preferences or the menu bar, follow mode is turned off and that pack stays locked until you re-enable follow mode.

### Task list behavior

The app aggregates concurrent Claude/Codex tasks and shows them in:

- the floating panel under the pet
- the menu bar item under `任务状态`

Clicking a task is the only time AgentPets tries to bring a task window forward. Background state changes do not auto-activate tasks.

### Product pack surface

The built-in product surface only exposes:

- `claude-pixel`
- `codex-pixel`

If `activePack` still points to an old unsupported pack, the app normalizes it back to a supported Claude/Codex pack when config is applied.

### Animation speed

```json
"fps": 16
```

`12` is the default. Lower values feel calmer; higher values feel busier.

### Hide the text label

```json
"showLabel": false
```

### Disable auto-foreground

```json
"autoForeground": false
```

When disabled, AgentPets never steals focus automatically. You can still open the panel from the menu bar icon.

### Restrict which events can foreground

```json
"foregroundOnEvents": ["SessionStart", "PreCompact"]
```

### Remap sub-states to custom sprite folders

```json
"stateSpriteMap": {
  "running": "running-fancy",
  "editing": "editing-fancy",
  "reading": "reading-fancy"
}
```

Then provide matching folders in your pack, such as `running-fancy/00.png`.

### Change which states show labels

```json
"stateLabelPolicy": { "showOn": ["thinking", "error"] }
```

## Reset config

```bash
rm ~/Library/Application\ Support/AgentPets/pet.json
```

Restart the app and it regenerates the default config.

## Reset everything

```bash
rm -rf ~/Library/Application\ Support/AgentPets
```

Restart the app and it regenerates `pet.json` plus the bundled `claude-pixel` and `codex-pixel` packs.

## Useful paths

Open the shipped Claude pack:

```bash
open ~/Library/Application\ Support/AgentPets/packs/claude-pixel
```
