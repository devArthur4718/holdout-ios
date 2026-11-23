import Foundation
import Testing
@testable import Quitter

@MainActor
struct NewHabitViewModelTests {
    let now = Date(timeIntervalSince1970: 1_795_000_000)

    let store = SwiftDataHabitStore.inMemory()

    func makeVM(onStarted: @escaping (UUID) -> Void = { _ in }) -> NewHabitViewModel {
        let fixed = now
        return NewHabitViewModel(store: store, now: { fixed }, onStarted: onStarted)
    }

    @Test func startsWithSmokingAndDefaultName() {
        let vm = makeVM()
        #expect(vm.kind == .smoking)
        #expect(vm.name == "Cigarettes")
        #expect(vm.lastDoneAt == nil)
    }

    @Test func changingKindReplacesDefaultName() {
        let vm = makeVM()
        vm.selectKind(.alcohol)
        #expect(vm.name == "Alcohol")
    }

    @Test func changingKindKeepsTypedName() {
        let vm = makeVM()
        vm.updateName("Rolling tobacco")
        vm.selectKind(.vaping)
        #expect(vm.name == "Rolling tobacco")
    }

    @Test func blankNameBlocksStart() {
        var started = false
        let vm = makeVM(onStarted: { _ in started = true })
        vm.updateName("  ")
        #expect(!vm.canStart)
        vm.startTapped()
        #expect(!started)
        #expect(!store.hasHabits())
    }

    @Test func projectionMatchesDesignExample() {
        let vm = makeVM()
        vm.updateCost("11.90")
        vm.updateMinutes("90")
        #expect(vm.yearlyCost == Decimal(string: "4343.5"))
        #expect(vm.yearlyHours == 547)
    }

    @Test func costAcceptsCommaAndRejectsJunk() {
        let vm = makeVM()
        vm.updateCost("4,2")
        vm.updateCost("4,2x")
        vm.updateCost("4,255")
        #expect(vm.costText == "4,2")
        #expect(vm.costPerDay == Decimal(string: "4.2"))
    }

    @Test func tooManyMinutesBlocksStart() {
        let vm = makeVM()
        vm.updateMinutes("1441")
        #expect(vm.minutesTooHigh)
        #expect(!vm.canStart)
    }

    @Test func futureLastDoneIsClampedToNow() {
        let vm = makeVM()
        vm.setLastDone(now.addingTimeInterval(3600))
        #expect(vm.lastDoneAt == now)
    }

    @Test func draftUsesNowWhenLastDoneNotPicked() {
        let vm = makeVM()
        vm.updateCost("8")
        #expect(vm.draft == HabitDraft(kind: .smoking, name: "Cigarettes", lastDoneAt: now, costPerDay: 8, minutesPerDay: nil))
    }

    @Test func startSavesHabitAndReportsItsId() throws {
        var savedId: UUID?
        let vm = makeVM(onStarted: { savedId = $0 })
        vm.updateName("  Online poker ")
        vm.updateCost("11.90")
        vm.startTapped()
        let id = try #require(savedId)
        let habit = try #require(store.habit(id: id))
        #expect(habit.name == "Online poker")
        #expect(habit.costPerDay == Decimal(string: "11.9"))
        #expect(habit.lastDoneAt == now)
    }
}
