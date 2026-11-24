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

    @Test func aHabitStartedJustNowSaysFromNowOn() throws {
        let vm = CounterViewModel(habitId: try savedHabitId(), store: store, now: lastDone.addingTimeInterval(5))
        #expect(vm.intro == .justStarted(firstGoalDays: 1))
        #expect(String(localized: vm.intro.body) == "From now on every minute counts for something. Your first trophy is at 1 day.")
    }

    @Test func aHabitStartedInThePastNamesTheNextTrophy() throws {
        let vm = CounterViewModel(habitId: try savedHabitId(), store: store, now: lastDone.addingTimeInterval(755 * 86_400))
        #expect(vm.intro == .alreadyGoing(nextGoalDays: 1095))
        #expect(String(localized: vm.intro.title) == "You're already on your way")
        #expect(String(localized: vm.intro.body) == "The time since you stopped already counts. Your next trophy is at 3 years.")
    }

    @Test(arguments: [(0, CounterViewModel.Intro.justStarted(firstGoalDays: 1)),
                      (59, .justStarted(firstGoalDays: 1)),
                      (60, .alreadyGoing(nextGoalDays: 1)),
                      (86_400, .alreadyGoing(nextGoalDays: 7)),
                      (7 * 86_400, .alreadyGoing(nextGoalDays: 30))])
    func introDependsOnWhenTheHabitStarted(seconds: Int, expected: CounterViewModel.Intro) {
        #expect(CounterViewModel.Intro(elapsedSeconds: seconds) == expected)
    }
}
