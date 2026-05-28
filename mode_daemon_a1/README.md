# ModeDaemon (A1) — menu bar modes + warnings + logs

This is **Track A1**: a separate menu bar app (not Stats) that provides:

- Manual mode selector: **Normal / LLM / Game**
- Lightweight background sampling
- Warnings for the 3 “enemies”:
  - **Memory pressure / swap growth**
  - **Thermal pressure**
  - **CPU saturation** (submission starvation risk)
- Local in-app log of warning events (and optional file logging)

## What this does NOT do (A1 by design)
- No system changes
- No “Apply” actions
- No privileged helper
- No GPU driver hacks

This app is meant to be the **measurement + control-plane foundation** for your later Track B work.

## Build (on your Mac)
1. Open Xcode → **File → New → Project…**
2. Choose **macOS App** (SwiftUI).
3. Name it `ModeDaemon`.
4. Delete the default generated source files (or keep them).
5. Drag the folder `Sources/ModeDaemon/` from this repo into your Xcode project.
6. Ensure target membership is enabled for all added files.
7. In your app target, set the app entry point to `ModeDaemonApp.swift` (or just keep it and remove the default `App` file).
8. Build & Run.

## Notes on metrics
- CPU and memory stats use `host_statistics64` + `sysctl` (no sudo).
- Thermal state uses `ProcessInfo.processInfo.thermalState`.
- “GPU utilization” is *not* reliably available via public APIs. The app surfaces this as “Unavailable” (by design) and relies on other signals (memory/thermal/CPU) to explain performance cliffs.

