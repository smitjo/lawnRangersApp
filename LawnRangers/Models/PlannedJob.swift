import Foundation
import SwiftData

/// A lawn the owner has planned to mow. Created from the Planning tab and
/// surfaced on the Lawns tab to log when done. Stored locally via SwiftData, so
/// it's instant, offline-proof, and reactive across tabs (no backend needed).
@Model
final class PlannedJob {
    var customer: String
    /// Planned date + time of day.
    var scheduledDate: Date
    /// Free-form extra info for the plan (gate code, where to start, etc.).
    var notes: String
    var createdAt: Date

    init(customer: String, scheduledDate: Date = .now, notes: String = "", createdAt: Date = .now) {
        self.customer = customer
        self.scheduledDate = scheduledDate
        self.notes = notes
        self.createdAt = createdAt
    }
}
