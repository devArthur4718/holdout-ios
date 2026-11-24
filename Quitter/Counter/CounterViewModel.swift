import Foundation
import Observation

@MainActor
@Observable
final class CounterViewModel {
    /// nil until found; stays nil if the habit doesn't exist.
    private(set) var habit: Habit?
    /// What the screen says above the arc, decided once when it opens.
    let intro: Intro

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
        now: Date = .now,
        onGoToHabits: @escaping () -> Void = {}
    ) {
        let habit = store.habit(id: habitId)
        self.habit = habit
        intro = Intro(elapsedSeconds: habit.map { max(0, Int(now.timeIntervalSince($0.lastDoneAt))) } ?? 0)
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

    /// The title and text above the arc: "from now on" for a habit started just now, or the next trophy
    /// for one that started in the past.
    enum Intro: Equatable {
        /// Started less than a minute ago; the first trophy is this many days away.
        case justStarted(firstGoalDays: Int)
        /// Started earlier; the next trophy lands at this many days.
        case alreadyGoing(nextGoalDays: Int)

        static let justNowSeconds = 60

        init(elapsedSeconds: Int) {
            let goal = Goals.current(elapsedSeconds: elapsedSeconds)
            self = elapsedSeconds < Self.justNowSeconds ? .justStarted(firstGoalDays: goal) : .alreadyGoing(nextGoalDays: goal)
        }

        var title: LocalizedStringResource {
            switch self {
            case .justStarted: "Your counter is running"
            case .alreadyGoing: "You're already on your way"
            }
        }

        var body: LocalizedStringResource {
            switch self {
            case .justStarted(let days):
                "From now on every minute counts for something. Your first trophy is at \(Goals.label(days: days))."
            case .alreadyGoing(let days):
                "The time since you stopped already counts. Your next trophy is at \(Goals.label(days: days))."
            }
        }
    }
}
