import AppKit
import SwiftUI

/// Click to record a system-wide shortcut; Esc cancels, Delete clears.
struct ShortcutRecorder: View {
    let shortcut: KeyShortcut?
    let onChange: (KeyShortcut?) -> Bool
    let onRecordingChange: (Bool) -> Void

    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var rejected = false

    var body: some View {
        HStack(spacing: 6) {
            Button(action: toggleRecording) {
                Text(label)
                    .monospacedDigit()
                    .frame(minWidth: 96)
                    .foregroundStyle(isRecording || shortcut == nil ? .secondary : .primary)
            }
            .buttonStyle(.bordered)
            .tint(isRecording ? .accentColor : nil)
            .accessibilityValue(shortcut?.displayString ?? L10n.none)
            if shortcut != nil && !isRecording {
                Button {
                    _ = onChange(nil)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help(L10n.clearShortcut)
                .accessibilityLabel(L10n.clearShortcut)
            }
        }
        .onDisappear(perform: stopRecording)
    }

    private var label: String {
        if rejected { return L10n.shortcutTaken }
        if isRecording { return L10n.typeShortcut }
        return shortcut?.displayString ?? L10n.recordShortcut
    }

    private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        rejected = false
        isRecording = true
        onRecordingChange(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch Int(event.keyCode) {
            case 53: // Esc
                stopRecording()
            case 51, 117: // Delete, Forward Delete
                _ = onChange(nil)
                stopRecording()
            default:
                guard let recorded = KeyShortcut(event: event) else {
                    NSSound.beep()
                    return nil
                }
                let accepted = onChange(recorded)
                stopRecording()
                if !accepted {
                    rejected = true
                    NSSound.beep()
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        rejected = false
                    }
                }
            }
            return nil
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        if isRecording {
            isRecording = false
            onRecordingChange(false)
        }
    }
}
