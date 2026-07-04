# Architecture

This repo is a small macOS accessory app that mirrors Claude/Codex task state through a floating pet panel, a menu bar item, and an optional Touch Bar surface.

## Runtime flow

```text
Claude / Codex hooks
        |
        v
  pet-notify.sh
        |
        v
~/Library/Application Support/AgentPets/inbox/
        |
        v
   InboxWatcher ----> HookEvent
        |                 |
        |                 v
        |            PetModel state
        |                 |
        v                 v
TerminalAgentMonitor --> AgentTaskRegistry --> floating panel / menu bar / task activation
```

## Main pieces

### Hook intake

- `Sources/AgentPets/Resources/pet-notify.sh`
- `Sources/AgentPets/IPC/InboxWatcher.swift`
- `Sources/AgentPets/IPC/HookEvent.swift`

Hook payloads are written to the inbox as files. That keeps delivery simple and survives app restarts.

### Task detection

- `Sources/AgentPets/IPC/TerminalAgentMonitor.swift`
- `Sources/AgentPets/IPC/WorkspaceMonitor.swift`
- `Sources/AgentPets/Tasks/AgentTaskRegistry.swift`
- `Sources/AgentPets/Tasks/TaskActivator.swift`

This layer discovers Claude/Codex processes, merges hook events with terminal snapshots, and provides clickable task activation entries.

### Config and persistence

- `Sources/AgentPets/Config/PetConfig.swift`
- `Sources/AgentPets/Config/PackManager.swift`
- `Sources/AgentPets/Persistence/StateStore.swift`

`pet.json` is the main user config. Packs are hot-reloaded from disk.

### Sprite pipeline

- `Sources/AgentPets/Sprite/PixelRobotRenderer.swift`
- `Sources/AgentPets/Sprite/BundledPetPackRenderer.swift`
- `Sources/AgentPets/Sprite/SpriteLoader.swift`
- `Sources/AgentPets/Sprite/PlaceholderRenderer.swift`
- `Sources/AgentPets/Sprite/HotReloadWatcher.swift`

The shipped product packs are generated locally for Claude and Codex. Custom packs are loaded from the user's packs directory. Placeholder art only exists as an internal fallback when no valid pack can be loaded.

### UI surfaces

- `Sources/AgentPets/App/PetPanel.swift`
- `Sources/AgentPets/App/StatusItemController.swift`
- `Sources/AgentPets/UI/PreferencesWindow.swift`
- `Sources/AgentPets/UI/StatusLegendWindow.swift`

The default interaction surface is the draggable floating panel plus the menu bar item. Touch Bar support still exists as an optional parallel surface.

### App lifecycle

- `Sources/AgentPets/App/AgentPetsApp.swift`
- `Sources/AgentPets/App/AppDelegate.swift`
- `Sources/AgentPets/App/AppSupport.swift`

The app runs as `.accessory`, so it stays out of the Dock while keeping the menu bar icon and floating panel alive.

## Useful debug paths

```bash
tail -f ~/Library/Application\ Support/AgentPets/logs/events.log
tail -f ~/Library/Application\ Support/AgentPets/logs/workspace.log
open ~/Library/Application\ Support/AgentPets/packs
open ~/Library/Application\ Support/AgentPets/pet.json
```
