import Foundation

/// Seed list of customers shown in the "Where?" dropdown on the Log a Lawn form.
///
/// Edit this list as your customer base changes. The dropdown also automatically
/// includes any customer you've previously entered in the app, plus a
/// "New customer…" option for one-off / first-time entries.
enum CustomerDirectory {
    static let seed: [String] = [
        "Adam", "Anderson", "Beverly", "Brian", "Corbit", "Eldridge",
        "Harrington", "Helen Lee", "Holland", "Hunter", "Johnson", "King",
        "Larry", "Matthews", "Nancy Patton", "Retzer", "Schreck", "Yatish",
    ].sorted()
}
