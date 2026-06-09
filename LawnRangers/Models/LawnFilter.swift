import Foundation

/// Filter criteria for the Lawns list. Applies across *all* lawns, not just the
/// visible/recent ones.
struct LawnFilter: Equatable {
    enum Paid: String, CaseIterable, Identifiable {
        case any = "Any", paid = "Paid", unpaid = "Unpaid"
        var id: String { rawValue }
    }

    var customer: String?            // exact customer name; nil = all
    var customerPaid: Paid = .any
    var teammemberPaid: Paid = .any
    var teamMember: String?          // a person listed in "Who?"; nil = anyone
    var fromDate: Date?              // inclusive, date only (time ignored)
    var toDate: Date?               // inclusive, date only (time ignored)

    var isActive: Bool {
        customer != nil || customerPaid != .any || teammemberPaid != .any
            || teamMember != nil || fromDate != nil || toDate != nil
    }

    func matches(_ l: SheetLawn) -> Bool {
        if let c = customer, (l.whereLocation ?? "") != c { return false }
        if customerPaid != .any, (l.customerPaid ?? "") != customerPaid.rawValue { return false }
        if teammemberPaid != .any, (l.teammemberPaid ?? "") != teammemberPaid.rawValue { return false }
        if let m = teamMember {
            let people = (l.who ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if !people.contains(where: { $0.caseInsensitiveCompare(m) == .orderedSame }) { return false }
        }

        // Date range — compared at day granularity (time of day ignored).
        if fromDate != nil || toDate != nil {
            guard let ts = l.ts, ts > 0 else { return false }
            let cal = Calendar.current
            let day = cal.startOfDay(for: Date(timeIntervalSince1970: ts / 1000))
            if let from = fromDate, day < cal.startOfDay(for: from) { return false }
            if let to = toDate, day > cal.startOfDay(for: to) { return false }
        }
        return true
    }
}
