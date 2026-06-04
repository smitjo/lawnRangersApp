import Foundation

/// A lawn entry as read back from the "Lawn Log" sheet (for displaying the
/// current state of the sheet on the Home screen).
struct SheetLawn: Decodable {
    let date: String?
    let whereLocation: String?
    let who: String?
    let howMuch: String?
    let customerPaid: String?
    let teammemberPaid: String?
    let note: String?

    enum CodingKeys: String, CodingKey {
        case date
        case whereLocation = "where"
        case who, howMuch, customerPaid, teammemberPaid, note
    }
}

/// An expense as read back from the "Overhead Expense" sheet.
struct SheetExpense: Decodable {
    let date: String?
    let expenses: String?
    let amount: String?
    let comment: String?
}

struct EntriesResponse: Decodable {
    let lawns: [SheetLawn]
    let expenses: [SheetExpense]
    let error: String?
}
