import Foundation
import Observation

@MainActor
@Observable
final class InsightsViewModel {
    private(set) var habits: [Habit] = []
    /// The habit the user picked; nil means the newest one. Shared with the other tab.
    var selectedId: UUID? { selection.habitId }
    private let selection: HabitSelection
    private(set) var slips: [Slip] = []
    private(set) var urgeStarts: [Date] = []

    let calendar: Calendar
    private let store: HabitStore

    init(store: HabitStore, selection: HabitSelection = HabitSelection(), calendar: Calendar = .current) {
        self.store = store
        self.selection = selection
        self.calendar = calendar
        reload()
    }

    var selected: Habit? {
        habits.first { $0.id == selectedId } ?? habits.last
    }

    func reload() {
        habits = store.allHabits()
        guard let habit = selected else {
            slips = []
            urgeStarts = []
            return
        }
        slips = store.slips(habitId: habit.id)
        urgeStarts = store.urgeStarts(habitId: habit.id)
    }

    func select(_ id: UUID) {
        selection.habitId = id
        reload()
    }

    var hardestTimes: HardestTimes {
        HardestTimes(slips: slips.map(\.at), urges: urgeStarts, calendar: calendar)
    }

    /// Newest first, as of `date`.
    func streakRows(at date: Date) -> [StreakRow] {
        guard let habit = selected else { return [] }
        return StreakHistory.rows(habit.streaks(slips: slips, now: date))
    }

    /// "Evening: 5 slips, 2 urges".
    nonisolated static func spoken(_ label: String, _ count: EventCount, locale: Locale = .current) -> String {
        let slips = String(localized: LocalizedStringResource("\(count.slips) slips", locale: locale))
        let urges = String(localized: LocalizedStringResource("\(count.urges) urges", locale: locale))
        return String(localized: LocalizedStringResource("\(label): \(slips), \(urges)", locale: locale))
    }
}
