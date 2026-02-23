<div align="center">
  <img src="docs/logo/logo_cropped_1024.png" alt="Copilot Island logo" width="128">
  <div><b>Copilot Island</b></div>
</div>

<br>
<br>

> **⚠️ Note**: This project is under active development. Features and APIs may change. Install at your own responsibility.

A macOS Dynamic Island–style notch UI for **GitHub Copilot CLI** — see what Copilot is doing in real-time without switching windows.

Inspired by [claude-island](https://github.com/farouqaldori/claude-island)

## What it does

Copilot Island lives in your Mac's notch. While Copilot CLI is thinking, running tools, or waiting for your input, the notch expands to show live activity indicators. Click it to open a full session panel with chat history, tool calls, and recent sessions.

- **Live activity**: notch widens and animates when Copilot is processing or running a tool
- **New message dot**: a small white dot on the closed notch signals when the assistant has finished a reply
- **Session panel**: click to expand and see the active session, prompt, and tool output
- **Chat history**: browse past sessions with full message and tool-call logs
- **Zero dock presence**: runs as a macOS accessory app; no dock icon, no menu bar icon

## Requirements

- macOS with a physical notch (MacBook Pro 14"/16", MacBook Air M2+)
- [GitHub Copilot CLI](https://docs.github.com/en/copilot/github-copilot-in-the-cli) installed (`copilot` on your PATH)
- `socat` or `python3` (for socket communication in hook scripts)
- `jq` (for JSON processing in hook scripts)

## Installation

### 1. Build the app

```bash
just build
```

Or with `xcodebuild`:

```bash
xcodebuild -project copilot-island.xcodeproj \
  -scheme copilot-island \
  -configuration Release \
  -derivedDataPath build/DerivedData \
  -destination 'platform=macOS' \
  CONFIGURATION_BUILD_DIR=build/Release \
  clean build
```

Build output: `build/Release/Copilot Island.app`

### 2. Install the Copilot plugin

Launch the app, then click the notch and open the menu (≡) → **Install Plugin**. The app will run:

```bash
copilot plugin install --path <plugin-directory>
```

Alternatively, install manually:

```bash
copilot plugin install --path /path/to/copilot-island/plugin
```

### 3. Use Copilot CLI normally

Start any `copilot` session. The notch will appear automatically when activity begins.

## How it works

```mermaid
flowchart TD
    copilot["Copilot CLI"]
    hooks["Plugin hook scripts<br/>(on-session-start.sh, on-prompt.sh, ...)"]
    bridge["_bridge.sh<br/>(sends JSON over Unix socket via socat/python3)"]
    socket["SocketServer<br/>(listens on /tmp/copilot-island.sock)"]
    events["events.jsonl<br/>(~/.copilot/session-state/&lt;id&gt;/events.jsonl)"]
    watcher["EventsFileWatcher<br/>(tail-watches file for assistant turn events)"]
    store["SessionStore<br/>(processes events, publishes @Published state)"]
    notch["NotchView<br/>(SwiftUI, animates based on session phase)"]

    copilot --> hooks --> bridge --> socket --> store --> notch
    copilot --> events --> watcher --> store
```

The Copilot CLI plugin fires hook scripts for 8 lifecycle events. Each script calls `_bridge.sh`, which forwards the event as JSON to the Unix socket the app is listening on. `SessionStore` decodes the events and drives the UI state machine.

Some events — specifically `assistant.turn_start` and `assistant.turn_end` — have no plugin hook. Instead, `EventsFileWatcher` tail-watches the session's `events.jsonl` file directly using a kqueue dispatch source, calling back into `SessionStore` when the assistant starts or finishes a turn.

## Project structure

```mermaid
flowchart TD
    root["copilot-island/"]
    app["App/<br/>AppDelegate, WindowManager"]
    models["Models/<br/>SessionStore, CopilotEvent, SessionPhase, chat history"]
    services["Services/<br/>SocketServer, PluginInstaller, ConversationParser"]
    ui["UI/"]
    views["Views/<br/>NotchView, SessionListView, ChatView, NotchMenuView, ..."]
    components["Components/<br/>CopilotIcon, ProcessingSpinner, NotchShape"]
    viewmodels["ViewModels/<br/>NotchViewModel"]
    window["Window/<br/>NotchPanel, NotchViewController, NotchWindowController"]
    plugin["plugin/"]
    pluginJson["plugin.json (plugin metadata)"]
    hooksJson["hooks.json (maps 8 hook events to scripts)"]
    pluginScripts["scripts/<br/>_bridge.sh, on-*.sh"]
    docs["docs/README.md (developer reference)"]

    root --> app
    root --> models
    root --> services
    root --> ui
    ui --> views
    ui --> components
    ui --> viewmodels
    ui --> window
    root --> plugin
    plugin --> pluginJson
    plugin --> hooksJson
    plugin --> pluginScripts
    root --> docs
```

See [`docs/README.md`](docs/README.md) for a detailed developer reference with per-file descriptions.