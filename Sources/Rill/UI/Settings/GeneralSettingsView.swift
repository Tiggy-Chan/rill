import AppKit
import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var model: AppModel
    @State private var language = LanguagePreference.current
    private let launchedLanguage = LanguagePreference.current

    var body: some View {
        Form {
            Section {
                Toggle(L10n.launchAtLogin, isOn: Binding(
                    get: { model.launchAtLogin == .enabled || model.launchAtLogin == .requiresApproval },
                    set: { model.setLaunchAtLogin($0) }
                ))
                if model.launchAtLogin == .requiresApproval {
                    Button(L10n.allowInSystemSettings, action: model.openLoginItemsSettings)
                        .buttonStyle(.link)
                }
                Toggle(L10n.pauseOnBattery, isOn: $model.pauseWhenSavingPower)
            }

            Section {
                Toggle(isOn: $model.syncLockScreen) {
                    Text(L10n.syncLockScreen)
                    Text(L10n.syncLockScreenDetail)
                }
            }

            Section {
                Picker(L10n.language, selection: $language) {
                    Text(L10n.systemLanguage(AppLanguage.nativeName(AppLanguage.system))).tag(String?.none)
                    Divider()
                    ForEach(AppLanguage.available, id: \.self) { code in
                        Text(AppLanguage.nativeName(code)).tag(String?.some(code))
                    }
                }
                .onChange(of: language) { _, newValue in
                    LanguagePreference.current = newValue
                }
                if language != launchedLanguage {
                    HStack {
                        Text(L10n.relaunchToApply)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(L10n.relaunchNow, action: LanguagePreference.relaunch)
                    }
                }
            }

            Section {
                Link(destination: URL(string: "https://github.com/Tiggy-Chan/rill")!) {
                    HStack {
                        Text("Rill")
                        Text("by Tiggy-Chan")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear(perform: model.refreshLaunchAtLogin)
    }
}

/// The per-app language override, stored where macOS's own per-app language setting keeps it.
enum LanguagePreference {
    private static let key = "AppleLanguages"

    /// nil means follow the system language.
    static var current: String? {
        get {
            let domain = UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
            return (domain?[key] as? [String])?.first
        }
        set {
            if let newValue {
                UserDefaults.standard.set([newValue], forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }

    @MainActor
    static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            Task { @MainActor in NSApp.terminate(nil) }
        }
    }
}
