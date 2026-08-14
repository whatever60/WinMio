<div align="center">
<img src="docs/winmio-icon-rounded.png" width="140" alt="WinMio">
<h1>WinMio</h1>
<p><b>Windows 11 Snipping Tool behavior for macOS.</b></p>
<p>
  <a href="#build-from-source"><b>Build&nbsp;for&nbsp;macOS</b></a> &nbsp;·&nbsp; <a href="LICENSE/GPL-3.0%20license">GPL-3.0</a> &nbsp;·&nbsp; <a href="https://github.com/iSoldLeo/Mio">Upstream Mio</a>
</p>
<p><sub>Requires macOS 15+ · Apple Silicon</sub></p>
<p><sub><b>Swift 6.3</b> &nbsp;·&nbsp; <b>SwiftUI · ScreenCaptureKit</b> &nbsp;·&nbsp; <b>Offline</b> &nbsp;·&nbsp; <b>~5&nbsp;MB</b> &nbsp;·&nbsp; <b>EN&nbsp;/&nbsp;中&nbsp;/&nbsp;日&nbsp;/&nbsp;FR&nbsp;/&nbsp;DE</b></sub></p>
</div>

## The familiar Windows capture flow, on a Mac

Press the hotkey and the last-used mode is active immediately. Every screen freezes at invocation, while a compact toolbar lets you switch among **Rectangle**, **Window**, **Full screen**, and **Freeform**. Rectangle and freeform captures finish when you release the pointer. By default, every successful capture is copied to the clipboard and saved to `~/Pictures/Screenshots`.

The default capture hotkey is bare `F19`, intended for a keyboard remapper to expose as a Windows-style physical shortcut such as `Shift+Win+S`. The app lives in the menu bar and makes no network connections.

This is an experimental GPL-3.0 fork of [Mio](https://github.com/iSoldLeo/Mio), whose ScreenCaptureKit freeze engine, editor, and menu-bar architecture provide the foundation.

<br>

<p align="center">
  <img src="docs/screenshot-framed-readme.png" width="70%" alt="WinMio output">
</p>
<p align="center">
  <img src="docs/screenshot-onboarding-frame-en.png" width="70%" alt="Framed screenshots">
</p>
<p align="center">
  <img src="docs/screenshot-onboarding-storage-en.png" width="70%" alt="Storage setup">
</p>

<br>

## Windows-style behavior

- Remembers the last capture mode and enters it directly
- Freezes the desktop before showing the selection UI
- Rectangle and freeform captures complete on pointer release
- Window mode captures the window under the pointer
- Rectangle and freeform selections can cross display boundaries
- Copies to the clipboard and auto-saves to `Pictures/Screenshots`
- `Esc`, right-click, or the toolbar's close button cancels

<br>

## Highlights

**Capture**
- Per-screen freeze in under 80&nbsp;ms — pick from still images, not a moving target
- Window-aware hover; click for a clean cut, drag for a region
- Multi-display picker for full screen capture

**Edit**
- Rectangle, ellipse, arrow, brush, mosaic, text
- Vector text annotations stay editable until you confirm
- Mosaic granularity is fixed so redactions can't leak
- Pick any color from anywhere on your screen

**Native**
- Menu bar only, accessory app
- Strict Concurrency, no third-party SDKs
- Zero network access, zero analytics

<br>

## Build from source

Clone the repository, open `WinMio.xcodeproj` in Xcode 26 or newer, select the `WinMio` scheme, and build. Grant **Screen Recording** when prompted.

```sh
git clone <your-fork-url>
cd WinMio
open WinMio.xcodeproj
```

> If macOS asks about an unidentified developer the first time, open **System Settings → Privacy & Security**, scroll to the prompt, and click **Open Anyway**.

<br>

## Privacy

WinMio runs entirely on your Mac. Screenshots go to the clipboard and, if you opt in, to a folder you choose. Nothing leaves the device. There's no account, no telemetry, no analytics — the app does not open a network connection at all.

<br>

## Info

Original Mio developers · [iSoldLeo](https://github.com/iSoldLeo) · [MeowLynxSea](https://github.com/MeowLynxSea) &nbsp;·&nbsp;
Upstream source · [github.com/iSoldLeo/Mio](https://github.com/iSoldLeo/Mio) &nbsp;·&nbsp;
License · [GPL-3.0](LICENSE/GPL-3.0%20license) &nbsp;·&nbsp;
Thanks · [Linux.do community](https://linux.do/)
