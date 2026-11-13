# ScreenOCR — Cursor project rules

Lightweight **macOS menu bar** app (`ScreenOCR/`): select screen region → on-device **Vision OCR** → clipboard. No network for OCR.

## Stack

- Swift 5, SwiftUI + AppKit where needed (overlays, `NSWindow`)
- macOS 14+ (`LSUIElement` — menu bar first)
- SPM: `KeyboardShortcuts` only
- Xcode project: `ScreenOCR.xcodeproj`

## Repository layout

| Path | Purpose |
|------|---------|
| `ScreenOCR/App/` | `ScreenOCRApp`, `AppModel`, `AppDelegate`, launch state |
| `ScreenOCR/Capture/` | Region overlay, ScreenCaptureKit capture, capture pipeline |
| `ScreenOCR/OCR/` | `VNRecognizeTextRequest` |
| `ScreenOCR/UI/` | Menu bar panel, settings, history, preview, tutorial windows |
| `ScreenOCR/Shortcuts/` | Global ⌘⇧T, Accessibility helpers |
| `ScreenOCR/History/` | Local JSON history |
| `ScreenOCR/Notifications/` | UserNotifications |
| `docs/agents/` | Issue tracker, triage labels, domain doc rules |
| `docs/adr/` | Architecture decision records (create when needed) |
| `.scratch/` | Local markdown specs and tickets |
| `graphify-out/` | Code knowledge graph (generated; gitignored) |

## Architecture

- **MVVM**: `AppModel` (`@MainActor`, `ObservableObject`) coordinates capture, OCR, clipboard, history, shortcuts, window requests.
- **Flow**: shortcut / menu → `startRegionSelection()` → `RegionSelectionManager` (per-display overlay) → `CapturePipeline` → `TextRecognitionService` → clipboard + optional preview + history.
- **Menu bar UI**: `NSStatusItem` in `AppDelegate` — click toggles `MenuBarPopoverController` (recent clips + actions). Full window via launch/reopen or “Open Full Window…” in the popover.
- **Auxiliary windows**: prefer `FeatureWindowController` / `MainWindowController` (`NSHostingController` + `NSWindow`) — do not rely on `openWindow` from menu bar content alone.
- **State**: use `@AppStorage` for user prefs; history on disk under Application Support.

## Coding rules

1. **Minimal diff** — match existing naming, folder layout, and patterns; no drive-by refactors.
2. **Main actor** — UI and `AppModel` stay on `@MainActor`; use `Task { @MainActor in }` for callbacks from AppKit.
3. **Permissions** — screen recording: one system prompt per session + optional in-app alert if denied; do not spam Accessibility prompts on every shortcut (Settings/tutorial only).
4. **Capture UX** — show selection overlay even when permission pending; verify capture access after region is chosen.
5. **Errors** — user-facing copy via `NotificationManager` + `statusMessage`; log unexpected errors with `NSLog`.
6. **No network** — do not add cloud OCR or telemetry unless explicitly requested.
7. **Xcode** — add new Swift files to `ScreenOCR.xcodeproj/project.pbxproj` when creating files.
8. **Commits** — only when the user asks; never force-push `main`.

## UI rules

- Menu bar panel: primary **Capture Text**; links to Getting Started, Last Extraction, History, Settings.
- Main window (`MainWindowController`): sidebar with Clipboard (history), Getting Started (`WelcomeView`), Settings. Opens on every launch and on reopen; first launch starts on Getting Started.
- Settings: `SettingsLink` + `KeyboardShortcuts.Recorder`; permission rows link to System Settings only when not granted.
- Keep permission UI short — no duplicate system + custom dialogs for the same permission in one flow.

## Build & run

```bash
cd /Users/rajan/Desktop/Github/screentext
xcodebuild -scheme ScreenOCR -configuration Debug -destination 'platform=macOS' -derivedDataPath build build
open build/Build/Products/Debug/ScreenOCR.app
```

Do not commit `build/`, `DerivedData/`, `graphify-out/`, or `xcuserdata/`.

## Agent skills (Matt Pocock + tools)

Configured via `setup-matt-pocock-skills`. Details in `AGENTS.md` and:

- **Issues**: `.scratch/<feature>/spec.md` and `issues/NN-slug.md` — see `docs/agents/issue-tracker.md`
- **Triage labels**: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix` — see `docs/agents/triage-labels.md`
- **Domain**: `GLOSSARY.md` + `docs/adr/` when they exist — see `docs/agents/domain.md`

Useful skills (global `~/.agents/skills/`): `implement`, `code-review`, `diagnosing-bugs`, `graphify`, `triage`, `to-spec`, `to-tickets`.

## Graphify

If `graphify-out/graph.json` exists, prefer `graphify query` / `graphify explain` / `graphify path` for architecture questions instead of re-grepping the whole tree.

Rebuild code graph (no API key):

```bash
graphify . --code-only && graphify cluster-only .
```

## Exploration hints

- Hub types: `AppModel`, `RegionSelectionManager`, `CapturePipeline`, `MainWindowController`, `FeatureWindowController`.
- Global shortcut default: **⌘⇧T** (not ⌘⇧E).

## When unsure

Read `README.md` for permissions and macOS 26+ menu bar visibility notes before changing launch or activation policy.
