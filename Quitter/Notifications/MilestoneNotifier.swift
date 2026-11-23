import Foundation
import SwiftUI
import UserNotifications

/// Trophy notifications, as the screens see them.
@MainActor
protocol MilestoneNotifying: AnyObject {
    /// True when the user turned them on and iOS allows them.
    func isOn() async -> Bool
    /// Asks for permission when needed. False when iOS says no, now or earlier.
    func turnOn() async -> Bool
    func turnOff() async
}

/// Nothing is scheduled; for previews.
final class NoMilestoneNotifications: MilestoneNotifying {
    func isOn() async -> Bool { false }
    func turnOn() async -> Bool { false }
    func turnOff() async {}
}

extension EnvironmentValues {
    @Entry var milestones: any MilestoneNotifying = NoMilestoneNotifications()
}

extension Notification.Name {
    /// Posted by the store after a habit is added, edited, reset or deleted.
    static let habitsChanged = Notification.Name("app.quitter.habitsChanged")
}

/// A notification at each trophy. iOS can't run the app when one is delivered, so several are
/// booked ahead for each habit, and the plan is redone whenever habits change or the app opens.
/// The user opts in; it's off by default.
@MainActor
final class MilestoneNotifier: MilestoneNotifying {
    nonisolated static let enabledKey = "milestoneNotifications"
    /// iOS keeps at most 64 pending notifications per app.
    nonisolated static let limit = 60

    private let store: HabitStore
    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults
    private var latest: Task<Void, Never>?
    private var observer: NSObjectProtocol?

    init(store: HabitStore, center: UNUserNotificationCenter = .current(), defaults: UserDefaults = .standard) {
        self.store = store
        self.center = center
        self.defaults = defaults
        observer = NotificationCenter.default.addObserver(forName: .habitsChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reschedule() }
        }
    }

    private var wanted: Bool {
        get { defaults.bool(forKey: Self.enabledKey) }
        set { defaults.set(newValue, forKey: Self.enabledKey) }
    }

    private func systemAllows() async -> Bool {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: true
        default: false
        }
    }

    func isOn() async -> Bool {
        let allowed = await systemAllows()
        return wanted && allowed
    }

    func turnOn() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        wanted = granted
        await reschedule().value
        return granted
    }

    func turnOff() async {
        wanted = false
        await reschedule().value
    }

    /// Replaces every booked notification with a fresh plan. Calls run one after another.
    @discardableResult
    func reschedule() -> Task<Void, Never> {
        let previous = latest
        let task = Task {
            await previous?.value
            center.removeAllPendingNotificationRequests()
            guard await isOn() else { return }
            for request in Self.requests(habits: store.allHabits(), now: .now, calendar: .current) {
                try? await center.add(request)
            }
        }
        latest = task
        return task
    }

    /// The nearest trophies across all habits, up to iOS's limit.
    nonisolated static func requests(habits: [Habit], now: Date, calendar: Calendar) -> [UNNotificationRequest] {
        guard !habits.isEmpty else { return [] }
        let perHabit = max(1, min(8, limit / habits.count))
        let planned = habits
            .flatMap { habit in habit.milestoneAlerts(now: now, calendar: calendar, count: perHabit).map { (habit, $0) } }
            .sorted { $0.1.at < $1.1.at }
            .prefix(limit)
        return planned.map { habit, alert in
            let content = UNMutableNotificationContent()
            content.title = title(kind: habit.kind, days: alert.days)
            content.body = String(localized: "Another trophy for \(habit.name). Keep going.")
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, alert.at.timeIntervalSince(now)), repeats: false)
            return UNNotificationRequest(identifier: "milestone-\(habit.id)-\(alert.days)", content: content, trigger: trigger)
        }
    }

    /// "Smoke-free for 7 days", or "… for 2 years" on an anniversary.
    nonisolated static func title(kind: HabitKind, days: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        let length: DateComponents
        if HabitProgress.isWholeYears(days) {
            formatter.allowedUnits = [.year]
            length = DateComponents(year: days / 365)
        } else {
            formatter.allowedUnits = [.day]
            length = DateComponents(day: days)
        }
        return "\(String(localized: kind.freeFor)) \(formatter.string(from: length) ?? "")"
    }
}

/// Shows a trophy notification even while the app is open.
final class ForegroundNotifications: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
