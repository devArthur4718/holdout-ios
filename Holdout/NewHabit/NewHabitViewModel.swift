import Foundation
import Observation

@MainActor
@Observable
final class NewHabitViewModel {
    static let maxMinutesPerDay = 24 * 60

    private(set) var kind: HabitKind = .smoking
    private(set) var name: String = HabitKind.smoking.defaultName
    /// nil means "just now": the moment the user taps Start.
    private(set) var lastDoneAt: Date?
    private(set) var costText = ""
    private(set) var minutesText = ""

    /// Set when saving failed, so the view can say so.
    var saveFailed = false

    private let store: HabitStore
    private let now: () -> Date
    private let onStarted: (UUID) -> Void
    /// The habit being edited, or nil when creating one.
    private let editingId: UUID?

    /// Editing a saved habit: when it was last done can't change, and the button says Save.
    var isEditing: Bool { editingId != nil }

    init(
        store: HabitStore,
        now: @escaping () -> Date = Date.init,
        editingId: UUID? = nil,
        onStarted: @escaping (UUID) -> Void = { _ in }
    ) {
        self.store = store
        self.now = now
        self.editingId = editingId
        self.onStarted = onStarted
        if let editingId, let habit = store.habit(id: editingId) {
            kind = habit.kind
            name = habit.name
            lastDoneAt = habit.lastDoneAt
            costText = habit.costPerDay.map { "\($0)" } ?? ""
            minutesText = habit.minutesPerDay.map(String.init) ?? ""
        }
    }

    // MARK: Derived state

    var costPerDay: Decimal? {
        Decimal(string: costText.replacingOccurrences(of: ",", with: "."), locale: Locale(identifier: "en_US_POSIX"))
    }

    var minutesPerDay: Int? { Int(minutesText) }

    var minutesTooHigh: Bool { (minutesPerDay ?? 0) > Self.maxMinutesPerDay }

    var canStart: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !minutesTooHigh
    }

    /// Money kept in a year at this rate, or nil when no cost is entered.
    var yearlyCost: Decimal? {
        guard let cost = costPerDay, cost > 0 else { return nil }
        return cost * 365
    }

    /// Whole hours back in a year, or nil when no time is entered.
    var yearlyHours: Int? {
        guard let minutes = minutesPerDay, minutes > 0, !minutesTooHigh else { return nil }
        return minutes * 365 / 60
    }

    /// The date the picker shows; "just now" shows the current time.
    var lastDoneDisplay: Date { lastDoneAt ?? now() }

    // MARK: Intents

    func selectKind(_ newKind: HabitKind) {
        // Keep a name the user typed; replace an empty or default one.
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || name == kind.defaultName {
            name = newKind.defaultName
        }
        kind = newKind
    }

    func updateName(_ text: String) { name = text }

    /// Accepts digits with one decimal separator and up to two decimals.
    func updateCost(_ text: String) {
        if text.isEmpty || text.wholeMatch(of: /\d{0,6}([.,]\d{0,2})?/) != nil {
            costText = text
        }
    }

    func updateMinutes(_ text: String) {
        if text.count <= 4, text.allSatisfy(\.isASCIIDigit) {
            minutesText = text
        }
    }

    /// Sets when the user last did it. A time in the future is moved back to now.
    func setLastDone(_ date: Date) {
        lastDoneAt = min(date, now())
    }

    /// The finished draft, or nil when the form is not valid yet.
    var draft: HabitDraft? {
        guard canStart else { return nil }
        return HabitDraft(
            kind: kind,
            name: name.trimmingCharacters(in: .whitespaces),
            lastDoneAt: lastDoneAt ?? now(),
            costPerDay: costPerDay,
            minutesPerDay: minutesPerDay
        )
    }

    /// Saves the habit, then reports its id. Does nothing if the form isn't valid.
    func startTapped() {
        guard let draft else { return }
        do {
            if let editingId {
                try store.updateDetails(id: editingId, kind: draft.kind, name: draft.name, costPerDay: draft.costPerDay, minutesPerDay: draft.minutesPerDay)
                onStarted(editingId)
            } else {
                onStarted(try store.add(draft))
            }
        } catch {
            saveFailed = true
        }
    }
}

private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}
