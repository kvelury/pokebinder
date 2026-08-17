import SwiftUI

/// Settings. Part 1 ships the shell and the database-id field; part 3 fills in the
/// Notion section with a real "Connect to Notion" flow (OAuth via `NotionAuth`,
/// ported from Dosa) and hands a Notion-backed `OwnershipBackend` to
/// `CollectionStore.use(_:)`.
///
/// The Connect button is disabled rather than absent so the shape of the finished
/// panel is visible now, and so part 3 has an obvious place to land.
struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var collection: CollectionStore

    /// Defaulted to the database from the spec, but editable rather than hardcoded.
    @AppStorage("notionDatabaseId")
    private var databaseId = "187a66ca-0d0d-40da-b3aa-64f51adceb65"

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Collection") {
                    LabeledContent("Source", value: collection.backendName)
                    LabeledContent("Collected", value: "\(collection.ownedCount) of \(collection.totalCount)")
                }

                Section("Notion") {
                    LabeledContent("Status") {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Theme.textSecondary.opacity(0.5))
                                .frame(width: 7, height: 7)
                            Text("Not connected")
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }

                    TextField("Database ID", text: $databaseId)
                        .font(Theme.numberFont(size: 11))
                        .textFieldStyle(.roundedBorder)

                    Button("Connect to Notion…") {}
                        .disabled(true)

                    Text("Notion sync arrives in part 3. Until then the binder tracks your collection on this Mac, and everything else works exactly the same.")
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
        .frame(width: 470, height: 470)
    }
}
