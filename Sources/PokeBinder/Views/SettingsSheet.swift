import PokeBinderSync
import SwiftUI

/// Settings. Notion OAuth + MCP live here: Connect/Disconnect, live status, and
/// the workspace name. Connecting hands a `NotionOwnershipBackend` to
/// `CollectionStore.use(_:)`; disconnecting falls back to `LocalOwnershipBackend`.
struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var collection: CollectionStore
    @EnvironmentObject private var notion: NotionManager

    @AppStorage(AppSettings.appearanceKey) private var appearance: AppAppearance = .system
    @AppStorage(AppSettings.appStyleKey) private var appStyle: AppStyle = .classic
    @AppStorage(AppSettings.glassPaletteKey) private var glassPalette: GlassPalette = .fullGlass
    @AppStorage(AppSettings.typeEraKey) private var typeEra: TypeEra = .current
    @AppStorage(AppSettings.matchupDetailLevelKey) private var matchupDetailLevel: MatchupDetailLevel = .simple

    /// Defaulted to the database from the spec, but editable rather than hardcoded.
    @AppStorage(AppSettings.notionDatabaseIdKey)
    private var databaseId = AppSettings.defaultDatabaseId

    @AppStorage(AppSettings.notionSyncIntervalKey)
    private var syncInterval: NotionSyncInterval = .manual
    @AppStorage(AppSettings.notionSyncCustomMinutesKey)
    private var customSyncMinutes = AppSettings.defaultNotionSyncCustomMinutes
    @State private var customMinutesText = ""

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Collection") {
                    LabeledContent("Source", value: collection.backendName)
                    LabeledContent("Collected", value: "\(collection.ownedCount) of \(collection.totalCount)")
                }

                Section("Theme") {
                    Picker("Style", selection: $appStyle) {
                        ForEach(AppStyle.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if appStyle == .liquidGlass {
                        LabeledContent("Glass palette") {
                            Text(glassPalette.title)
                                .foregroundStyle(theme.textSecondary)
                        }

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(GlassPalette.allCases) { palette in
                                paletteChoice(palette)
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    Picker("Appearance", selection: $appearance) {
                        ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    Text("Auto follows the Appearance setting in System Settings.")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section("Types") {
                    Picker("Assignments", selection: $typeEra) {
                        ForEach(TypeEra.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    Text("Current includes later Steel and Fairy assignments. Gen I shows the types used in the original games.")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Picker("Hover matchups", selection: $matchupDetailLevel) {
                        ForEach(MatchupDetailLevel.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    Text("Controls the matchup rows shown when hovering a card. Simple shows strengths and weaknesses. Advanced adds resistances and immunities. Full includes offensive coverage gaps. The focused card always shows Full details.")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section("Notion") {
                    LabeledContent("Status") {
                        statusView
                    }

                    TextField("Database ID", text: $databaseId)
                        .font(theme.numberFont(size: 11))
                        .textFieldStyle(.roundedBorder)

                    Picker("Refresh", selection: $syncInterval) {
                        ForEach(NotionSyncInterval.allCases) { interval in
                            Text(interval.shortTitle).tag(interval)
                        }
                    }
                    .pickerStyle(.segmented)
                    .help("How often to pull Notion and flush queued local edits while the app is open.")

                    if syncInterval == .custom {
                        TextField("Minutes", text: $customMinutesText)
                            .font(theme.numberFont(size: 13))
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: customMinutesText) { _, newValue in
                                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                if let value = Int(trimmed) {
                                    customSyncMinutes = NotionSyncInterval.sanitizedCustomMinutes(value)
                                }
                            }
                            .onSubmit { commitCustomMinutes() }
                    }

                    if let lastSynced = collection.lastSyncedAt {
                        LabeledContent("Last synced", value: lastSynced.formatted(date: .omitted, time: .shortened))
                    }

                    connectionButton

                    if let error = notion.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text("Connect your Notion account (opens the browser). Edits you make are queued and written on the next sync. Automatic refresh runs only while PokéBinder is open; the resync button always pulls Notion and flushes the queue. A pending local edit wins if the same Pokémon also changed in Notion.")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section("About") {
                    LabeledContent("Binder", value: "\(Pokedex.pageCount) pages · \(Pokedex.count) Pokémon")
                    LabeledContent("Artwork", value: "PokeAPI official artwork")
                    LabeledContent("Type matchups", value: "PokeAPI type charts")
                    LabeledContent("Type icons", value: "duiker101")
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(14)
        }
        .frame(width: 520, height: 760)
        .onAppear { customMinutesText = String(customSyncMinutes) }
        .onChange(of: customSyncMinutes) { _, newValue in
            customMinutesText = String(newValue)
        }
        .onChange(of: syncInterval) { _, newValue in
            if newValue == .custom {
                commitCustomMinutes()
            }
        }
        .onChange(of: notion.connectionState) { _, state in
            if case .connected = state {
                Task { await collection.use(NotionOwnershipBackend(manager: notion)) }
            }
        }
    }

    private func commitCustomMinutes() {
        let trimmed = customMinutesText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let value = Int(trimmed) {
            customSyncMinutes = NotionSyncInterval.sanitizedCustomMinutes(value)
        }
        customMinutesText = String(customSyncMinutes)
    }

    private func paletteChoice(_ palette: GlassPalette) -> some View {
        let preview = Theme(style: .liquidGlass, palette: palette)
        let isSelected = glassPalette == palette

        return Button {
            glassPalette = palette
        } label: {
            HStack(spacing: 9) {
                ZStack {
                    Circle()
                        .fill(preview.cover)
                        .frame(width: 22, height: 22)
                    Circle()
                        .fill(preview.brass)
                        .frame(width: 11, height: 11)
                        .offset(x: 8, y: 7)
                }
                .frame(width: 32)

                Text(palette.title)
                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(theme.brass)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 42)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? theme.controlFillActive : theme.controlFill.opacity(0.62))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? theme.brass.opacity(0.7) : theme.controlStroke, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(palette.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var statusView: some View {
        HStack(spacing: 6) {
            switch notion.connectionState {
            case .disconnected:
                Circle()
                    .fill(theme.textSecondary.opacity(0.5))
                    .frame(width: 7, height: 7)
                Text("Not connected")
                    .foregroundStyle(theme.textSecondary)
            case .connecting:
                ProgressView()
                    .controlSize(.mini)
                Text("Waiting for authorization…")
                    .foregroundStyle(theme.textSecondary)
            case .connected(let workspace):
                Circle()
                    .fill(Color.green)
                    .frame(width: 7, height: 7)
                Text(workspace)
                    .foregroundStyle(theme.textPrimary)
            }
        }
    }

    @ViewBuilder
    private var connectionButton: some View {
        switch notion.connectionState {
        case .disconnected:
            Button("Connect to Notion…") { notion.connect() }
        case .connecting:
            Button("Cancel") { notion.cancelConnect() }
        case .connected:
            Button("Disconnect", role: .destructive) {
                notion.disconnect()
                Task { await collection.use(LocalOwnershipBackend()) }
            }
        }
    }
}
