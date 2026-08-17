import SwiftUI

/// Settings. Notion OAuth + MCP live here: Connect/Disconnect, live status, and
/// the workspace name. Connecting hands a `NotionOwnershipBackend` to
/// `CollectionStore.use(_:)`; disconnecting falls back to `LocalOwnershipBackend`.
struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var collection: CollectionStore
    @EnvironmentObject private var notion: NotionManager

    /// Defaulted to the database from the spec, but editable rather than hardcoded.
    @AppStorage(AppSettings.notionDatabaseIdKey)
    private var databaseId = AppSettings.defaultDatabaseId

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Collection") {
                    LabeledContent("Source", value: collection.backendName)
                    LabeledContent("Collected", value: "\(collection.ownedCount) of \(collection.totalCount)")
                }

                Section("Notion") {
                    LabeledContent("Status") {
                        statusView
                    }

                    TextField("Database ID", text: $databaseId)
                        .font(Theme.numberFont(size: 11))
                        .textFieldStyle(.roundedBorder)

                    connectionButton

                    if let error = notion.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text("Connect your Notion account (opens the browser). Ownership is read from this database and the Owned toggle writes back to the matching row.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section("About") {
                    LabeledContent("Binder", value: "\(Pokedex.pageCount) pages · \(Pokedex.count) Pokémon")
                    LabeledContent("Artwork", value: "PokeAPI official artwork")
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
        .frame(width: 470, height: 490)
        .onChange(of: notion.connectionState) { _, state in
            if case .connected = state {
                Task { await collection.use(NotionOwnershipBackend(manager: notion)) }
            }
        }
    }

    @ViewBuilder
    private var statusView: some View {
        HStack(spacing: 6) {
            switch notion.connectionState {
            case .disconnected:
                Circle()
                    .fill(Theme.textSecondary.opacity(0.5))
                    .frame(width: 7, height: 7)
                Text("Not connected")
                    .foregroundStyle(Theme.textSecondary)
            case .connecting:
                ProgressView()
                    .controlSize(.mini)
                Text("Waiting for authorization…")
                    .foregroundStyle(Theme.textSecondary)
            case .connected(let workspace):
                Circle()
                    .fill(Color.green)
                    .frame(width: 7, height: 7)
                Text(workspace)
                    .foregroundStyle(Theme.textPrimary)
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
