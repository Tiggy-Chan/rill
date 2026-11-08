[English](README.md) | **简体中文**

# Rill

Rill 是一个小巧的 macOS 原生应用，可以把视频设为桌面壁纸。它只在菜单栏显示图标，平时不打扰你，壁纸看不见时会自动暂停。

## 功能

- **所有显示器都能显示动态壁纸。** 视频在系统壁纸之上、桌面图标和小组件之下。切换桌面空间时一直都在，也不会挡住鼠标点击。运行中接上或拔掉显示器都没问题。
- **每块显示器可以放不同的视频。** 没有单独设置的显示器会跟随主视频。
- **可轮换的视频库。** 想加多少视频都可以，能手动切换，也能按顺序或随机定时更换，间隔从 15 分钟到一天不等。
- **循环无缝，占用低。** 循环播放没有间隔，用硬件解码，默认静音。显示同一个视频的显示器共用一个解码器。在 Apple Silicon 上测试，循环播放 4K H.264 视频大约只占 2% CPU。
- **MKV 等格式也能播。** 系统打不开的容器——MKV、WebM、AVI、FLV，包括实为 Matroska 却改名成 `.mp4` 的文件——导入时会自动转成 MP4，不重新编码。
- **看不见时自动暂停。** 显示器休眠、锁屏，或者显示某个视频的所有显示器都被窗口完全遮挡时，这个视频会暂停。也可以设置在用电池或开启低电量模式时暂停。壁纸暂停时不会轮换视频。
- **锁屏同步。** 可选功能：把视频的一帧设为系统壁纸，锁屏会显示它。关闭后会恢复你原来的壁纸。默认关闭。
- **菜单栏面板简洁。** 有实时预览、播放/暂停、下一个、静音和音量，以及填充、适应、拉伸三种画面模式。其余选项都在「设置」（⌘,）里。
- **多语言。** 支持英文、简体中文、繁体中文、日语、韩语、德语、法语、西班牙语、意大利语、巴西葡萄牙语、俄语、荷兰语、波兰语和土耳其语。默认跟随系统语言，也可以在设置里自己选。
- **注重隐私，运行在沙盒中。** Rill 在 App 沙盒里运行，不联网，不收集任何数据，只能读取你选择的视频。

## 系统要求

- macOS 14 Sonoma 或更高版本
- 编译需要 Swift 6 工具链：安装 Xcode 16 或更高版本，或者只装命令行工具（`xcode-select --install`）

## 安装

