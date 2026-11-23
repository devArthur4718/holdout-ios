import Foundation
import Testing
@testable import Quitter

@MainActor
struct UrgeViewModelTests {
    let store = SwiftDataHabitStore.inMemory()
    let start = Date(timeIntervalSince1970: 1_795_000_000) // 18 Nov 2026
    var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    func habit() throws -> UUID {
        try store.add(HabitDraft(kind: .smoking, name: "Cigarettes", lastDoneAt: start, costPerDay: nil, minutesPerDay: nil))
    }

    @Test func countsDownFromFiveMinutesAndStopsAtZero() throws {
        let fixed = start
        let vm = UrgeViewModel(habitId: try habit(), store: store, now: { fixed }, onFinished: { _ in })
        #expect(vm.remainingSeconds(at: start) == 300)
        #expect(UrgePhase(remaining: vm.remainingSeconds(at: start)) == .breathe)
        #expect(vm.remainingSeconds(at: start.addingTimeInterval(150)) == 150)
        #expect(UrgePhase(remaining: 150) == .peak)
        #expect(UrgePhase(remaining: 30) == .fading)
        #expect(vm.remainingSeconds(at: start.addingTimeInterval(400)) == 0)
        #expect(UrgePhase(remaining: 0) == .done)
    }

    @Test func gettingThroughItSavesTheUrgeAndCountsThisMonth() throws {
        let id = try habit()
        try store.logUrge(habitId: id, startedAt: start.addingTimeInterval(-30 * 86_400), endedAt: start.addingTimeInterval(-30 * 86_400)) // October
        try store.logUrge(habitId: id, startedAt: start.addingTimeInterval(-86_400), endedAt: start.addingTimeInterval(-86_400))
        var now = start
        var counts: [Int] = []
        let vm = UrgeViewModel(habitId: id, store: store, now: { now }, calendar: utc, onFinished: { counts.append($0) })
        now = start.addingTimeInterval(200)

        vm.gotThroughIt()
        vm.gotThroughIt() // A double tap saves once.

        #expect(counts == [2])
        #expect(store.countUrges(habitId: id, since: .distantPast) == 3)
    }

    @Test func homeShowsTheCountAndClosesTheTimer() throws {
        try habit()
        let home = HomeViewModel(store: store)
        home.urgeTapped()
        let urge = try #require(home.urge)
        urge.gotThroughIt()
        #expect(home.urge == nil)
        #expect(home.toast == "Urge logged and outlasted. That is 1 this month.")
    }
}
