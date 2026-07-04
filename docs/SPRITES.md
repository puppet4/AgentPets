# Sprite Packs

AgentPets reads packs from:

`~/Library/Application Support/AgentPets/packs/`

The app ships two generated packs by default:

- `claude-pixel`
- `codex-pixel`

You can add your own pack folder next to them.

## Folder layout

```text
packs/
├── claude-pixel/
├── codex-pixel/
└── my-pack/
    ├── pack.json
    ├── idle/
    │   ├── 00.png
    │   └── 01.png
    ├── listening/
    ├── thinking/
    ├── working/
    ├── success/
    ├── error/
    └── offline/
```

## PNG rules

- transparent PNG
- numbered as `00.png`, `01.png`, `02.png`
- keep every frame in one state folder at the same canvas size
- 4-8 frames per looping state is usually enough

The built-in packs render at `192x192` pixels with a logical `96x96` frame size. Custom packs do not have to match that exactly, but keeping a square canvas around that range gives the cleanest result.

## Supported state folders

- `idle`
- `listening`
- `thinking`
- `working`
- `success`
- `error`
- `offline`

Optional additional folders can be targeted through `pet.json` via `stateSpriteMap`, for example remapping `running` or `editing` to a custom folder.

## `pack.json`

```json
{
  "name": "My Pack",
  "author": "you",
  "version": 1,
  "frameSize": { "w": 96, "h": 96 },
  "states": ["idle", "listening", "thinking", "working", "success", "error", "offline"],
  "defaultFallback": "idle",
  "loop": {
    "idle": true,
    "listening": true,
    "thinking": true,
    "working": true,
    "success": false,
    "error": false,
    "offline": true
  }
}
```

If `pack.json` is missing, AgentPets can still load the PNGs, but keeping the manifest makes pack behavior predictable.

## Suggested workflow

1. Copy one of the shipped packs:

   ```bash
   cp -R ~/Library/Application\ Support/AgentPets/packs/claude-pixel \
         ~/Library/Application\ Support/AgentPets/packs/my-pack
   ```

2. Rename the pack in `my-pack/pack.json`.
3. Replace the PNG frames.
4. Open Preferences or the menu bar pack picker and switch to `my-pack`.

## Hot reload

Sprite folders are watched automatically. Replacing a PNG or editing `pack.json` updates the app without a restart.
