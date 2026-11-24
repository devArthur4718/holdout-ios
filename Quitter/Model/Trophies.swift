import Foundation

/// One run without the habit: from the start of tracking or a slip, to the next slip or now.
struct Streak: Equatable {
    let start: Date
    /// nil for the current streak, which is still running.
    let end: Date?
    let seconds: Int

    var isCurrent: Bool { end == nil }
}

extension Habit {
    /// Every streak, oldest first; the last one is the current streak.
    func streaks(slips: [Slip], now: Date) -> [Streak] {
        var result: [Streak] = []
        var start = trackingSince
        for slip in slips.sorted(by: { $0.at < $1.at }) {
            result.append(Streak(start: start, end: slip.at, seconds: max(0, Int(slip.at.timeIntervalSince(start)))))
            start = max(start, slip.at)
        }
        result.append(Streak(start: lastDoneAt, end: nil, seconds: max(0, Int(now.timeIntervalSince(lastDoneAt)))))
        return result
    }
}

/// A trophy as the Trophies tab shows it.
struct TrophyItem: Equatable, Identifiable {
    let days: Int
    /// Set for a personal goal.
    let personal: PersonalGoal?
    /// When it was first reached, in whichever streak reached it first; nil when never reached.
    let earnedAt: Date?
    /// The goal the current streak is heading for, as on the arc. It may already be earned from an
    /// earlier streak; then it is shown earned and marked Next.
    let isNext: Bool

    var id: Int { days }
    var isEarned: Bool { earnedAt != nil }
}

enum Trophies {
    /// Standard and personal trophies in day order. A trophy is earned when any streak, past or
    /// current, lasted its days. The standard ladder stops at the first yearly trophy beyond both
    /// the best streak and the next goal; personal goals are always listed.
    static func list(streaks: [Streak], personal: [PersonalGoal]) -> [TrophyItem] {
        let day = Goals.secondsPerDay
        let currentDays = (streaks.last?.seconds ?? 0) / day
        let bestDays = (streaks.map(\.seconds).max() ?? 0) / day
        let next = Goals.next(afterDays: currentDays, personal: personal)
        let limit = (max(bestDays, next) / 365 + 1) * 365

        var standard = Goals.ladder.filter { $0 <= limit }
        var yearly = Goals.ladder[Goals.ladder.count - 1] + 365
        while yearly <= limit {
            standard.append(yearly)
            yearly += 365
        }

        let goals = standard.map { ($0, PersonalGoal?.none) } + personal.map { ($0.days, Optional($0)) }
        return goals.sorted { $0.0 < $1.0 }.map { days, goal in
            let reached = streaks.first { $0.seconds >= days * day }
            let earnedAt = reached.map { $0.start.addingTimeInterval(TimeInterval(days * day)) }
            return TrophyItem(days: days, personal: goal, earnedAt: earnedAt, isNext: days == next)
        }
    }
}

/// A row of the streak history.
struct StreakRow: Equatable {
    let streak: Streak
    /// The longest streak, marked once there are two or more. A tie goes to the most recent.
    let isBest: Bool
}

enum StreakHistory {
    /// Newest first, so the current streak is on top.
    static func rows(_ streaks: [Streak]) -> [StreakRow] {
        let newestFirst = Array(streaks.reversed())
        let best = newestFirst.count > 1 ? newestFirst.indices.max { a, b in
            // On equal length the lower index (the newer streak) counts as larger, so it wins.
            newestFirst[a].seconds < newestFirst[b].seconds || (newestFirst[a].seconds == newestFirst[b].seconds && a > b)
        } : nil
        return newestFirst.enumerated().map { StreakRow(streak: $1, isBest: $0 == best) }
    }
}
