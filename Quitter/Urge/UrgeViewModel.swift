import Foundation
import Observation

@MainActor
@Observable
final class UrgeViewModel: Identifiable {
    /// When the timer started. The clock runs from here, so leaving the app doesn't pause it.
    let startedAt: Date
    /// Saving failed; the view shows an alert.
    var saveFailed = false
    /// One of the user's reasons for quitting, picked once so it doesn't change while they read it.
    let reason: String?

    private let habitId: UUID
    private let store: HabitStore
    private let now: () -> Date
    private let calendar: Calendar
    /// Called after the urge is saved, with how many were ridden out this month.
    private let onFinished: (Int) -> Void
    private var saving = false

    init(
        habitId: UUID,
        store: HabitStore,
        now: @escaping () -> Date = { .now },
        calendar: Calendar = .current,
        onFinished: @escaping (Int) -> Void
    ) {
        self.habitId = habitId
        self.store = store
        self.now = now
        self.calendar = calendar
        self.onFinished = onFinished
        startedAt = now()
        reason = store.reasons(habitId: habitId).randomElement()?.text
    }

    func remainingSeconds(at date: Date) -> Int {
        let elapsed = min(urgeSeconds, max(0, Int(date.timeIntervalSince(startedAt))))
        return urgeSeconds - elapsed
    }

    func gotThroughIt() {
        guard !saving else { return }
        saving = true
        let end = now()
        do {
            try store.logUrge(habitId: habitId, startedAt: startedAt, endedAt: end)
            let monthStart = calendar.dateInterval(of: .month, for: end)?.start ?? end
            onFinished(store.countUrges(habitId: habitId, since: monthStart))
        } catch {
            saving = false
            saveFailed = true
        }
    }
}
