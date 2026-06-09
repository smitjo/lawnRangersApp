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

    var isActive: Bool {
        customer != nil || customerPaid != .any || teammemberPaid != .any || teamMember != nil
    }

    func matches(_ l: SheetLawn) -> Bool {
        if let c = customer, (l.whereLocation ?? "") != c { return false }
        if customerPaid != .any, (l.customerPaid ?? "") != customerPaid.rawValue { return false }
        if teammemberPaid != .any, (l.teammemberPaid ?? "") != teammemberPaid.rawValue { return false }
        if let m = teamMember, !(l.who ?? "").localizedCaseInsensitiveContains(m) { return false }
        return true
    }
}
