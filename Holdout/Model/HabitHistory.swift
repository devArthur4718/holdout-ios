import Foundation

enum DayState: Equatable {
    /// Before tracking began.
    case untracked, clean, slip, future
}

struct CalendarDay: Equatable, Identifiable {
    let date: Date
    let day: Int
    let state: DayState
    let isToday: Bool
    var id: Date { date }
}

/// The days of the month containing `month`, with nils first so day 1 lands under its weekday.
/// A day with any slip is a slip day; a tracked day without one is clean.
func calendarMonth(
    _ month: Date,
    trackingSince: Date,
    slips: [Slip],
    now: Date,
    calendar: Calendar
) -> [CalendarDay?] {
    guard let interval = calendar.dateInterval(of: .month, for: month),
          let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
    let today = calendar.startOfDay(for: now)
    let firstTracked = calendar.startOfDay(for: trackingSince)
    let slipDays = Set(slips.map { calendar.startOfDay(for: $0.at) })
    let leading = (calendar.component(.weekday, from: interval.start) - calendar.firstWeekday + 7) % 7
    let days: [CalendarDay?] = range.compactMap { day in
        guard let date = calendar.date(byAdding: .day, value: day - 1, to: interval.start) else { return nil }
        let state: DayState =
            date > today ? .future
            : date < firstTracked ? .untracked
            : slipDays.contains(date) ? .slip
            : .clean
        return CalendarDay(date: date, day: day, state: state, isToday: date == today)
    }
    return Array(repeating: nil, count: leading) + days
}

struct MonthSavings: Equatable {
    /// The first moment of the month.
    let month: Date
    let total: Decimal
}

extension Habit {
    /// Money kept in total by the end of each of the last `count` months (the current month up
    /// to `now`), oldest first. Months before tracking began are left out. Empty without a cost.
    func savingsByMonth(now: Date, calendar: Calendar, count: Int = 6) -> [MonthSavings] {
        guard let cost = costPerDay,
              let current = calendar.dateInterval(of: .month, for: now)?.start,
              let tracked = calendar.dateInterval(of: .month, for: trackingSince)?.start,
              let earliest = calendar.date(byAdding: .month, value: -(count - 1), to: current) else { return [] }
        var month = max(tracked, earliest)
        var result: [MonthSavings] = []
        while month <= current {
            guard let next = calendar.date(byAdding: .month, value: 1, to: month) else { break }
            let seconds = max(0, Int(min(next, now).timeIntervalSince(trackingSince)))
            var raw = cost * Decimal(seconds) / 86_400
            var rounded = Decimal()
            NSDecimalRound(&rounded, &raw, 2, .plain)
            result.append(MonthSavings(month: month, total: rounded))
            month = next
        }
        return result
    }
}
