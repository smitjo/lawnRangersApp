import Foundation
import SwiftData

/// A single "Log an Expense" entry.
///
/// NOTE: These fields are a best-guess placeholder for a business expense log.
/// They will be replaced to exactly match the source Google Form once its
/// field list is available.
@Model
final class Expense {
    var date: Date
    var category: String
    var vendor: String
    var amount: Double
    var paymentMethod: String
    var notes: String

    init(
        date: Date = .now,
        category: String = "",
        vendor: String = "",
        amount: Double = 0,
        paymentMethod: String = "",
        notes: String = ""
    ) {
        self.date = date
        self.category = category
        self.vendor = vendor
        self.amount = amount
        self.paymentMethod = paymentMethod
        self.notes = notes
    }
}
