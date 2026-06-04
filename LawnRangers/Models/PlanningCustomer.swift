import Foundation

/// One row from the app's "Planning" sheet.
struct PlanningCustomer: Decodable, Identifiable {
    let customer: String
    let interval: Double?        // mow every N days
    let lastMowed: String?       // formatted date, or "" if never mowed
    let daysSinceMowed: Double?  // nil if never mowed
    let dueIn: Double?           // interval − daysSinceMowed (negative = overdue)

    var id: String { customer }
}

struct PlanningResponse: Decodable {
    let planning: [PlanningCustomer]
    let error: String?
}
