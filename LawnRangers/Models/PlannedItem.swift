import Foundation

/// A planned job from the shared "Plan" tab in the Google Sheet.
struct PlannedItem: Identifiable, Decodable {
    let id: String
    let customer: String
    /// Scheduled date+time as epoch milliseconds (from the sheet).
    let scheduled: Double?
    let notes: String?

    var scheduledDate: Date {
        Date(timeIntervalSince1970: (scheduled ?? 0) / 1000)
    }
}
