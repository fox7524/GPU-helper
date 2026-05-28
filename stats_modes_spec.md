# Stats fork: Manual Performance Modes (Normal / LLM / Game)

This is the first MVP implementation of “modes” **inside the Stats app** (exelban/stats), matching your rules:

- Manual only (you select the mode)
- UI-only (no system tweaks, no process killing, no recommendations)
- Switching mode **immediately applies a saved layout** (modules + widgets)

## What “mode” does (in this MVP)
Each mode is a **layout snapshot** of *Stats internal UI state*:

- Which modules are enabled/disabled (CPU/GPU/RAM/etc.)
- Which widgets are active per module (mini/line_chart/bar_chart/etc.)
- Widget ordering positions (basic)

No macOS-level changes are performed.

## Files changed / added

### 1) `Kit/types.swift` (added enum + notification)
Adds:
- `PerformanceMode` enum (`normal`, `llm`, `game`)
- `PerformanceModes` list for the UI picker
- `Notification.Name.performanceModeChanged`
- `Notification.Name.performanceModeMenuBarVisibilityChanged` (menu bar indicator toggle)

### 2) `Stats/PerformanceModeManager.swift` (new)
Implements:
- Save snapshot for a mode: `saveSnapshot(for:modules:)`
- Apply snapshot for a mode: `applySnapshot(for:modules:)`
- Mode selection + notification: `setMode(_:)`

Snapshot contents:
- module enabled states
- widget list string per module
- widget positions per module/widget

### 3) `Stats/Views/AppSettings.swift` (Settings UI)
Adds a “Modes” section:
- “Performance mode” popup: Normal / LLM / Game
- “Save” + “Clear” current layout to this mode
- “Show mode in menu bar” toggle (optional)
- “Export” / “Import” layouts as JSON (optional)

### 4) `Stats/AppDelegate.swift` (wiring)
- On app start (after modules mount), it applies the current mode snapshot (if one exists)
- Listens for `.performanceModeChanged` and applies the snapshot immediately

## Intended workflow (manual)
1) Configure Stats visually the way you want for **LLM** (enable/disable modules, choose widgets, reorder).
2) In **Settings → Modes**, select **LLM** and click **Save**.
3) Repeat for **Game** and **Normal**.
4) From then on: selecting a mode instantly swaps the layout.
5) Optional: use **Export/Import** to back up and restore layouts.

## Notes / limitations (MVP)
- If a mode has no saved snapshot yet, switching to it does nothing.
- This MVP focuses on layout only; it does **not** change sampling/update intervals per mode (we can add that later if you want).
- It includes an optional **menu bar mode indicator** (disabled by default). Enable it in **Settings → Modes → “Show mode in menu bar”**.

## How to build on your Mac (Xcode)
1) Fork and clone:
   - `git clone https://github.com/<you>/stats.git`
2) Open:
   - `Stats.xcodeproj`
3) Add the new file to the Xcode project:
   - `Stats/PerformanceModeManager.swift`
   - Make sure it is included in the **Stats** target.
4) Build + Run.

Menu bar indicator behavior:
- Shows `N`, `LLM`, or `G` in the menu bar
- Clicking it opens a menu to switch modes (manual)

## Bonus stability fix included (recommended)
Stats has a long-standing issue where `/usr/bin/nettop` (Network module) can hang and become an orphan process, burning CPU over time. This matters directly for your “max performance” goal because the monitor itself must not waste resources.

In the fork, I added a small helper that:
- enforces a timeout
- calls `waitUntilExit()` to reap the process

This is based on the recent bug report describing orphaned `nettop` processes. See: https://github.com/exelban/stats/issues/3224