从 [GitHub Releases](https://github.com/Tiggy-Chan/rill/releases) 下载最新版 `Rill-0.1.0.dmg`，打开磁盘映像并将 Rill 拖入「应用程序」文件夹即可。

*注：应用为 ad-hoc 签名且未经公证。首次打开若遇到系统安全提示，可在访达中右键点击 `Rill.app` 选择「打开」，或在终端执行 `xattr -cr /Applications/Rill.app`。*

### 从源码编译

也可以只装命令行工具（`xcode-select --install`）直接编译：

```sh
git clone https://github.com/Tiggy-Chan/rill.git
cd rill
./Scripts/fetch-ffmpeg.sh       # 先编译内置的 FFmpeg 库（约 2 分钟，一次即可）
./Scripts/build.sh              # 生成 build/Rill.app（或执行 ./Scripts/package-dmg.sh 打包 DMG）
cp -R build/Rill.app /Applications/
open /Applications/Rill.app
```

## 使用方法

1. 点击菜单栏里的水滴图标，打开面板。
2. 点击「选择视频…」或预览区域，把视频拖到菜单栏图标上，或者在访达里用「打开方式 › Rill」。新视频会加入视频库，并开始播放第一个。
3. 在面板里可以暂停或继续、切换到下一个视频、调节音量，以及选择填充、适应或拉伸。按 Esc 或点击面板外关闭面板。
4. 点击齿轮按钮或按 ⌘, 打开「设置…」，调整其他选项：
   - 「通用」：登录时启动、用电池时暂停、锁屏同步和语言。
   - 「视频库」：添加和移除视频、选择主视频、设置更换频率和是否随机。接了多块显示器时，还可以为每块显示器选择视频。

面板里的「移除」会把当前视频移出视频库，「退出」会退出应用，原来的壁纸就会显示出来。只有开启锁屏同步时，Rill 才会修改系统壁纸。

Rill 能播放系统支持的所有格式，比如 `.mp4`、`.mov`、`.m4v` 文件里的 H.264 或 HEVC 视频。系统打不开的容器——MKV、WebM、AVI、FLV——在添加时会以流拷贝方式转成 Rill 自己存储里的 MP4 文件（每 GB 大约一秒），源文件没变就一直复用；从视频库里移除时会删掉这份副本。视频本身需要是 H.264 或 HEVC 编码——其他编码无法在不重新编码的前提下转换，Rill 会明确提示，而不是无声失败。使用「填充」时，视频比例越接近屏幕比例，被裁掉的部分越少。

## 工作原理

Rill 为每块显示器创建一个无边框窗口，放在比桌面窗口高一层的位置，所以视频夹在系统壁纸和访达的桌面图标之间。这些窗口不响应鼠标，并且出现在所有桌面空间里。每个不同的视频对应一个 `AVPlayer`，显示同一视频的显示器共用它。每个播放器什么时候运行，由一个带单元测试的小策略决定，它综合了你的手动暂停、显示器休眠、锁屏、窗口遮挡和电源状态。选过的视频用安全范围书签记住，所以在沙盒里重启后也能重新打开，文件被重命名或移动过也没关系。

## 开发

```sh
./Scripts/fetch-ffmpeg.sh  # 把内置的 FFmpeg 库编译到 Vendor/（build/test 前需要先跑一次）
./Scripts/build.sh         # 低优先级的 release 编译（可用 CONFIG=debug、JOBS=n 覆盖）
./Scripts/test.sh          # 单元测试（Swift Testing），只装命令行工具也能运行
./Scripts/make-icon.sh     # 用 Scripts/make-icon.swift 重新生成 Resources/AppIcon.icns
```

```
Sources/Rill/
├─ MenuBar/     菜单栏图标和弹出面板
├─ UI/          SwiftUI 面板、设置窗口、所有界面文案
├─ Library/     视频库、轮换和显示器分配
├─ Wallpaper/   桌面层级的窗口和锁屏同步
├─ Playback/    循环播放器、暂停策略、系统状态监听、容器嗅探与转封装
└─ Settings/    设置的保存和语言选择
Sources/CRemux/           C 桥接层：通过 FFmpeg 把 MKV/AVI/FLV 流拷贝成 MP4
Resources/      Info.plist、权限文件、隐私清单、图标、*.lproj
Vendor/         FFmpeg 编译产物（由 Scripts/fetch-ffmpeg.sh 生成，不入库）
```

新增文案时，要同时加到 `Sources/Rill/UI/Strings.swift` 和每个 `Resources/*.lproj/Localizable.strings` 里。如果某种语言缺了键或少了 `%@`，测试会失败。

## 卸载

1. 在设置里关掉「登录时启动」。如果开着「在锁屏上显示视频画面」，也先关掉，这样原来的壁纸才会恢复。
2. 退出 Rill，删除 `Rill.app`。
3. 如果需要，删除它的设置和数据：`rm -rf ~/Library/Containers/com.tiggychan.rill`

## 许可证

Rill 是采用 [GNU 通用公共许可证 v3.0 (GPL-3.0)](LICENSE) 开源的软件。版权所有 © 2026 Tiggy-Chan。

Rill 内置了以 GNU LGPLv2.1 许可编译的 FFmpeg 库：`Scripts/fetch-ffmpeg.sh` 记录了确切的源码、校验和与编译参数，许可文本随应用一起分发。
