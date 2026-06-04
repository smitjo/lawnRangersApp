import Foundation

/// One row from the "Lawns due, 2025" sheet, read for the Planning tab.
struct PlanningCustomer: Decodable, Identifiable {
    let customer: String
    let daysSinceMowed: Double?
    let nextDate: String?
    let address: String?
    let notes: String?
    let interval: Double?
    let loop: String?
    let price: String?
    let phone: String?

    var id: String { customer + "|" + (address ?? "") }
}

struct PlanningResponse: Decodable {
    let planning: [PlanningCustomer]
    let error: String?
}
