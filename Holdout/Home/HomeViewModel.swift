import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {
    private(set) var habits: [Habit] = []
    /// The selected habit's personal goals, part of its trophy ladder.
    private(set) var personalGoals: [PersonalGoal] = []
    /// The habit the user picked; nil means "the newest one".
    private(set) var selectedId: UUID?
    /// The habit whose "Log a slip" sheet is open.
    var slipSheetHabit: Habit?
    /// A short confirmation shown at the bottom, then cleared by the view.
    var toast: String?
    /// Saving a slip failed; the view shows an alert.
    var slipFailed = false

    /// What the home links to. Set by whoever owns navigation.
    struct Actions {
        var addHabit: () -> Void = {}
        var openDetail: (UUID) -> Void = { _ in }
        var checkIn: () -> Void = {}
        var settings: () -> Void = {}
    }

    let actions: Actions
    private let store: HabitStore
    private let now: () -> Date

    init(store: HabitStore, now: @escaping () -> Date = { .now }, actions: Actions = Actions()) {
        self.store = store
        self.now = now
        self.actions = actions
        reload()
    }

    var selected: Habit? {
        habits.first { $0.id == selectedId } ?? habits.last
    }

    /// Reads habits again, e.g. after one was added.
    func reload() {
        habits = store.allHabits()
        personalGoals = selected.map { store.personalGoals(habitId: $0.id) } ?? []
    }

    func select(_ id: UUID) {
        selectedId = id
        reload()
    }

    func logSlipTapped() {
        slipSheetHabit = selected
    }

    /// Restarts the habit's counter from now. Its longest streak and money kept stay.
    func confirmSlip(trigger: SlipTrigger?) {
        guard let habit = slipSheetHabit else { return }
        slipSheetHabit = nil
        do {
            guard let updated = try store.logSlip(habitId: habit.id, at: now(), trigger: trigger) else { return }
            reload()
            toast = updated.bestSeconds >= Self.notableStreak
                ? String(localized: "Counter reset. Longest streak of \(Self.streakLength(updated.bestSeconds)) is kept.")
                : String(localized: "Counter reset.")
        } catch {
            slipFailed = true
        }
    }

    /// A streak under a minute is too short to call a record.
    nonisolated static let notableStreak = 60

    /// "18 days", "5 hours" or "12 minutes": the largest whole unit.
    nonisolated static func streakLength(_ seconds: Int) -> String {
        let (value, unit): (Int, Duration.UnitsFormatStyle.Unit) =
            seconds >= 86_400 ? (seconds / 86_400 * 86_400, .days)
            : seconds >= 3_600 ? (seconds / 3_600 * 3_600, .hours)
            : (seconds / 60 * 60, .minutes)
        // Truncated first, so 1.9 days reads "1 day", never rounded up.
        return Duration.seconds(value).formatted(.units(allowed: [unit], width: .wide))
    }
}
