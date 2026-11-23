import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    var deleteFailed = false
    /// Trophy notifications are on.
    private(set) var milestonesOn = false
    /// The user turned them on, but iOS has them off for Quitter.
    var notificationsBlocked = false

    private let store: HabitStore
    private let milestones: any MilestoneNotifying
    private let onAllDeleted: () -> Void

    init(
        store: HabitStore,
        milestones: any MilestoneNotifying = NoMilestoneNotifications(),
        onAllDeleted: @escaping () -> Void
    ) {
        self.store = store
        self.milestones = milestones
        self.onAllDeleted = onAllDeleted
    }

    func refreshNotifications() async {
        milestonesOn = await milestones.isOn()
    }

    func setMilestones(_ on: Bool) async {
        if on {
            milestonesOn = await milestones.turnOn()
            notificationsBlocked = !milestonesOn
        } else {
            await milestones.turnOff()
            milestonesOn = false
        }
    }

    /// Everything stored, ready to share or save as a file.
    func export() -> CSVExport {
        CSVExport(text: store.exportCSV())
    }

    func deleteAll() {
        do {
            try store.deleteAll()
            onAllDeleted()
        } catch {
            deleteFailed = true
        }
    }

    var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
}
