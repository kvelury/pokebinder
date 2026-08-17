import Foundation

/// Last-known ownership and Notion row ids, stored at
/// `~/Library/Application Support/PokeBinder/ownership.json`.
///
/// On launch the binder paints from this file before the network returns;
/// the row ids are the `page_id`s for writeback, so a toggle right after
/// launch still reaches the matching Notion row.
enum OwnershipSnapshot {
    struct Payload: Codable {
        var ownership: [String: Bool]
        var pageIds: [String: String]
    }

    struct Contents {
        var ownership: [Int: Bool]
        var pageIds: [Int: String]
    }

    static var fileURL: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PokeBinder", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent("ownership.json")
    }

    static func load() -> Contents? {
        guard let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            return nil
        }
        var ownership: [Int: Bool] = [:]
        var pageIds: [Int: String] = [:]
        for (key, value) in payload.ownership {
            if let dex = Int(key) { ownership[dex] = value }
        }
        for (key, value) in payload.pageIds {
            if let dex = Int(key) { pageIds[dex] = value }
        }
        guard !ownership.isEmpty || !pageIds.isEmpty else { return nil }
        return Contents(ownership: ownership, pageIds: pageIds)
    }

    static func save(ownership: [Int: Bool], pageIds: [Int: String]) {
        let payload = Payload(
            ownership: Dictionary(uniqueKeysWithValues: ownership.map { (String($0.key), $0.value) }),
            pageIds: Dictionary(uniqueKeysWithValues: pageIds.map { (String($0.key), $0.value) })
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func update(dex: Int, owned: Bool) {
        guard var contents = load() else { return }
        contents.ownership[dex] = owned
        save(ownership: contents.ownership, pageIds: contents.pageIds)
    }
}
