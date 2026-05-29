import Foundation
import SwiftData

/// A single "Log a Lawn" entry.
///
/// NOTE: These fields are a best-guess placeholder for a lawn-care service log.
/// They will be replaced to exactly match the source Google Form once its
/// field list is available.
@Model
final class LawnLog {
    var date: Date
    var customerName: String
    var address: String
    var crewMember: String
    /// Services performed (e.g. Mow, Edge, Trim, Blow/Cleanup).
    var services: [String]
    var amountCharged: Double
    var paymentMethod: String
    var notes: String

    init(
        date: Date = .now,
        customerName: String = "",
        address: String = "",
        crewMember: String = "",
        services: [String] = [],
        amountCharged: Double = 0,
        paymentMethod: String = "",
        notes: String = ""
    ) {
        self.date = date
        self.customerName = customerName
        self.address = address
        self.crewMember = crewMember
        self.services = services
        self.amountCharged = amountCharged
        self.paymentMethod = paymentMethod
        self.notes = notes
    }
}
