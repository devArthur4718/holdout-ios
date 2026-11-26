import Foundation
import Testing
@testable import Holdout

@MainActor
struct HomeViewModelTests {
    let store = SwiftDataHabitStore.inMemory()

    @discardableResult
    func add(_ name: String) throws -> UUID {
        try store.add(HabitDraft(kind: .smoking, name: name, lastDoneAt: .now, costPerDay: nil, minutesPerDay: nil))
    }

    @Test func showsNewestHabitByDefault() throws {
        try add("Cigarettes")
        try add("Alcohol")
        let vm = HomeViewModel(store: store)
        #expect(vm.habits.map(\.name) == ["Cigarettes", "Alcohol"])
        #expect(vm.selected?.name == "Alcohol")
    }

    @Test func selectingAChipSwitchesHabit() throws {
        let first = try add("Cigarettes")
        try add("Alcohol")
        let vm = HomeViewModel(store: store)
        vm.select(first)
        #expect(vm.selected?.name == "Cigarettes")
    }

    @Test func reloadPicksUpNewHabits() throws {
        try add("Cigarettes")
        let vm = HomeViewModel(store: store)
        try add("Alcohol")
        vm.reload()
        #expect(vm.habits.count == 2)
    }

    @Test func loggingASlipRestartsTheCounterAndKeepsTheStreak() throws {
        let start = Date(timeIntervalSince1970: 1_795_000_000)
        let id = try store.add(HabitDraft(kind: .smoking, name: "Cigarettes", lastDoneAt: start, costPerDay: nil, minutesPerDay: nil))
        let slipAt = start.addingTimeInterval(3 * 86_400 + 3_600)
        let vm = HomeViewModel(store: store, now: { slipAt })

        vm.logSlipTapped()
        #expect(vm.slipSheetHabit?.id == id)
        vm.confirmSlip(trigger: .stress)

        #expect(vm.slipSheetHabit == nil)
        #expect(vm.selected?.lastDoneAt == slipAt)
        #expect(vm.selected?.bestSeconds == 3 * 86_400 + 3_600)
        #expect(vm.toast == "Counter reset. Longest streak of 3 days is kept.")
        #expect(store.slips(habitId: id) == [Slip(habitId: id, at: slipAt, trigger: .stress)])
    }

    @Test func cancellingTheSheetChangesNothing() throws {
        try add("Cigarettes")
        let vm = HomeViewModel(store: store)
        let before = vm.selected
        vm.logSlipTapped()
        vm.slipSheetHabit = nil // Cancel or swipe down.
        #expect(vm.selected == before)
        #expect(vm.toast == nil)
    }

    @Test func aStreakUnderAMinuteIsNotCalledARecord() throws {
        try add("Cigarettes") // lastDoneAt is now
        let vm = HomeViewModel(store: store)
        vm.logSlipTapped()
        vm.confirmSlip(trigger: nil)
        #expect(vm.toast == "Counter reset.")
    }

    @Test(arguments: [(59, "0 min"), (61, "1 minute"), (7_199, "1 hour"), (86_400 * 2 - 1, "1 day"), (86_400 * 18, "18 days")])
    func streakLengthUsesTheLargestWholeUnit(seconds: Int, expected: String) {
        let text = HomeViewModel.streakLength(seconds)
        // Allow for locale wording; the number must be truncated, never rounded up.
        #expect(text.hasPrefix(expected.split(separator: " ")[0] + " "))
    }
}
