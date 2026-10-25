**English** | [简体中文](README.zh-CN.md)

# Rill

A small native macOS app that plays video as your desktop wallpaper. It lives in the menu bar, stays out of your way, and pauses itself when nobody can see it.

## Features

- **Live wallpaper on every display.** The video sits above the system wallpaper and below your desktop icons and widgets. It shows on every Space and never catches mouse clicks. You can connect or remove displays while it runs.
- **A different video on each display.** Every display follows the main video unless you pick one for it.
- **A library that rotates.** Add as many videos as you like and switch between them by hand, on a schedule from every 15 minutes to once a day, in order or shuffled.
- **Seamless, quiet loop.** Looping has no gaps, decoding uses the hardware, and sound is muted by default. Displays showing the same video share one decoder. In testing on Apple Silicon, a 4K H.264 loop used about 2% CPU.
- **Plays MKV and friends.** Videos in containers the system can't open — MKV and WebM, AVI, FLV, including `.mp4` files that are secretly Matroska — are converted to MP4 automatically on import, without re-encoding.
- **Pauses when it can't be seen.** Each video stops while the displays sleep, while the screen is locked, or while windows fully cover every display showing it. It can also pause on battery power or in Low Power Mode. Rotation waits while the wallpaper is paused.
- **Lock screen to match.** Optionally, Rill sets a still from the video as your macOS wallpaper, which is what the lock screen shows. Your own wallpaper comes back when you turn it off. It's off by default.
- **Simple menu bar panel.** A live preview, play/pause, next, mute and volume, and fill / fit / stretch. Everything else lives in Settings (⌘,).
- **Speaks your language.** English, Simplified and Traditional Chinese, Japanese, Korean, German, French, Spanish, Italian, Brazilian Portuguese, Russian, Dutch, Polish and Turkish. Rill follows your system language, or you can pick one in Settings.
- **Private and sandboxed.** Rill runs in the App Sandbox, makes no network connections and collects no data. It can only read the videos you choose.

## Requirements

- macOS 14 Sonoma or later
- To build: a Swift 6 toolchain, from Xcode 16 or later or just the Command Line Tools (`xcode-select --install`)

## Build and install

There are no prebuilt releases yet, so build it from source:

```sh
git clone https://github.com/Tiggy-Chan/rill.git
cd rill
./Scripts/fetch-ffmpeg.sh       # builds the bundled FFmpeg libraries once (~2 minutes)
./Scripts/build.sh              # creates build/Rill.app
cp -R build/Rill.app /Applications/
open /Applications/Rill.app
```

The app is ad-hoc signed and not notarized. It opens normally on the Mac that built it. If you copy it to another Mac, Gatekeeper may block it.

## Usage

1. Click the drop icon in the menu bar to open the panel.
2. Click **Choose Video…** or the preview area, drop videos onto the menu bar icon, or use **Open With › Rill** in Finder. New videos are added to your library and the first one starts playing.
3. From the panel, pause or resume, skip to the next video, change the volume, and choose Fill, Fit or Stretch. Press Esc or click elsewhere to close it.
4. Open **Settings…** with the gear button or ⌘, for everything else:
   - **General:** launch at login, pausing on battery, lock screen sync and language.
   - **Library:** add and remove videos, pick the main video, set how often it changes and whether to shuffle. With more than one display connected, choose a video for each display.

**Remove** in the panel takes the current video out of your library. **Quit** closes the app and your normal wallpaper shows again. Rill only changes your system wallpaper while lock screen sync is on.

Rill plays any format the system supports, such as H.264 or HEVC in `.mp4`, `.mov` or `.m4v` files. Videos in containers the system can't open — MKV and WebM, AVI, FLV — are stream-copied into an MP4 file in Rill's own storage when you add them (about a second per gigabyte), and the copy is reused until the source file changes; removing the video deletes its copy. The video itself must be H.264 or HEVC — other codecs can't be converted without re-encoding, and Rill says so instead of failing silently. With Fill, a video that matches your screen's aspect ratio shows the most of the frame.

## How it works

Rill opens one borderless window per display, one level above the desktop window. That puts the video between the system wallpaper and the Finder's desktop icons. The windows ignore the mouse and appear on all Spaces. Each distinct video gets one `AVPlayer`, shared by every display that shows it. A small, unit-tested policy decides when each player runs. It combines your own pause with display sleep, screen lock, window occlusion and power state. Chosen videos are remembered with security-scoped bookmarks, so they reopen after a relaunch inside the sandbox even if you rename or move them.

## Development

```sh
./Scripts/fetch-ffmpeg.sh  # builds the bundled FFmpeg libraries into Vendor/ (needed once before build/test)
./Scripts/build.sh         # low-priority release build (CONFIG=debug, JOBS=n to override)
./Scripts/test.sh          # unit tests (Swift Testing); works with only the Command Line Tools
./Scripts/make-icon.sh     # regenerates Resources/AppIcon.icns from Scripts/make-icon.swift
```

```
Sources/Rill/
├─ MenuBar/     status item and popover
├─ UI/          SwiftUI panel, settings window, all user-facing strings
├─ Library/     library items, rotation, display assignment
├─ Wallpaper/   desktop-level windows and lock screen sync
├─ Playback/    looping player, pause policy, system monitoring, container sniffing and remuxing
└─ Settings/    persisted preferences and language choice
Sources/CRemux/           C bridge: stream-copies MKV/AVI/FLV into MP4 through FFmpeg
Resources/      Info.plist, entitlements, privacy manifest, icon, *.lproj
Vendor/         FFmpeg build output (rebuilt by Scripts/fetch-ffmpeg.sh, not checked in)
```

To add a string, add it to `Sources/Rill/UI/Strings.swift` and to every `Resources/*.lproj/Localizable.strings`. The tests fail if any language is missing a key or drops a `%@`.

## Uninstall

1. In Settings, turn off **Launch at login**. If **Show the video on the lock screen** is on, turn it off too so your own wallpaper comes back.
2. Quit Rill and delete `Rill.app`.
3. Optionally, remove its settings and data: `rm -rf ~/Library/Containers/com.tiggychan.rill`

## License

Rill is open-source software licensed under the [GNU General Public License v3.0](LICENSE). Copyright © 2026 Tiggy-Chan.

Rill bundles FFmpeg libraries built under the GNU LGPLv2.1: `Scripts/fetch-ffmpeg.sh` records the exact source, checksum and build flags, and the license text ships inside the app.
