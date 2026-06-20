import Foundation

/// Pure date logic for auto-scheduling: the crew only mows on **Tuesday and
/// Thursday**, so any recommended date is snapped to the next Tue/Thu.
///
/// This is the on-device half of the auto-scheduler. The same rule is mirrored
/// server-side in `backend/Code.gs` (`?action=autoschedule`) so the app can get
/// the recommendation either locally (instant, offline) or from the sheet.
enum MowingSchedule {
    /// Weekdays the crew mows (Gregorian: Sunday = 1 … Saturday = 7).
    /// Tuesday = 3, Thursday = 5.
    static let mowingWeekdays: Set<Int> = [3, 5]

    /// Default time of day to schedule a mow (9:00 AM local).
    static let defaultHour = 9

    /// The next Tuesday or Thursday on or after `date`, at `defaultHour`.
    /// `date` itself counts if it already falls on a mowing day.
    static func nextMowingDay(onOrAfter date: Date,
                              calendar: Calendar = .current) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        for offset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfDay) else { continue }
            if mowingWeekdays.contains(calendar.component(.weekday, from: day)) {
                return calendar.date(bySettingHour: defaultHour, minute: 0, second: 0, of: day) ?? day
            }
        }
        return date   // unreachable: a Tue/Thu always falls within any 7-day window
    }

    /// The recommended next mow date for a customer: figure out when they're due
    /// from the Planning data, then snap to the next mowing day.
    ///
    /// - Overdue or due today (`dueIn <= 0`) → the next mowing day from now.
    /// - Due later (`dueIn > 0`) → the next mowing day on/after the due date.
    /// - Never mowed (`daysSinceMowed == nil`) → the next mowing day from now.
    static func recommendedDate(for customer: PlanningCustomer,
                                from today: Date = .now,
                                calendar: Calendar = .current) -> Date {
        let target: Date
        if customer.daysSinceMowed == nil {
            target = today                       // never mowed — schedule asap
        } else if let due = customer.dueIn, due > 0 {
            target = calendar.date(byAdding: .day, value: Int(due), to: today) ?? today
        } else {
            target = today                       // due today or overdue
        }
        return nextMowingDay(onOrAfter: target, calendar: calendar)
    }

    /// Customers worth auto-scheduling now: those due within `withinDays` (or
    /// already overdue, or never mowed), most overdue first.
    static func dueCustomers(_ customers: [PlanningCustomer],
                             withinDays: Double = 7) -> [PlanningCustomer] {
        customers
            .filter { c in
                guard c.daysSinceMowed != nil else { return true }   // never mowed
                guard let due = c.dueIn else { return true }
                return due <= withinDays
            }
            .sorted { ($0.dueIn ?? -9_999) < ($1.dueIn ?? -9_999) }
    }
}
