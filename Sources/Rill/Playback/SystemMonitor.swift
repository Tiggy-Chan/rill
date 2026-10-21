import AppKit
import IOKit.ps

@MainActor
final class SystemMonitor {
    var onChange: (() -> Void)?

    private(set) var screensAsleep = false
    private(set) var isOnBattery = SystemMonitor.readIsOnBattery()
    private(set) var isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    private var sessionActive = true
    private var screenLocked = false
    private var powerSource: CFRunLoopSource?

    var isSessionActive: Bool { sessionActive && !screenLocked }

    init() {
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.screensDidSleepNotification) { $0.screensAsleep = true }
        observe(workspace, NSWorkspace.screensDidWakeNotification) { $0.screensAsleep = false }
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification) { $0.sessionActive = false }
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification) { $0.sessionActive = true }

        let distributed = DistributedNotificationCenter.default()
        observe(distributed, Notification.Name("com.apple.screenIsLocked")) { $0.screenLocked = true }
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked")) { $0.screenLocked = false }

        observe(NotificationCenter.default, .NSProcessInfoPowerStateDidChange) {
            $0.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        }

        startPowerSourceMonitoring()
    }

    private func observe(
        _ center: NotificationCenter,
        _ name: Notification.Name,
        update: @escaping @MainActor @Sendable (SystemMonitor) -> Void
    ) {
        center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                update(self)
                self.onChange?()
            }
        }
    }

    private func startPowerSourceMonitoring() {
        // The callback holds an unretained pointer; the monitor lives for the whole app lifetime.
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let monitor = Unmanaged<SystemMonitor>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated {
                monitor.isOnBattery = SystemMonitor.readIsOnBattery()
                monitor.onChange?()
            }
        }, context)?.takeRetainedValue() else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        powerSource = source
    }

    nonisolated private static func readIsOnBattery() -> Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue()
        else { return false }
        return (type as String) == kIOPSBatteryPowerValue
    }
}
