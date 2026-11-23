import Foundation
import Observation

@MainActor
@Observable
final class CounterViewModel {
    /// nil until found; stays nil if the habit doesn't exist.
    private(set) var habit: Habit?

    /// Trophy notifications are on.
    private(set) var notificationsOn = false
    /// The user wants them, but iOS has them turned off for Quitter.
    private(set) var notificationsBlocked = false

    private let onGoToHabits: () -> Void
    private let milestones: any MilestoneNotifying

    init(
        habitId: UUID,
        store: HabitStore,
        milestones: any MilestoneNotifying = NoMilestoneNotifications(),
        onGoToHabits: @escaping () -> Void = {}
    ) {
        habit = store.habit(id: habitId)
        self.milestones = milestones
        self.onGoToHabits = onGoToHabits
    }

    func refreshNotifications() async {
        notificationsOn = await milestones.isOn()
        if notificationsOn { notificationsBlocked = false }
    }

    /// Asks iOS for permission, the moment the first trophy has just been mentioned.
    func notifyTapped() async {
        notificationsOn = await milestones.turnOn()
        notificationsBlocked = !notificationsOn
    }

    /// Whole seconds since the habit was last done. Never negative, even if the clock moved back.
    func elapsedSeconds(at now: Date) -> Int {
        guard let habit else { return 0 }
        return max(0, Int(now.timeIntervalSince(habit.lastDoneAt)))
    }

    func goToHabitsTapped() { onGoToHabits() }

    /// "00:01:05", or "3d 04:01:05" once a full day has passed.
    nonisolated static func format(seconds total: Int) -> String {
        let days = total / 86_400
        let clock = String(format: "%02d:%02d:%02d", total / 3_600 % 24, total / 60 % 60, total % 60)
        return days > 0 ? "\(days)d \(clock)" : clock
    }
}
