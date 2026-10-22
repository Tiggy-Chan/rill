import SwiftUI

struct LibrarySettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section {
                if model.library.isEmpty {
                    Text(L10n.libraryEmpty)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    ForEach(model.library) { item in
                        LibraryRow(
                            item: item,
                            isCurrent: item.id == model.currentItemID,
                            select: { model.select(item.id) },
                            remove: { model.remove(item.id) }
                        )
                    }
                }
            } header: {
                HStack {
                    Text(L10n.videos)
                    Spacer()
                    Button(L10n.addVideos) {
                        if let urls = VideoPicker.run() {
                            model.addVideos(urls)
                        }
                    }
                    .controlSize(.small)
                }
            }

            Section {
                Picker(L10n.changeVideoEvery, selection: $model.rotationInterval) {
                    ForEach(RotationInterval.allCases) { interval in
                        Text(interval.title).tag(interval)
                    }
                }
                Toggle(L10n.shuffle, isOn: $model.shuffle)
                    .disabled(model.rotationInterval == .never && !model.canShowNext)
            } footer: {
                Text(L10n.rotationFooter)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if model.displays.count > 1 {
                Section {
                    ForEach(model.displays) { display in
                        Picker(display.name, selection: Binding(
                            get: { model.displayOverrides[display.id] },
                            set: { model.setVideo($0, forDisplay: display.id) }
                        )) {
                            Text(L10n.sameAsMain).tag(UUID?.none)
                            Divider()
                            ForEach(model.library) { item in
                                Text(item.name).tag(UUID?.some(item.id))
                            }
                        }
                    }
                } header: {
                    Text(L10n.displays)
                } footer: {
                    Text(L10n.displaysFooter)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minHeight: 320)
    }
}

private struct LibraryRow: View {
    let item: LibraryItem
    let isCurrent: Bool
    let select: () -> Void
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isCurrent ? "play.circle.fill" : "film")
                .foregroundStyle(isCurrent ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .frame(width: 18)
            Text(item.name)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            if !isCurrent {
                Button(L10n.show, action: select)
                    .controlSize(.small)
            }
            Button(action: remove) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(L10n.removeFromLibrary)
            .accessibilityLabel(L10n.removeFromLibrary)
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: select)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}
