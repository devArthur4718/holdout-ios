import Foundation

/// Where a habit stands at a given moment.
struct HabitProgress: Equatable {
    private static let secondsPerDay = Goals.secondsPerDay

    let elapsedSeconds: Int
    /// The longest streak so far, counting the current one.
    let bestSeconds: Int
    /// True while the current streak is the longest.
    let isPersonalBest: Bool
    /// Money not spent so far, across all streaks, or nil when the habit has no daily cost.
    let moneyKept: Decimal?
    /// Whole hours not spent so far, across all streaks, or nil when the habit has no daily time.
    let hoursBack: Int?
    /// The current goal: the next trophy, in days.
    let nextMilestoneDays: Int
    /// The last goal reached, in days, or 0.
    let previousMilestoneDays: Int
    let secondsToNextMilestone: Int
    /// 0 to 1: how much of the current goal is done, counted from the quit moment.
    let goalFraction: Double
    /// The habit's personal goals, part of the ladder above.
    let personalGoals: [PersonalGoal]

    /// The next goal's name: a personal goal's own name, or its day label.
    var nextGoalLabel: String { Goals.label(days: nextMilestoneDays, personal: personalGoals) }

    init(habit: Habit, now: Date, personalGoals: [PersonalGoal] = []) {
        let elapsed = max(0, Int(now.timeIntervalSince(habit.lastDoneAt)))
        let days = elapsed / Self.secondsPerDay
        let next = Goals.next(afterDays: days, personal: personalGoals)

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
        previousMilestoneDays = Goals.previous(atDays: days, personal: personalGoals)
        secondsToNextMilestone = next * Self.secondsPerDay - elapsed
        goalFraction = Goals.fraction(elapsedSeconds: elapsed, personal: personalGoals)
        self.personalGoals = personalGoals
    }
}
