import SwiftUI

/// The app's authored motion scale. System-owned transitions, such as sheets and
/// interactive glass feedback, continue to use the platform's native timing.
enum AppMotion {
    /// Pointer and control-state feedback.
    static let quick = Animation.easeOut(duration: 0.08)
    /// Search, ownership, and content-reveal feedback.
    static let feedback = Animation.easeOut(duration: 0.12)
    /// Pocket-to-detail presentation and dismissal.
    static let cardDetail = Animation.spring(response: 0.20, dampingFraction: 0.88)

    static let pageTurnDuration: TimeInterval = 0.28
    static let pageTurnMinimumDuration: TimeInterval = 0.08
    static let pageTurnSnapBack = Animation.spring(response: 0.24, dampingFraction: 0.88)

    static func respectingReduceMotion(
        _ animation: Animation,
        reduceMotion: Bool
    ) -> Animation? {
        reduceMotion ? nil : animation
    }
}
