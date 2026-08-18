import Foundation

/// Last-known ownership, Notion row ids, queued local edits, and sync metadata,
/// stored at `~/Library/Application Support/PokeBinder/ownership.json`.
///
/// On launch the binder paints from this file before the network returns.
/// Pending edits survive relaunch and win over a later Notion value for the
/// same Pokédex number. `fileURL` is overridable so tests can use a temp file.
public enum OwnershipSnapshot {
    public struct Payload: Codable, Equatable {
        public var ownership: [String: Bool]
        public var pageIds: [String: String]
        public var pendingEdits: [String: Bool]?
        public var lastSyncedAt: Date?
    }

    public struct Contents: Equatable {
        public var ownership: [Int: Bool]
        public var pageIds: [Int: String]
        public var pendingEdits: [Int: Bool]
        public var lastSyncedAt: Date?

        public init(
            ownership: [Int: Bool] = [:],
            pageIds: [Int: String] = [:],
            pendingEdits: [Int: Bool] = [:],
            lastSyncedAt: Date? = nil
        ) {
            self.ownership = ownership
            self.pageIds = pageIds
            self.pendingEdits = pendingEdits
            self.lastSyncedAt = lastSyncedAt
        }

        public var syncState: OwnershipSyncState {
            OwnershipSyncState(
                ownership: ownership,
                pageIds: pageIds,
                pendingEdits: pendingEdits,
                lastSyncedAt: lastSyncedAt
            )
        }
    }

    public static let defaultFileURL: URL = {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PokeBinder", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent("ownership.json")
    }()

    /// Production points at Application Support; tests replace this with a temp URL.
    public static var fileURL: URL = defaultFileURL

    public static func resetFileURL() {
        fileURL = defaultFileURL
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    public static func load() -> Contents? {
        guard let data = try? Data(contentsOf: fileURL),
              let payload = try? decoder.decode(Payload.self, from: data) else {
            return nil
        }
        return contents(from: payload)
    }

    /// Decode a payload that may predate pending edits / last-sync metadata.
    public static func contents(from payload: Payload) -> Contents? {
        var ownership: [Int: Bool] = [:]
        var pageIds: [Int: String] = [:]
        var pendingEdits: [Int: Bool] = [:]
        for (key, value) in payload.ownership {
            if let dex = Int(key) { ownership[dex] = value }
        }
        for (key, value) in payload.pageIds {
            if let dex = Int(key) { pageIds[dex] = value }
        }
        for (key, value) in payload.pendingEdits ?? [:] {
            if let dex = Int(key) { pendingEdits[dex] = value }
        }
        guard !ownership.isEmpty || !pageIds.isEmpty || !pendingEdits.isEmpty else {
            return nil
        }
        return Contents(
            ownership: ownership,
            pageIds: pageIds,
            pendingEdits: pendingEdits,
            lastSyncedAt: payload.lastSyncedAt
        )
    }

    public static func save(
        ownership: [Int: Bool],
        pageIds: [Int: String],
        pendingEdits: [Int: Bool] = [:],
        lastSyncedAt: Date? = nil
    ) {
        save(
            Contents(
                ownership: ownership,
                pageIds: pageIds,
                pendingEdits: pendingEdits,
                lastSyncedAt: lastSyncedAt
            )
        )
    }

    public static func save(_ contents: Contents) {
        let payload = Payload(
            ownership: Dictionary(uniqueKeysWithValues: contents.ownership.map { (String($0.key), $0.value) }),
            pageIds: Dictionary(uniqueKeysWithValues: contents.pageIds.map { (String($0.key), $0.value) }),
            pendingEdits: contents.pendingEdits.isEmpty
                ? nil
                : Dictionary(uniqueKeysWithValues: contents.pendingEdits.map { (String($0.key), $0.value) }),
            lastSyncedAt: contents.lastSyncedAt
        )
        guard let data = try? encoder.encode(payload) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    public static func save(_ state: OwnershipSyncState) {
        save(
            Contents(
                ownership: state.ownership,
                pageIds: state.pageIds,
                pendingEdits: state.pendingEdits,
                lastSyncedAt: state.lastSyncedAt
            )
        )
    }

    /// Queue a local edit without talking to Notion. The snapshot ownership is
    /// updated too so a relaunch paints the user's choice immediately.
    public static func enqueue(dex: Int, owned: Bool) {
        var contents = load() ?? Contents()
        contents.pendingEdits[dex] = owned
        contents.ownership[dex] = owned
        save(contents)
    }

    public static func update(dex: Int, owned: Bool) {
        guard var contents = load() else { return }
        contents.ownership[dex] = owned
        save(contents)
    }
}
