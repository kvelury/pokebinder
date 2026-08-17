import Foundation
import SwiftUI

/// App-facing Notion integration: connection lifecycle plus this binder's
/// schema (`fetchAll` / `setOwned`) via Notion's hosted MCP tools.
@MainActor
final class NotionManager: ObservableObject {
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected(workspace: String)
    }

    @Published var connectionState: ConnectionState = .disconnected
    @Published var errorMessage: String?
    @Published var errorDetail: String?

    private let auth = NotionAuth()
    private let client = NotionMCPClient()
    private var connectTask: Task<Void, Never>?
    /// Notion row id keyed by Pokédex number — the `page_id` for writeback.
    private var pageIds: [Int: String] = [:]

    var isConnected: Bool {
        if case .connected = connectionState { return true }
        return false
    }

    var workspaceDisplayName: String {
        switch connectionState {
        case .connected(let workspace):
            return workspace
        default:
            return UserDefaults.standard.string(forKey: AppSettings.notionWorkspaceKey) ?? "Notion"
        }
    }

    init() {
        let defaults = UserDefaults.standard
        if auth.isConnected {
            connectionState = .connected(workspace: defaults.string(forKey: AppSettings.notionWorkspaceKey) ?? "Notion")
        }
        if let snapshot = OwnershipSnapshot.load() {
            pageIds = snapshot.pageIds
        }
    }

    // MARK: - Connection

    func connect() {
        guard case .disconnected = connectionState else { return }
        connectionState = .connecting
        clearError()
        connectTask = Task {
            do {
                try await auth.authorize()
                client.reset()
                let workspace = (try? await fetchWorkspaceName()) ?? "Notion"
                UserDefaults.standard.set(workspace, forKey: AppSettings.notionWorkspaceKey)
                connectionState = .connected(workspace: workspace)
            } catch NotionAuth.AuthError.cancelled {
                connectionState = .disconnected
            } catch {
                setError(error)
                connectionState = .disconnected
            }
        }
    }

    func cancelConnect() {
        auth.cancelAuthorization()
        connectTask?.cancel()
        connectionState = .disconnected
    }

    func disconnect() {
        auth.clear()
        client.reset()
        pageIds = [:]
        connectionState = .disconnected
        clearError()
    }

    // MARK: - Schema

    /// One `notion-query-data-sources` call. Joins on `Pokédex #`, never name.
    func fetchAll() async throws -> (ownership: [Int: Bool], pageIds: [Int: String]) {
        let databaseId = Self.resolvedDatabaseId
        let collectionURL = "collection://\(databaseId)"
        let text = try await callToolAuthorized("notion-query-data-sources", [
            "data": [
                "data_source_urls": [collectionURL],
                "query": "SELECT * FROM \"\(collectionURL)\" ORDER BY \"Pokédex #\" ASC",
            ],
        ])
        let parsed = Self.parseQueryResult(text)
        guard !parsed.pageIds.isEmpty else {
            throw NotionMCPClient.ClientError.malformed("query returned no Pokémon rows")
        }
        pageIds = parsed.pageIds

        var ownership = Dictionary(uniqueKeysWithValues: (1...Pokedex.count).map { ($0, false) })
        for (dex, owned) in parsed.ownership where (1...Pokedex.count).contains(dex) {
            ownership[dex] = owned
        }
        return (ownership, parsed.pageIds)
    }

    func setOwned(dex: Int, owned: Bool) async throws {
        guard let pageId = pageIds[dex] else {
            throw NotionMCPClient.ClientError.malformed("no Notion page id for Pokédex #\(dex)")
        }
        _ = try await callToolAuthorized("notion-update-page", [
            "command": "update_properties",
            "page_id": pageId,
            "properties": ["Owned": owned ? "__YES__" : "__NO__"],
        ])
    }

    // MARK: - Plumbing

    private static var resolvedDatabaseId: String {
        let stored = UserDefaults.standard.string(forKey: AppSettings.notionDatabaseIdKey) ?? ""
        let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? AppSettings.defaultDatabaseId : trimmed
    }

    private func setError(_ error: Error) {
        errorMessage = error.localizedDescription
        errorDetail = (error as? DetailedError)?.errorDetail
    }

    private func clearError() {
        errorMessage = nil
        errorDetail = nil
    }

    private func callToolAuthorized(_ name: String, _ arguments: [String: Any]) async throws -> String {
        let token = try await auth.validAccessToken()
        do {
            return try await client.callTool(name: name, arguments: arguments, accessToken: token)
        } catch NotionMCPClient.ClientError.unauthorized {
            let refreshed = try await auth.refreshAccessToken()
            client.reset()
            return try await client.callTool(name: name, arguments: arguments, accessToken: refreshed)
        }
    }

    private func fetchWorkspaceName() async throws -> String? {
        let text = try await callToolAuthorized("notion-fetch", ["id": "self"])
        if let name = Self.workspaceName(fromJSON: text) {
            return name
        }
        if let workspaceRange = text.range(of: "workspace", options: .caseInsensitive) {
            let tail = String(text[workspaceRange.upperBound...])
            if let match = tail.range(of: #""name"\s*:\s*"([^"]+)""#, options: .regularExpression) {
                let fragment = String(tail[match])
                if let nameMatch = fragment.range(of: #":\s*"([^"]+)""#, options: .regularExpression) {
                    return String(fragment[nameMatch])
                        .replacingOccurrences(of: #"^:\s*""#, with: "", options: .regularExpression)
                        .replacingOccurrences(of: "\"", with: "")
                }
            }
        }
        return nil
    }

    private static func workspaceName(fromJSON text: String) -> String? {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let selfObj = json["self"] as? [String: Any] {
            if let workspace = selfObj["workspace"] as? [String: Any], let name = workspace["name"] as? String {
                return name
            }
            if let name = selfObj["workspace_name"] as? String { return name }
            if let name = selfObj["name"] as? String { return name }
        }
        if let workspace = json["workspace"] as? [String: Any], let name = workspace["name"] as? String {
            return name
        }
        return nil
    }

    // MARK: - Response parsing
    //
    // MCP tools return markdown/tagged text meant for language models, not a
    // fixed schema. Tolerate JSON records (the shape in the spec), nested
    // `results` arrays, and markdown tables.

    static func parseQueryResult(_ text: String) -> (ownership: [Int: Bool], pageIds: [Int: String]) {
        var ownership: [Int: Bool] = [:]
        var pageIds: [Int: String] = [:]

        for record in jsonRecords(in: text) {
            ingest(record, ownership: &ownership, pageIds: &pageIds)
        }
        if pageIds.isEmpty {
            parseMarkdownTable(text, ownership: &ownership, pageIds: &pageIds)
        }
        return (ownership, pageIds)
    }

    private static func ingest(
        _ record: [String: Any],
        ownership: inout [Int: Bool],
        pageIds: inout [Int: String]
    ) {
        guard let dex = dexNumber(from: record) else { return }
        if let owned = ownedValue(from: record) {
            ownership[dex] = owned
        }
        if let id = pageId(from: record) {
            pageIds[dex] = id
        }
    }

    private static func jsonRecords(in text: String) -> [[String: Any]] {
        var records: [[String: Any]] = []

        func add(_ value: Any) {
            if let dict = value as? [String: Any] {
                if dexNumber(from: dict) != nil {
                    records.append(dict)
                } else {
                    for nested in dict.values { add(nested) }
                }
            } else if let array = value as? [Any] {
                array.forEach(add)
            } else if let string = value as? String, let nested = decodeJSON(string) {
                add(nested)
            }
        }

        let stripped = stripCodeFences(text)
        if let obj = decodeJSON(stripped) {
            add(obj)
            if !records.isEmpty { return records }
        }

        var index = stripped.startIndex
        while index < stripped.endIndex {
            let char = stripped[index]
            if char == "{" || char == "[" {
                if let (value, end) = extractJSONValue(stripped, start: index) {
                    add(value)
                    index = end
                    continue
                }
            }
            index = stripped.index(after: index)
        }
        return records
    }

    private static func decodeJSON(_ text: String) -> Any? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        return obj
    }

    private static func stripCodeFences(_ text: String) -> String {
        var result = text
        if let fence = try? NSRegularExpression(pattern: #"```(?:json)?\s*([\s\S]*?)```"#) {
            let ns = text as NSString
            result = fence.stringByReplacingMatches(
                in: text,
                range: NSRange(location: 0, length: ns.length),
                withTemplate: "$1"
            )
        }
        return result
    }

    private static func extractJSONValue(_ text: String, start: String.Index) -> (Any, String.Index)? {
        let open = text[start]
        guard open == "{" || open == "[" else { return nil }
        let close: Character = open == "{" ? "}" : "]"
        var depth = 0
        var inString = false
        var escape = false
        var index = start
        while index < text.endIndex {
            let char = text[index]
            if inString {
                if escape {
                    escape = false
                } else if char == "\\" {
                    escape = true
                } else if char == "\"" {
                    inString = false
                }
            } else if char == "\"" {
                inString = true
            } else if char == open {
                depth += 1
            } else if char == close {
                depth -= 1
                if depth == 0 {
                    let fragment = String(text[start...index])
                    if let obj = decodeJSON(fragment) {
                        return (obj, text.index(after: index))
                    }
                    return nil
                }
            }
            index = text.index(after: index)
        }
        return nil
    }

    private static let dexKeys = ["Pokédex #", "Pokedex #", "Pokédex", "Pokedex", "pokedex", "dex"]
    private static let ownedKeys = ["Owned", "owned"]
    private static let idKeys = ["id", "page_id", "pageId"]
    private static let urlKeys = ["url", "URL", "page_url", "pageUrl"]

    private static func dexNumber(from record: [String: Any]) -> Int? {
        for key in dexKeys {
            if let number = intValue(record[key]) { return number }
        }
        return nil
    }

    private static func ownedValue(from record: [String: Any]) -> Bool? {
        for key in ownedKeys {
            if let value = record[key] { return isOwnedFlag(value) }
        }
        return nil
    }

    private static func pageId(from record: [String: Any]) -> String? {
        for key in idKeys {
            if let string = record[key] as? String, looksLikeNotionId(string) {
                return string
            }
        }
        for key in urlKeys {
            if let string = record[key] as? String, let id = notionId(fromURL: string) {
                return id
            }
        }
        return nil
    }

    private static func intValue(_ value: Any?) -> Int? {
        switch value {
        case let int as Int: return int
        case let double as Double: return Int(double)
        case let string as String:
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if let int = Int(trimmed) { return int }
            if let double = Double(trimmed) { return Int(double) }
            return nil
        default: return nil
        }
    }

    private static func isOwnedFlag(_ value: Any) -> Bool {
        switch value {
        case let flag as Bool: return flag
        case let int as Int: return int != 0
        case let string as String:
            let normalized = string.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            return normalized == "__YES__" || normalized == "YES" || normalized == "TRUE" || normalized == "1"
        default: return false
        }
    }

    private static func looksLikeNotionId(_ string: String) -> Bool {
        let compact = string.replacingOccurrences(of: "-", with: "")
        return compact.range(of: #"^[0-9a-fA-F]{32}$"#, options: .regularExpression) != nil
    }

    static func notionId(fromURL url: String) -> String? {
        let pattern = try! NSRegularExpression(pattern: #"[0-9a-fA-F]{32}"#)
        let ns = url.components(separatedBy: "?").first.map { $0 as NSString } ?? (url as NSString)
        let matches = pattern.matches(in: ns as String, range: NSRange(location: 0, length: ns.length))
        guard let last = matches.last else { return nil }
        return ns.substring(with: last.range)
    }

    private static func parseMarkdownTable(
        _ text: String,
        ownership: inout [Int: Bool],
        pageIds: inout [Int: String]
    ) {
        let lines = text.components(separatedBy: .newlines)
        guard let headerIndex = lines.firstIndex(where: { line in
            let lower = line.lowercased()
            return lower.contains("pokédex") || lower.contains("pokedex")
        }) else { return }

        let headers = tableCells(lines[headerIndex])
        func column(_ names: [String]) -> Int? {
            headers.firstIndex { header in
                let lower = header.lowercased()
                return names.contains { lower == $0 || lower.contains($0) }
            }
        }
        let dexColumn = column(["pokédex #", "pokedex #", "pokédex", "pokedex", "dex"])
        let ownedColumn = column(["owned"])
        let idColumn = column(["id", "page_id", "page id"])
        let urlColumn = column(["url", "page_url", "page url"])
        guard let dexColumn else { return }

        for line in lines.dropFirst(headerIndex + 1) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { break }
            if trimmed.allSatisfy({ $0 == "|" || $0 == "-" || $0 == " " || $0 == ":" }) { continue }
            let cells = tableCells(line)
            guard dexColumn < cells.count, let dex = Int(cells[dexColumn].trimmingCharacters(in: .whitespaces)) else {
                continue
            }
            if let ownedColumn, ownedColumn < cells.count {
                ownership[dex] = isOwnedFlag(cells[ownedColumn])
            }
            if let idColumn, idColumn < cells.count, looksLikeNotionId(cells[idColumn]) {
                pageIds[dex] = cells[idColumn].trimmingCharacters(in: .whitespaces)
            } else if let urlColumn, urlColumn < cells.count, let id = notionId(fromURL: cells[urlColumn]) {
                pageIds[dex] = id
            } else if let id = notionId(fromURL: line) {
                pageIds[dex] = id
            }
        }
    }

    private static func tableCells(_ line: String) -> [String] {
        var cells = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        if cells.first?.trimmingCharacters(in: .whitespaces).isEmpty == true { cells.removeFirst() }
        if cells.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { cells.removeLast() }
        return cells.map { $0.trimmingCharacters(in: .whitespaces) }
    }
}
