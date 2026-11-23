import Foundation

/// A trophy notification: the streak reaches `days` and the user hears about it `at`.
struct MilestoneAlert: Equatable {
    let days: Int
    let at: Date
}

/// No notifications from 22:00 until 08:00.
enum QuietHours {
    static let startHour = 22
    static let endHour = 8

    /// Moves a time inside quiet hours to the next 08:00.
    static func shift(_ date: Date, calendar: Calendar) -> Date {
        let hour = calendar.component(.hour, from: date)
        let day: Date
        switch hour {
        case ..<endHour: day = date
        case startHour...: day = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        default: return date
        }
        return calendar.date(bySettingHour: endHour, minute: 0, second: 0, of: day) ?? date
    }
}

extension HabitProgress {
    /// The first trophy after this many seconds of streak.
    static func nextMilestoneDays(afterSeconds elapsed: Int) -> Int {
        let days = elapsed / 86_400
        return milestoneDays.first { $0 > days } ?? (days / 365 + 1) * 365
    }

    /// True when the duration is a whole number of years, so it reads better as years.
    static func isWholeYears(_ days: Int) -> Bool { days >= 365 && days % 365 == 0 }
}

extension Habit {
    /// The next `count` trophy notifications for the current streak, all after `now`.
    func milestoneAlerts(now: Date, calendar: Calendar, count: Int) -> [MilestoneAlert] {
        // A milestone reached at night is still due at 08:00, so start looking far enough back to catch it.
        let quietSeconds = (24 - QuietHours.startHour + QuietHours.endHour) * 3_600
        var elapsed = max(0, Int(now.timeIntervalSince(lastDoneAt)) - quietSeconds)
        var alerts: [MilestoneAlert] = []
        while alerts.count < count {
            let days = HabitProgress.nextMilestoneDays(afterSeconds: elapsed)
            let at = QuietHours.shift(lastDoneAt.addingTimeInterval(TimeInterval(days * 86_400)), calendar: calendar)
            if at > now { alerts.append(MilestoneAlert(days: days, at: at)) }
            elapsed = days * 86_400
        }
        return alerts
    }
}
