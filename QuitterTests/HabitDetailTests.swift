import Foundation
import Testing
@testable import Quitter

@MainActor
struct HabitDetailTests {
    let store = SwiftDataHabitStore.inMemory()
    var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 2 // Monday
        return calendar
    }
    func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
    var now: Date { date("2026-11-18T12:00:00Z") }

    @Test func trackingSinceSurvivesSlips() {
        let habit = Habit(id: UUID(), kind: .smoking, name: "C", lastDoneAt: date("2026-11-01T00:00:00Z"), costPerDay: nil, minutesPerDay: nil)
            .afterSlip(at: date("2026-11-04T09:00:00Z"))
        #expect(habit.trackingSince == date("2026-11-01T00:00:00Z"))
    }

    @Test func calendarMarksEachDay() throws {
        let days = calendarMonth(
            now, trackingSince: date("2026-11-03T20:00:00Z"),
            slips: [Slip(habitId: UUID(), at: date("2026-11-10T08:00:00Z"), trigger: nil)],
            now: now, calendar: utc
        )
        // 1 November 2026 is a Sunday: six blanks before it in a Monday-first week.
        #expect(days.prefix { $0 == nil }.count == 6)
        func day(_ n: Int) -> CalendarDay? { days.compactMap { $0 }.first { $0.day == n } }
        #expect(day(2)?.state == .untracked)
        #expect(day(3)?.state == .clean)
        #expect(day(10)?.state == .slip)
        #expect(day(18)?.state == .clean)
        #expect(day(18)?.isToday == true)
        #expect(day(19)?.state == .future)
    }

    @Test func savingsAddUpByTheEndOfEachMonth() {
        let habit = Habit(id: UUID(), kind: .smoking, name: "C", lastDoneAt: date("2026-09-21T00:00:00Z"), costPerDay: 10, minutesPerDay: nil)
        let savings = habit.savingsByMonth(now: now, calendar: utc)
        #expect(savings.map(\.total) == [100, 410, 585])
    }

    @Test func savingsShowAtMostSixMonths() {
        let habit = Habit(id: UUID(), kind: .smoking, name: "C", lastDoneAt: date("2025-01-01T00:00:00Z"), costPerDay: 1, minutesPerDay: nil)
        let savings = habit.savingsByMonth(now: now, calendar: utc)
        #expect(savings.count == 6)
        #expect(savings.first?.month == date("2026-06-01T00:00:00Z"))
    }

    func makeVM() throws -> HabitDetailViewModel {
        let id = try store.add(HabitDraft(kind: .smoking, name: "Cigarettes", lastDoneAt: date("2026-09-21T00:00:00Z"), costPerDay: nil, minutesPerDay: nil))
        let fixed = now
        return HabitDetailViewModel(habitId: id, store: store, now: { fixed }, calendar: utc)
    }

    @Test func calendarStaysBetweenTrackingStartAndNow() throws {
        let vm = try makeVM()
        #expect(vm.month == date("2026-11-01T00:00:00Z"))
        #expect(!vm.canGoForward)
        vm.showPreviousMonth()
        vm.showPreviousMonth()
        vm.showPreviousMonth()
        #expect(vm.month == date("2026-09-01T00:00:00Z"))
        #expect(!vm.canGoBack)
    }

    @Test func reasonsAreTrimmedCappedAndDeletedWhenCleared() throws {
        let vm = try makeVM()
        vm.addReason("   ")
        vm.addReason("  My daughter asked me to stop. ")
        vm.addReason(String(repeating: "x", count: 500))
        #expect(vm.reasons.map(\.text) == ["My daughter asked me to stop.", String(repeating: "x", count: Reason.maxLength)])
        let first = try #require(vm.reasons.first)
        vm.updateReason(id: first.id, text: "For my lungs")
        #expect(vm.reasons.first?.text == "For my lungs")
        vm.updateReason(id: first.id, text: " ")
        #expect(vm.reasons.count == 1)
    }

    @Test func loggingASlipMarksTodayAndKeepsTrackingSince() throws {
        let vm = try makeVM()
        vm.slipSheetOpen = true
        vm.confirmSlip(trigger: .boredom)
        #expect(!vm.slipSheetOpen)
        #expect(vm.days(at: now).compactMap { $0 }.first { $0.isToday }?.state == .slip)
        #expect(vm.habit?.trackingSince == date("2026-09-21T00:00:00Z"))
        #expect(vm.toast == "Counter reset. Longest streak of 58 days is kept.")
    }
}
