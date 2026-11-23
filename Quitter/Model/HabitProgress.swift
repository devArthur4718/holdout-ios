import Foundation

/// Where a habit stands at a given moment.
struct HabitProgress: Equatable {
    /// Trophy milestones in days. After a year, a trophy lands every year.
    static let milestoneDays = [1, 3, 7, 14, 30, 90, 180, 365]
    private static let secondsPerDay = 86_400

    let elapsedSeconds: Int
    /// The longest streak so far, counting the current one.
    let bestSeconds: Int
    /// True while the current streak is the longest.
    let isPersonalBest: Bool
    /// Money not spent so far, across all streaks, or nil when the habit has no daily cost.
    let moneyKept: Decimal?
    /// Whole hours not spent so far, across all streaks, or nil when the habit has no daily time.
    let hoursBack: Int?
    let nextMilestoneDays: Int
    let secondsToNextMilestone: Int
    /// 0 to 1: how far from the previous milestone to the next one.
    let milestoneFraction: Double

    init(habit: Habit, now: Date) {
        let elapsed = max(0, Int(now.timeIntervalSince(habit.lastDoneAt)))
        let days = elapsed / Self.secondsPerDay
        let next = Self.milestoneDays.first { $0 > days } ?? (days / 365 + 1) * 365
        let previous = days < 365 ? (Self.milestoneDays.last { $0 <= days } ?? 0) : days / 365 * 365
        let span = Double((next - previous) * Self.secondsPerDay)

        let clean = habit.bankedSeconds + elapsed

        elapsedSeconds = elapsed
        bestSeconds = max(habit.bestSeconds, elapsed)
        isPersonalBest = elapsed >= habit.bestSeconds
        moneyKept = habit.costPerDay.map { cost in
            var raw = cost * Decimal(clean) / Decimal(Self.secondsPerDay)
            var rounded = Decimal()
            NSDecimalRound(&rounded, &raw, 2, .plain)
            return rounded
        }
        hoursBack = habit.minutesPerDay.map { $0 * clean / Self.secondsPerDay / 60 }
        nextMilestoneDays = next
        secondsToNextMilestone = next * Self.secondsPerDay - elapsed
        milestoneFraction = min(1, max(0, Double(elapsed - previous * Self.secondsPerDay) / span))
    }
}
