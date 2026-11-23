import Foundation
import Testing
@testable import Quitter

@MainActor
struct CounterViewModelTests {
    let lastDone = Date(timeIntervalSince1970: 1_795_000_000)
    let store = SwiftDataHabitStore.inMemory()

    func savedHabitId() throws -> UUID {
        try store.add(HabitDraft(kind: .smoking, name: "Cigarettes", lastDoneAt: lastDone, costPerDay: nil, minutesPerDay: nil))
    }

    @Test func loadsHabitAndCountsFromLastDone() throws {
        let vm = CounterViewModel(habitId: try savedHabitId(), store: store)
        #expect(vm.habit?.name == "Cigarettes")
        #expect(vm.elapsedSeconds(at: lastDone) == 0)
        #expect(vm.elapsedSeconds(at: lastDone.addingTimeInterval(65.7)) == 65)
    }

    @Test func clockBehindLastDoneShowsZero() throws {
        let vm = CounterViewModel(habitId: try savedHabitId(), store: store)
        #expect(vm.elapsedSeconds(at: lastDone.addingTimeInterval(-30)) == 0)
    }

    @Test func unknownHabitHasNoName() {
        let vm = CounterViewModel(habitId: UUID(), store: store)
        #expect(vm.habit == nil)
    }

    @Test func goToHabitsCallsBack() throws {
        var went = false
        let vm = CounterViewModel(habitId: try savedHabitId(), store: store, onGoToHabits: { went = true })
        vm.goToHabitsTapped()
        #expect(went)
    }

    @Test(arguments: [(0, "00:00:00"), (3_665, "01:01:05"), (3 * 86_400 + 4 * 3_600 + 1, "3d 04:00:01")])
    func formatsElapsedTime(seconds: Int, expected: String) {
        #expect(CounterViewModel.format(seconds: seconds) == expected)
    }
}
