# Codex Pixel Terminal

macOS app that shows Pixel Agents on the left and an embedded interactive Codex CLI terminal on the right.

## Build

From the repository root:

```bash
./script/build_and_run.sh --bundle
```

The app bundle is generated at:

```text
dist/Codex Pixel Terminal.app
```

## Install

```bash
ditto --norsrc --noextattr "dist/Codex Pixel Terminal.app" "/Applications/Codex Pixel Terminal.app"
```

## Runtime Notes

- Pixel Agents runtime is bundled under `CodexPixelTerminal/Resources/PixelAgents`.
- The terminal pane uses SwiftTerm so keyboard input, paste, alternate screens, and terminal resizing are handled by a real terminal emulator.
- The app uses `/usr/local/bin/node` for Pixel Agents and `/opt/homebrew/bin/codex` for Codex CLI.
- Codex starts in `/Users/yasusu/Desktop/Programing Files/CodexCLI-MOD`.
