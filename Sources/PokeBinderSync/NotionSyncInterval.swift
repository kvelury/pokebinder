import Foundation

/// How often PokéBinder pulls Notion and flushes queued local edits.
///
/// `manual` never schedules a timer; the always-visible resync control still
/// runs the same two-way sync on demand. Custom values are whole minutes.
public enum NotionSyncInterval: String, CaseIterable, Identifiable, Sendable {
    case manual
    case oneMinute
    case threeMinutes
    case fiveMinutes
    case eightMinutes
    case custom

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .manual: "Manual"
        case .oneMinute: "1 min"
        case .threeMinutes: "3 min"
        case .fiveMinutes: "5 min"
        case .eightMinutes: "8 min"
        case .custom: "Custom"
        }
    }

    /// Compact segmented-picker labels so the six options fit the Settings form.
    public var shortTitle: String {
        switch self {
        case .manual: "Manual"
        case .oneMinute: "1"
        case .threeMinutes: "3"
        case .fiveMinutes: "5"
        case .eightMinutes: "8"
        case .custom: "Custom"
        }
    }

    public static let minimumCustomMinutes = 1
    public static let maximumCustomMinutes = 24 * 60
    public static let defaultCustomMinutes = 10

    public static func sanitizedCustomMinutes(_ value: Int) -> Int {
        min(max(value, minimumCustomMinutes), maximumCustomMinutes)
    }

    /// `nil` means no automatic refresh — Manual mode.
    public func resolvedMinutes(customMinutes: Int) -> Int? {
        switch self {
        case .manual:
            return nil
        case .oneMinute:
            return 1
        case .threeMinutes:
            return 3
        case .fiveMinutes:
            return 5
        case .eightMinutes:
            return 8
        case .custom:
            return Self.sanitizedCustomMinutes(customMinutes)
        }
    }
}

public enum NotionSyncScheduling {
    /// Automatic refresh is due when an interval is selected and enough time has
    /// passed since the last successful pull. A missing `lastSyncedAt` is treated
    /// as overdue so activation after launch still catches up.
    public static func isDue(
        lastSyncedAt: Date?,
        interval: NotionSyncInterval,
        customMinutes: Int,
        now: Date = Date()
    ) -> Bool {
        guard let minutes = interval.resolvedMinutes(customMinutes: customMinutes) else {
            return false
        }
        let last = lastSyncedAt ?? .distantPast
        return now.timeIntervalSince(last) >= Double(minutes) * 60
    }
}
