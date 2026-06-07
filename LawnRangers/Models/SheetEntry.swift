import Foundation

/// A lawn entry as read back from the "Lawn Log" sheet (for displaying the
/// current state of the sheet on the Home screen).
struct SheetLawn: Decodable {
    let date: String?
    /// Raw epoch milliseconds from the sheet's Timestamp column, used to sort
    /// newest→oldest in the app independently of the sheet's filter/sort state.
    let ts: Double?
    let whereLocation: String?
    let who: String?
    let howMuch: String?
    let customerPaid: String?
    let teammemberPaid: String?
    let note: String?

    enum CodingKeys: String, CodingKey {
        case date, ts
        case whereLocation = "where"
        case who, howMuch, customerPaid, teammemberPaid, note
    }
}

/// An expense as read back from the "Overhead Expense" sheet.
struct SheetExpense: Decodable {
    let date: String?
    /// Raw epoch milliseconds (see SheetLawn.ts) for newest→oldest sorting.
    let ts: Double?
    let expenses: String?
    let amount: String?
    let comment: String?
}

struct EntriesResponse: Decodable {
    let lawns: [SheetLawn]
    let expenses: [SheetExpense]
    let error: String?
}
