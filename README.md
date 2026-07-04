# AgentPets

AgentPets is a macOS accessory app that shows Claude and Codex task state through a floating pixel pet, a menu bar item, and optional Touch Bar support.

## Build

```bash
swift build
```

## Test

```bash
swift test --disable-sandbox
```

## Install Locally

```bash
bash scripts/build-and-install.sh
```

## Package DMG

```bash
bash scripts/build-dmg.sh
```

The generated DMG is written to `dist/` and is intentionally not tracked in git.
