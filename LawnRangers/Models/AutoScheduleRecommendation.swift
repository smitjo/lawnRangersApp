import Foundation

/// A server-computed auto-schedule suggestion from the Google Sheet backend
/// (`?action=autoschedule`). The backend applies the same Tue/Thu-only rule the
/// app uses on-device, so the two paths agree.
struct AutoScheduleRecommendation: Decodable, Identifiable {
    let customer: String
    /// Recommended next mow (epoch milliseconds), already snapped to a Tue/Thu.
    let recommended: Double?
    let dueIn: Double?
    let daysSinceMowed: Double?

    var id: String { customer }

    var recommendedDate: Date? {
        guard let ms = recommended else { return nil }
        return Date(timeIntervalSince1970: ms / 1000)
    }
}

struct AutoScheduleResponse: Decodable {
    let autoschedule: [AutoScheduleRecommendation]
    let error: String?
}
