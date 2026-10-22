**English** | [简体中文](README.zh-CN.md)

# Rill

A small native macOS app that plays a video as your desktop wallpaper. It lives in the menu bar, stays out of your way, and pauses itself when nobody can see it.

## Features

- **Live wallpaper on every display.** The video sits above the system wallpaper and below your desktop icons. It shows on every Space and never catches mouse clicks. You can connect or remove displays while it runs.
- **Seamless, quiet loop.** Looping has no gaps, decoding uses the hardware, and sound is muted by default. In testing on Apple Silicon, a 4K H.264 loop used about 2% CPU.
- **Simple menu bar panel.** It has a live preview, play/pause, mute and volume, and fill / fit / stretch.
- **Easy to set.** Choose a file from the panel, drop a video onto the menu bar icon, or use **Open With › Rill** in Finder.
- **Pauses when it can't be seen.** Playback stops while the displays sleep, while the screen is locked, or while other windows fully cover the wallpaper. It can also pause on battery power or in Low Power Mode.
- **Remembers your choice.** Your video and settings come back on the next launch, even if you renamed or moved the file.
- **Optional launch at login.** It is off by default.
- **Follows your system language.** The interface appears in English or Simplified Chinese to match macOS.
- **Private by design.** Rill makes no network connections and collects no data. Settings stay in the local preferences domain `com.tiggychan.rill`.

## Requirements

- macOS 14 Sonoma or later
- To build: a Swift 6 toolchain, from Xcode 16 or later or just the Command Line Tools (`xcode-select --install`)

## Build and install

There are no prebuilt releases yet, so build it from source:

```sh
git clone https://github.com/Tiggy-Chan/rill.git
cd rill
./Scripts/build.sh                  # creates build/Rill.app
cp -R build/Rill.app /Applications/
open /Applications/Rill.app
```

The app is ad-hoc signed and not notarized. It opens normally on the Mac that built it. If you copy it to another Mac, Gatekeeper may block it.

## Usage

1. Click the drop icon in the menu bar to open the panel.
2. Click **Choose Video…** or the preview area, or drop a video onto the menu bar icon.
3. Adjust the wallpaper from the panel:
   - Play/pause button, mute button and volume slider
   - **Scaling**: Fill · Fit · Stretch
   - **Pause on battery or in Low Power Mode**
   - **Launch at login**
4. Close the panel by clicking anywhere else or pressing Esc.

**Change Video…** picks another file. **Remove** turns the video wallpaper off. **Quit** closes the app. Rill never changes your system wallpaper setting, so removing the video or quitting brings your normal wallpaper back.

Rill plays any format AVFoundation supports, such as H.264 or HEVC in `.mp4`, `.mov` or `.m4v` files. With Fill, a video that matches your screen's aspect ratio shows the most of the frame.

## How it works

Rill opens one borderless window per display, one level above the desktop window. That puts the video between the system wallpaper and the Finder's desktop icons. The windows ignore the mouse and appear on all Spaces. All displays share one `AVPlayer`, so extra displays add no extra decoding work. A small, unit-tested policy decides when to play. It combines your own pause with display sleep, screen lock, window occlusion and power state.

## Development

```sh
./Scripts/build.sh      # low-priority release build (CONFIG=debug, JOBS=n to override)
./Scripts/test.sh       # unit tests (Swift Testing); works with only the Command Line Tools
./Scripts/make-icon.sh  # regenerates Resources/AppIcon.icns from Scripts/make-icon.swift
```

```
Sources/Rill/
├─ MenuBar/     status item and popover
├─ UI/          SwiftUI panel
├─ Wallpaper/   desktop-level windows, one per display
├─ Playback/    looping player, pause policy, system monitoring
└─ Settings/    persisted preferences
```

## Uninstall

1. If **Launch at login** is on, turn it off in the panel.
2. Quit Rill and delete `Rill.app`.
3. Optionally, remove its settings: `defaults delete com.tiggychan.rill`

## License

Rill is open-source software licensed under the [GNU General Public License v3.0](LICENSE). Copyright © 2026 Tiggy-Chan.
