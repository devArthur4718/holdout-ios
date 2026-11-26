import Foundation
import Observation

/// The form for adding or changing a personal goal.
struct PersonalGoalForm: Identifiable, Equatable {
    /// The goal being edited; nil for a new one.
    let editing: PersonalGoal?
    var daysText: String
    var name: String
    /// Shown under the Days field after a failed Save.
    var problem: PersonalGoal.Problem?

    var id: String { editing?.id.uuidString ?? "new" }
}

@MainActor
@Observable
final class TrophiesViewModel {
    private(set) var habits: [Habit] = []
    /// The habit the user picked; nil means the newest one. Shared with the other tab.
    var selectedId: UUID? { selection.habitId }
    private let selection: HabitSelection
    private(set) var slips: [Slip] = []
    private(set) var personalGoals: [PersonalGoal] = []
    /// The open add/edit sheet.
    var form: PersonalGoalForm?
    var saveFailed = false

    private let store: HabitStore
    private let now: () -> Date

    init(store: HabitStore, selection: HabitSelection = HabitSelection(), now: @escaping () -> Date = { .now }) {
        self.store = store
        self.selection = selection
        self.now = now
        reload()
    }

    var selected: Habit? {
        habits.first { $0.id == selectedId } ?? habits.last
    }

    func reload() {
        habits = store.allHabits()
        guard let habit = selected else {
            slips = []
            personalGoals = []
            return
        }
        slips = store.slips(habitId: habit.id)
        personalGoals = store.personalGoals(habitId: habit.id)
    }

    func select(_ id: UUID) {
        selection.habitId = id
        reload()
    }

    /// The grid, as of `date`.
    func trophies(at date: Date) -> [TrophyItem] {
        guard let habit = selected else { return [] }
        return Trophies.list(streaks: habit.streaks(slips: slips, now: date), personal: personalGoals)
    }

    // MARK: Personal goals

    func addGoalTapped() {
        form = PersonalGoalForm(editing: nil, daysText: "", name: "")
    }

    func goalTapped(_ goal: PersonalGoal) {
        form = PersonalGoalForm(editing: goal, daysText: String(goal.days), name: goal.name ?? "")
    }

    /// Saves the form, or keeps it open with the problem to show.
    func saveForm() {
        guard var form, let habit = selected else { return }
        switch PersonalGoal.validate(daysText: form.daysText, existing: personalGoals, editing: form.editing?.id) {
        case .failure(let problem):
            form.problem = problem
            self.form = form
        case .success(let days):
            let name = PersonalGoal.cleanName(form.name)
            do {
                if let goal = form.editing {
                    try store.updatePersonalGoal(id: goal.id, days: days, name: name)
                } else {
                    try store.addPersonalGoal(habitId: habit.id, days: days, name: name, at: now())
                }
                self.form = nil
                reload()
            } catch {
                saveFailed = true
            }
        }
    }

    func deleteGoal(_ goal: PersonalGoal) {
        do {
            try store.deletePersonalGoal(id: goal.id)
            form = nil
            reload()
        } catch {
            saveFailed = true
        }
    }

    /// The message for a problem, e.g. "There's already a trophy at 30 days."
    nonisolated static func message(for problem: PersonalGoal.Problem, locale: Locale = .current) -> String {
        switch problem {
        case .daysOutOfRange:
            let most = ArcText.grouped(PersonalGoal.maxDays, locale: locale)
            return String(localized: LocalizedStringResource("Enter a number of days from 1 to \(most).", locale: locale))
        case .duplicate(let days):
            let label = Goals.label(days: days, locale: locale)
            return String(localized: LocalizedStringResource("There's already a trophy at \(label).", locale: locale))
        }
    }

    /// What VoiceOver says for a badge, e.g. "Personal goal: Beach trip, 45 days, not earned yet".
    nonisolated static func spoken(_ item: TrophyItem, locale: Locale = .current) -> String {
        let days = Goals.label(days: item.days, locale: locale)
        var label = days
        if let goal = item.personal {
            let name = goal.name.map { "\($0), \(days)" } ?? days
            label = String(localized: LocalizedStringResource("Personal goal: \(name)", locale: locale))
        }
        let state = if let earned = item.earnedAt {
            String(localized: LocalizedStringResource("\(label), earned \(earned.formatted(Date.FormatStyle(date: .long, time: .omitted).locale(locale)))", locale: locale))
        } else {
            String(localized: LocalizedStringResource("\(label), not earned yet", locale: locale))
        }
        return item.isNext ? "\(state). \(String(localized: LocalizedStringResource("Next", locale: locale)))" : state
    }
}
