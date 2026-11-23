import Foundation
import Observation

enum DetailTab: CaseIterable, Identifiable {
    case stats, calendar, reasons
    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .stats: "Stats"
        case .calendar: "Calendar"
        case .reasons: "Reasons"
        }
    }
}

@MainActor
@Observable
final class HabitDetailViewModel {
    private(set) var habit: Habit?
    private(set) var slips: [Slip] = []
    private(set) var reasons: [Reason] = []
    var tab: DetailTab = .stats
    /// The first moment of the calendar month shown.
    private(set) var month: Date
    var slipSheetOpen = false
    var urge: UrgeViewModel?
    var toast: String?
    var saveFailed = false

    let calendar: Calendar
    private let habitId: UUID
    private let store: HabitStore
    private let now: () -> Date

    init(habitId: UUID, store: HabitStore, now: @escaping () -> Date = { .now }, calendar: Calendar = .current) {
        self.habitId = habitId
        self.store = store
        self.now = now
        self.calendar = calendar
        month = calendar.dateInterval(of: .month, for: now())?.start ?? now()
        reload()
    }

    func reload() {
        habit = store.habit(id: habitId)
        slips = store.slips(habitId: habitId)
        reasons = store.reasons(habitId: habitId)
    }

    // MARK: Calendar

    private var firstMonth: Date {
        habit.flatMap { calendar.dateInterval(of: .month, for: $0.trackingSince)?.start } ?? month
    }

    private var currentMonth: Date { calendar.dateInterval(of: .month, for: now())?.start ?? month }

    var canGoBack: Bool { month > firstMonth }
    var canGoForward: Bool { month < currentMonth }

    func showPreviousMonth() {
        guard canGoBack, let previous = calendar.date(byAdding: .month, value: -1, to: month) else { return }
        month = previous
    }

    func showNextMonth() {
        guard canGoForward, let next = calendar.date(byAdding: .month, value: 1, to: month) else { return }
        month = next
    }

    func days(at date: Date) -> [CalendarDay?] {
        guard let habit else { return [] }
        return calendarMonth(month, trackingSince: habit.trackingSince, slips: slips, now: date, calendar: calendar)
    }

    // MARK: Reasons

    /// Adds a reason; blank text is ignored and long text is cut to `Reason.maxLength`.
    func addReason(_ text: String) {
        guard let clean = Self.clean(text) else { return }
        save { try store.addReason(habitId: habitId, text: clean, at: now()) }
    }

    /// Saves the new text, or deletes the reason if the text was cleared.
    func updateReason(id: UUID, text: String) {
        if let clean = Self.clean(text) {
            save { try store.updateReason(id: id, text: clean) }
        } else {
            deleteReason(id: id)
        }
    }

    func deleteReason(id: UUID) {
        save { try store.deleteReason(id: id) }
    }

    nonisolated static func clean(_ text: String) -> String? {
        let trimmed = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Reason.maxLength))
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Deletes the habit with its history. The view closes once `habit` is nil.
    func deleteHabit() {
        save { try store.delete(id: habitId) }
    }

    // MARK: Urge and slip

    func urgeTapped() {
        urge = UrgeViewModel(habitId: habitId, store: store, now: now) { [weak self] count in
            self?.urge = nil
            self?.toast = String(localized: "Urge logged and outlasted. That is \(count) this month.")
        }
    }

    func confirmSlip(trigger: SlipTrigger?) {
        slipSheetOpen = false
        do {
            guard let updated = try store.logSlip(habitId: habitId, at: now(), trigger: trigger) else { return }
            reload()
            toast = updated.bestSeconds >= HomeViewModel.notableStreak
                ? String(localized: "Counter reset. Longest streak of \(HomeViewModel.streakLength(updated.bestSeconds)) is kept.")
                : String(localized: "Counter reset.")
        } catch {
            saveFailed = true
        }
    }

    private func save(_ change: () throws -> Void) {
        do {
            try change()
            reload()
        } catch {
            saveFailed = true
        }
    }
}
