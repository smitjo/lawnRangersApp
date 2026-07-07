import Foundation

/// A single "Log a Lawn" entry — mirrors the "Lawn Mowing Wizard - 2025 Daily Log"
/// Google Form. Field order matches the sheet columns A–G; the timestamp is
/// captured automatically at save time (column A). Columns H onward in the sheet
/// (Rate, per-person splits, Overhead, Depreciation) are spreadsheet formulas,
/// not inputs, so they are not part of this model.
///
/// Not persisted on the device — this only shapes the JSON posted to the sheet,
/// which is the single source of truth.
struct LawnLog {
    /// Column A — Timestamp (auto).
    var timestamp: Date
    /// Column B — "Where?" (customer / location).
    var whereLocation: String
    /// Column C — "Who?" (team members; stored individually, joined for the sheet).
    var who: [String]
    /// Column D — "How much? Enter 'Standard' or the actual rate."
    var howMuch: String
    /// Column E — "Customer paid?" ("Paid" / "Unpaid").
    var customerPaid: String
    /// Column F — "Teammember paid?" ("Paid" / "Unpaid").
    var teammemberPaid: String
    /// Column G — "Note. Include Address & Phone for new customers" (optional).
    var note: String

    init(
        timestamp: Date = .now,
        whereLocation: String = "",
        who: [String] = [],
        howMuch: String = "",
        customerPaid: String = "",
        teammemberPaid: String = "",
        note: String = ""
    ) {
        self.timestamp = timestamp
        self.whereLocation = whereLocation
        self.who = who
        self.howMuch = howMuch
        self.customerPaid = customerPaid
        self.teammemberPaid = teammemberPaid
        self.note = note
    }

    /// JSON payload for the Google Sheets backend. Keys are appended in
    /// column order (A–G) by the Apps Script web app.
    func sheetPayload() -> [String: Any] {
        [
            "type": "lawn",
            "timestamp": ISO8601DateFormatter().string(from: timestamp),
            "where": whereLocation,
            "who": who.joined(separator: ", "),
            "howMuch": howMuch,
            "customerPaid": customerPaid,
            "teammemberPaid": teammemberPaid,
            "note": note,
        ]
    }
}
