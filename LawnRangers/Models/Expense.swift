import Foundation
import SwiftData

/// A single "Log an Expense" entry — mirrors the "Overhead Expense" Google Form.
/// The timestamp is captured automatically at save time.
@Model
final class Expense {
    /// Timestamp (auto).
    var timestamp: Date
    /// "Expenses" — what was purchased (required).
    var expenses: String
    /// "Amount" (required). Stored as free text to match the form's short-answer field.
    var amount: String
    /// "Comment" (optional).
    var comment: String

    init(
        timestamp: Date = .now,
        expenses: String = "",
        amount: String = "",
        comment: String = ""
    ) {
        self.timestamp = timestamp
        self.expenses = expenses
        self.amount = amount
        self.comment = comment
    }

    /// JSON payload for the Google Sheets backend.
    func sheetPayload() -> [String: Any] {
        [
            "type": "expense",
            "timestamp": ISO8601DateFormatter().string(from: timestamp),
            "expenses": expenses,
            "amount": amount,
            "comment": comment,
        ]
    }
}
