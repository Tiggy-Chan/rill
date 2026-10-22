import AppKit
import AVFoundation
import SwiftUI

struct PanelView: View {
    @Bindable var model: AppModel
    let chooseVideo: () -> Void
    let openSettings: () -> Void
    let quit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if let problem = model.problem {
                ProblemBanner(message: problem)
            }
            PreviewCard(model: model, chooseVideo: chooseVideo)
            if let video = model.video {
                details(for: video)
                playbackControls
                fillModeRow
            }
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 300)
    }

    private var header: some View {
        HStack(spacing: 7) {
            Image(systemName: "drop.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tint)
            Text("Rill")
                .font(.headline)
            Spacer()
            StatusBadge(status: model.status)
        }
    }

    private func details(for video: VideoInfo) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(video.name)
                .font(.callout.weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .help(video.name)
            Text(video.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            if case .autoPaused(let reason) = model.status {
                Label(reason.explanation, systemImage: "moon.zzz.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
    }

    private var playbackControls: some View {
        HStack(spacing: 10) {
            Button(action: model.togglePause) {
                Image(systemName: model.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .background(.quaternary, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help(model.isPaused ? L10n.resume : L10n.pause)
            .accessibilityLabel(model.isPaused ? L10n.resume : L10n.pause)

            Button(action: model.toggleMute) {
                Image(systemName: model.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(model.isMuted ? L10n.unmute : L10n.mute)
            .accessibilityLabel(model.isMuted ? L10n.unmute : L10n.mute)

            VolumeSlider(value: volumeBinding)

            if model.canShowNext {
                Button(action: model.showNext) {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(L10n.nextVideo)
                .accessibilityLabel(L10n.nextVideo)
            }
        }
    }

    private var volumeBinding: Binding<Double> {
        Binding(
            get: { model.isMuted ? 0 : Double(model.volume) },
            set: { newValue in
                model.volume = Float(newValue)
                model.isMuted = newValue == 0
            }
        )
    }

    private var fillModeRow: some View {
        HStack {
            Text(L10n.scaling)
                .foregroundStyle(.secondary)
            Spacer()
            Picker(L10n.scaling, selection: $model.fillMode) {
                ForEach(FillMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
        .font(.callout)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Button(model.video == nil ? L10n.chooseVideo : L10n.changeVideo, action: chooseVideo)
            if model.video != nil {
                Button(L10n.remove, action: model.removeCurrent)
                    .help(L10n.removeHelp)
            }
            Spacer()
            Button(action: openSettings) {
                Image(systemName: "gearshape")
            }
            .help(L10n.settings)
            .accessibilityLabel(L10n.settings)
            .keyboardShortcut(",")
            Button(L10n.quit, action: quit)
                .keyboardShortcut("q")
        }
        .buttonStyle(.borderless)
        .font(.callout)
        .foregroundStyle(.secondary)
    }
}

private struct ProblemBanner: View {
    let message: String

    var body: some View {
        Label {
            Text(message)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// The system Slider renders without a visible track inside popovers on recent macOS.
private struct VolumeSlider: View {
    @Binding var value: Double

    private let knobSize: CGFloat = 12
    private let trackHeight: CGFloat = 4

    var body: some View {
        GeometryReader { geometry in
            let travel = max(geometry.size.width - knobSize, 1)
            let offset = CGFloat(value) * travel
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.primary.opacity(0.16))
                    .frame(height: trackHeight)
                Capsule()
                    .fill(.tint)
                    .frame(width: offset + knobSize / 2, height: trackHeight)
                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.3), radius: 1.5, y: 0.5)
                    .frame(width: knobSize, height: knobSize)
                    .offset(x: offset)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { drag in
                    value = min(max((drag.location.x - knobSize / 2) / travel, 0), 1)
                }
            )
        }
        .frame(height: 18)
        .accessibilityElement()
        .accessibilityLabel(L10n.volume)
        .accessibilityValue("\(Int((value * 100).rounded()))%")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(value + 0.1, 1)
            case .decrement: value = max(value - 0.1, 0)
            @unknown default: break
            }
        }
    }
}

private struct StatusBadge: View {
    let status: PlaybackStatus

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(title)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.quaternary.opacity(0.6), in: Capsule())
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        switch status {
        case .idle: L10n.notSet
        case .playing: L10n.playing
        case .paused: L10n.paused
        case .autoPaused: L10n.autoPaused
        }
    }

    private var color: Color {
        switch status {
        case .idle: .secondary
        case .playing: .green
        case .paused: .orange
        case .autoPaused: .yellow
        }
    }
}

private struct PreviewCard: View {
    let model: AppModel
    let chooseVideo: () -> Void
    @State private var isHovering = false

    private let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)

    var body: some View {
        Button(action: chooseVideo) {
            ZStack {
                if model.video != nil {
                    PlayerPreview(player: model.previewPlayer, gravity: model.fillMode)
                    if isHovering {
                        changeOverlay
                    }
                } else {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(screenAspectRatio, contentMode: .fit)
            .clipShape(shape)
            .overlay(shape.strokeBorder(.separator, lineWidth: model.video == nil ? 0 : 0.5))
            .contentShape(shape)
            .animation(.easeOut(duration: 0.15), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityLabel(model.video == nil ? L10n.chooseAVideo : L10n.changeVideoShort)
    }

    private var changeOverlay: some View {
        ZStack {
            Color.black.opacity(0.25)
            Label(L10n.changeVideoShort, systemImage: "arrow.triangle.2.circlepath")
                .font(.callout.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .transition(.opacity)
    }

    private var emptyState: some View {
        ZStack {
            shape.fill(.quaternary.opacity(isHovering ? 0.8 : 0.4))
            shape.strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .foregroundStyle(isHovering ? .secondary : .tertiary)
            VStack(spacing: 6) {
                Image(systemName: "play.rectangle.on.rectangle")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 2)
                Text(L10n.chooseAVideo)
                    .font(.callout.weight(.medium))
                Text(L10n.orDropOnIcon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var screenAspectRatio: CGFloat {
        guard let size = NSScreen.main?.frame.size, size.height > 0 else { return 16 / 10 }
        return size.width / size.height
    }
}

private struct PlayerPreview: NSViewRepresentable {
    let player: AVPlayer?
    let gravity: FillMode

    func makeNSView(context: Context) -> PlayerView {
        PlayerView(player: player, cornerRadius: 10)
    }

    func updateNSView(_ view: PlayerView, context: Context) {
        if view.player !== player {
            view.player = player
        }
        view.videoGravity = gravity.videoGravity
    }
}
