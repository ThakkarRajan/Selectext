# ScreenOCR

macOS menu bar app: drag a screen region → on-device OCR (Apple Vision) → text on the clipboard. No cloud, no account.

## Features

- **Region capture** — select any rectangle on any display
- **On-device OCR** — [`VNRecognizeTextRequest`](https://developer.apple.com/documentation/vision/vnrecognizetextrequest); text stays on your Mac
- **Global shortcut** — default **⌘⇧T** (customizable in Settings)
- **Clipboard-first** — recognized text is copied automatically; paste with **⌘V**
- **History** — recent extractions stored locally under Application Support
- **Menu bar UI** — capture, history, settings, and getting-started guide without a Dock icon

## Requirements

| | |
| --- | --- |
| **macOS** | 14.0 (Sonoma) or later |
| **Hardware** | Apple Silicon or Intel |
| **Build** | Xcode 15+ (to compile from source) |

There is no signed release binary in this repo yet — build and run locally (see below).

## Quick start

### Option A — Xcode

1. Clone this repository.
2. Open `ScreenOCR.xcodeproj` in Xcode.
3. Select the **ScreenOCR** scheme and **My Mac**.
4. Run (**⌘R**).

### Option B — Terminal

```bash
git clone https://github.com/ThakkarRajan/ScreenOCR.git
cd ScreenOCR
xcodebuild -scheme ScreenOCR -configuration Debug -destination 'platform=macOS' -derivedDataPath build build
open build/Build/Products/Debug/ScreenOCR.app
```

On first launch, ScreenOCR opens **Getting Started** and may ask for permissions (see below).

## How to use

1. Press **⌘⇧T** (or choose **Capture Text** from the menu bar icon).
2. Drag a rectangle over the text you want.
3. Wait a moment — text is copied to the clipboard.
4. Paste anywhere with **⌘V**.
5. Open the **menu bar icon** for history, settings, last extraction, or **Getting Started…**.

You can change the shortcut in **Settings**.

## Permissions

| Permission | Why |
| --- | --- |
| **Screen Recording** | Capture pixels in the selected region ([ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit)) |
| **Accessibility** | Global hotkey via [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) (only if macOS prompts) |
| **Notifications** | Optional success feedback (first run may prompt) |

Grant **Screen Recording** in **System Settings → Privacy & Security → Screen Recording** and enable ScreenOCR.

## Privacy

- OCR runs **entirely on device**.
- No network calls for recognition.
- History is a **local JSON file** in `~/Library/Application Support/ScreenOCR/`.

## Architecture

| Component | Role |
| --- | --- |
| `AppModel` | Coordinates selection → capture → OCR → clipboard → history |
| `RegionSelectionManager` | Per-display overlay; drag rect; **Esc** cancels |
| `ScreenCaptureManager` | ScreenCaptureKit region capture (Retina-aware) |
| `TextRecognitionService` | Vision OCR with reading-order line grouping |
| `ShortcutManager` | Global shortcut |
| `OCRHistoryManager` | Local history on disk |

SwiftUI + AppKit (`LSUIElement` — menu bar app). Source lives under `ScreenOCR/`.

## Troubleshooting

### Console: `linkd.autoShortcut`

Harmless macOS noise around App Intents / Shortcuts registration. ScreenOCR does not integrate with Shortcuts.

### App quits right after launch (macOS 26+)

Check **Control Center → Menu Bar** and keep the ScreenOCR item **visible**. A hidden menu bar extra plus a Dock-less app can cause SwiftUI to exit; the app may show a Dock icon as a fallback.

### Capture does nothing

Confirm **Screen Recording** is enabled for ScreenOCR in System Settings, then try again.

## Development

```bash
xcodebuild -scheme ScreenOCR -configuration Debug -destination 'platform=macOS' -derivedDataPath build build
```

Agent and contributor notes: `AGENTS.md`, `cursor.md`. Issues and specs for maintainers may live under `.scratch/` and `docs/agents/`.

## License

MIT — see [LICENSE](LICENSE).
