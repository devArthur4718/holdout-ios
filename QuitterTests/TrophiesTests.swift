import Foundation
import Testing
@testable import Quitter

struct CombinedLadderTests {
    let habitId = UUID()

    func goal(_ days: Int, _ name: String? = nil) -> PersonalGoal {
        PersonalGoal(id: UUID(), habitId: habitId, days: days, name: name, createdAt: .now)
    }

    @Test func personalGoalsSitBetweenStandardOnes() {
        let personal = [goal(45), goal(3)]
        #expect(Goals.next(afterDays: 0, personal: personal) == 1)
        #expect(Goals.next(afterDays: 1, personal: personal) == 3)
        #expect(Goals.next(afterDays: 31, personal: personal) == 45)
        #expect(Goals.next(afterDays: 45, personal: personal) == 60)
        #expect(Goals.previous(atDays: 50, personal: personal) == 45)
        #expect(Goals.previous(atDays: 2, personal: personal) == 1)
    }

    @Test func aPersonalGoalIsNamedOrLabelledByItsDays() {
        #expect(Goals.label(days: 45, personal: [goal(45, "Beach trip")]) == "Beach trip")
        #expect(Goals.label(days: 45, personal: [goal(45)], locale: Locale(identifier: "en_US")) == "45 days")
    }

    @Test(arguments: ["", "0", "abc", "3651", "-5", "2.5"])
    func daysOutsideTheRangeAreRejected(text: String) {
        #expect(PersonalGoal.validate(daysText: text, existing: []) == .failure(.daysOutOfRange))
    }

    @Test(arguments: [1, 7, 30, 365, 545, 730, 1095, 3650])
    func daysOfAStandardTrophyAreRejected(days: Int) {
        #expect(PersonalGoal.validate(daysText: "\(days)", existing: []) == .failure(.duplicate(days: days)))
    }

    @Test func daysOfAnotherPersonalGoalAreRejectedButAGoalMayKeepItsOwn() {
        let beach = goal(45)
        #expect(PersonalGoal.validate(daysText: "45", existing: [beach]) == .failure(.duplicate(days: 45)))
        #expect(PersonalGoal.validate(daysText: "45", existing: [beach], editing: beach.id) == .success(45))
        #expect(PersonalGoal.validate(daysText: " 3649 ", existing: [beach]) == .success(3649))
    }

    @Test func namesAreTrimmedAndCut() {
        #expect(PersonalGoal.cleanName("   ") == nil)
        #expect(PersonalGoal.cleanName("  Beach trip ") == "Beach trip")
        #expect(PersonalGoal.cleanName(String(repeating: "a", count: 50))?.count == 40)
    }

    @Test func problemsReadNaturallyInEachLanguage() {
        let en = Locale(identifier: "en_US"), pt = Locale(identifier: "pt_BR"), es = Locale(identifier: "es_ES")
        #expect(TrophiesViewModel.message(for: .daysOutOfRange, locale: en) == "Enter a number of days from 1 to 3,650.")
        #expect(TrophiesViewModel.message(for: .daysOutOfRange, locale: es) == "Escribe un número de días del 1 al 3.650.")
        #expect(TrophiesViewModel.message(for: .duplicate(days: 30), locale: en) == "There's already a trophy at 30 days.")
        #expect(TrophiesViewModel.message(for: .duplicate(days: 7), locale: pt) == "Já existe um troféu em 1 semana.")
    }
}

struct TrophyListTests {
    let start = Date(timeIntervalSince1970: 1_795_000_000)
    let day = 86_400.0

    func habit() -> Habit {
        Habit(id: UUID(), kind: .smoking, name: "Cigarettes", lastDoneAt: start, costPerDay: nil, minutesPerDay: nil)
    }

    func at(_ days: Double) -> Date { start.addingTimeInterval(days * day) }

    @Test func streaksRunFromTrackingToEachSlipAndOnToNow() {
        let h = habit().afterSlip(at: at(10)).afterSlip(at: at(12))
        let slips = [Slip(habitId: h.id, at: at(12), trigger: nil), Slip(habitId: h.id, at: at(10), trigger: nil)]
        let streaks = h.streaks(slips: slips, now: at(15))
        #expect(streaks == [
            Streak(start: start, end: at(10), seconds: 10 * 86_400),
            Streak(start: at(10), end: at(12), seconds: 2 * 86_400),
            Streak(start: at(12), end: nil, seconds: 3 * 86_400),
        ])
    }

    @Test func aTrophyEarnedInAPastStreakStaysEarnedWithTheFirstDate() {
        // 10 days, then a slip, 2 days, a slip, then 8 days and counting.
        let h = habit().afterSlip(at: at(10)).afterSlip(at: at(12))
        let slips = [Slip(habitId: h.id, at: at(10), trigger: nil), Slip(habitId: h.id, at: at(12), trigger: nil)]
        let items = Trophies.list(streaks: h.streaks(slips: slips, now: at(20)), personal: [])
        let week = items.first { $0.days == 7 }
        #expect(week?.earnedAt == at(7)) // from the first streak, not the current one
        #expect(items.first { $0.days == 1 }?.earnedAt == at(1))
        #expect(items.first { $0.days == 30 }?.earnedAt == nil)
        // The current streak (8 days) heads for 30; 7 is already earned, so it isn't "next".
        #expect(items.filter(\.isNext).map(\.days) == [30])
    }

    @Test func theArcsNextGoalIsMarkedNextEvenWhenEarnedBefore() {
        // 10 days, a slip, then 3 days: the arc heads for 1 week again, earned in the first streak.
        let h = habit().afterSlip(at: at(10))
        let slips = [Slip(habitId: h.id, at: at(10), trigger: nil)]
        let items = Trophies.list(streaks: h.streaks(slips: slips, now: at(13)), personal: [])
        let week = items.first { $0.days == 7 }
        #expect(week?.isNext == true)
        #expect(week?.earnedAt == at(7))
        #expect(items.filter(\.isNext).map(\.days) == [7])
        #expect(HabitProgress(habit: h, now: at(13)).nextMilestoneDays == 7)
        let spoken = TrophiesViewModel.spoken(try! #require(week), locale: Locale(identifier: "en_US"))
        #expect(spoken.hasPrefix("1 week, earned "))
        #expect(spoken.hasSuffix(". Next"))
    }

    @Test func theLadderStopsOneYearlyTrophyPastTheBestAndTheNextGoal() {
        let days = { (seconds: Int) in
            Trophies.list(streaks: [Streak(start: self.start, end: nil, seconds: seconds)], personal: []).map(\.days)
        }
        #expect(days(3 * 86_400) == [1, 7, 30, 60, 90, 180, 365])
        #expect(days(400 * 86_400) == [1, 7, 30, 60, 90, 180, 365, 545, 730])
        #expect(days(800 * 86_400) == [1, 7, 30, 60, 90, 180, 365, 545, 730, 1095, 1460])
    }

    @Test func personalGoalsMergeByDaysEvenBeyondTheCutOff() {
        let beach = PersonalGoal(id: UUID(), habitId: UUID(), days: 45, name: "Beach trip", createdAt: start)
        let far = PersonalGoal(id: UUID(), habitId: UUID(), days: 2000, name: nil, createdAt: start)
        let items = Trophies.list(streaks: [Streak(start: start, end: nil, seconds: 31 * 86_400)], personal: [far, beach])
        #expect(items.map(\.days) == [1, 7, 30, 45, 60, 90, 180, 365, 2000])
        #expect(items.first { $0.days == 45 }?.personal == beach)
        #expect(items.filter(\.isNext).map(\.days) == [45])
    }

    @Test func badgesAreSpokenInFull() {
        let en = Locale(identifier: "en_US")
        let beach = PersonalGoal(id: UUID(), habitId: UUID(), days: 45, name: "Beach trip", createdAt: start)
        let march = try! Date("2026-03-12T12:00:00Z", strategy: .iso8601)
        #expect(TrophiesViewModel.spoken(TrophyItem(days: 30, personal: nil, earnedAt: march, isNext: false), locale: en)
            .hasPrefix("30 days, earned March 1"))
        #expect(TrophiesViewModel.spoken(TrophyItem(days: 90, personal: nil, earnedAt: nil, isNext: false), locale: en)
            == "90 days, not earned yet")
        #expect(TrophiesViewModel.spoken(TrophyItem(days: 45, personal: beach, earnedAt: nil, isNext: true), locale: en)
            == "Personal goal: Beach trip, 45 days, not earned yet. Next")
        #expect(TrophiesViewModel.spoken(TrophyItem(days: 90, personal: nil, earnedAt: nil, isNext: false), locale: Locale(identifier: "pt_BR"))
            == "90 dias, ainda não conquistado")
    }
}

/// A store whose personal-goal writes fail, for the error alert.
@MainActor
final class FailingGoalStore: HabitStore {
    let base = SwiftDataHabitStore.inMemory()
    struct Failure: Error {}

    func add(_ draft: HabitDraft) throws -> UUID { try base.add(draft) }
    func habit(id: UUID) -> Habit? { base.habit(id: id) }
    func allHabits() -> [Habit] { base.allHabits() }
    func hasHabits() -> Bool { base.hasHabits() }
    func logSlip(habitId: UUID, at date: Date, trigger: SlipTrigger?) throws -> Habit? { try base.logSlip(habitId: habitId, at: date, trigger: trigger) }
    func slips(habitId: UUID) -> [Slip] { base.slips(habitId: habitId) }
    func reasons(habitId: UUID) -> [Reason] { base.reasons(habitId: habitId) }
    func addReason(habitId: UUID, text: String, at date: Date) throws { try base.addReason(habitId: habitId, text: text, at: date) }
    func updateReason(id: UUID, text: String) throws { try base.updateReason(id: id, text: text) }
    func deleteReason(id: UUID) throws { try base.deleteReason(id: id) }
    func updateDetails(id: UUID, kind: HabitKind, name: String, costPerDay: Decimal?, minutesPerDay: Int?) throws {
        try base.updateDetails(id: id, kind: kind, name: name, costPerDay: costPerDay, minutesPerDay: minutesPerDay)
    }
    func personalGoals(habitId: UUID) -> [PersonalGoal] { base.personalGoals(habitId: habitId) }
    func addPersonalGoal(habitId: UUID, days: Int, name: String?, at date: Date) throws { throw Failure() }
    func updatePersonalGoal(id: UUID, days: Int, name: String?) throws { throw Failure() }
    func deletePersonalGoal(id: UUID) throws { throw Failure() }
    func delete(id: UUID) throws { try base.delete(id: id) }
    func deleteAll() throws { try base.deleteAll() }
    func exportCSV() -> String { base.exportCSV() }
}

@MainActor
struct TrophiesViewModelTests {
    let store = SwiftDataHabitStore.inMemory()
    let start = Date(timeIntervalSince1970: 1_795_000_000)

    func addHabit(_ name: String = "Cigarettes") throws -> UUID {
        try store.add(HabitDraft(kind: .smoking, name: name, lastDoneAt: start, costPerDay: nil, minutesPerDay: nil))
    }

    @Test func addingEditingAndDeletingAPersonalGoal() throws {
        let id = try addHabit()
        let vm = TrophiesViewModel(store: store, now: { self.start })
        vm.addGoalTapped()
        vm.form?.daysText = "45"
        vm.form?.name = "  Beach trip "
        vm.saveForm()
        #expect(vm.form == nil)
        #expect(vm.personalGoals.map(\.days) == [45])
        #expect(vm.personalGoals.first?.name == "Beach trip")
        #expect(vm.trophies(at: start.addingTimeInterval(31 * 86_400)).first { $0.isNext }?.days == 45)

        let goal = try #require(vm.personalGoals.first)
        vm.goalTapped(goal)
        #expect(vm.form?.daysText == "45")
        vm.form?.daysText = "50"
        vm.form?.name = ""
        vm.saveForm()
        #expect(store.personalGoals(habitId: id).map(\.days) == [50])
        #expect(store.personalGoals(habitId: id).first?.name == nil)

        vm.deleteGoal(try #require(vm.personalGoals.first))
        #expect(vm.personalGoals.isEmpty)
    }

    @Test func aDuplicateKeepsTheFormOpenWithTheProblem() throws {
        _ = try addHabit()
        let vm = TrophiesViewModel(store: store)
        vm.addGoalTapped()
        vm.form?.daysText = "30"
        vm.saveForm()
        #expect(vm.form?.problem == .duplicate(days: 30))
        #expect(vm.personalGoals.isEmpty)
    }

    @Test func aFailedWriteShowsTheErrorAlert() throws {
        let failing = FailingGoalStore()
        _ = try failing.add(HabitDraft(kind: .smoking, name: "Cigarettes", lastDoneAt: start, costPerDay: nil, minutesPerDay: nil))
        let vm = TrophiesViewModel(store: failing)
        vm.addGoalTapped()
        vm.form?.daysText = "45"
        vm.saveForm()
        #expect(vm.saveFailed)
        #expect(vm.form != nil)
    }

    @Test func pickingAHabitShowsItsGoals() throws {
        let first = try addHabit("Cigarettes")
        let second = try addHabit("Wine")
        try store.addPersonalGoal(habitId: first, days: 45, name: nil, at: start)
        let vm = TrophiesViewModel(store: store)
        #expect(vm.selected?.id == second)
        #expect(vm.personalGoals.isEmpty)
        vm.select(first)
        #expect(vm.personalGoals.map(\.days) == [45])
    }

    @Test func goalsAreDeletedWithTheirHabitAndExported() throws {
        let id = try addHabit()
        try store.addPersonalGoal(habitId: id, days: 45, name: "Beach, \"trip\"", at: start)
        #expect(store.exportCSV().contains("goal,Cigarettes,,"))
        #expect(store.exportCSV().contains("\"days: 45; name: Beach, \"\"trip\"\"\""))
        try store.delete(id: id)
        #expect(store.personalGoals(habitId: id).isEmpty)
    }
}

struct ReviewFixTests {
    let start = Date(timeIntervalSince1970: 1_795_000_000)
    func at(_ seconds: Double) -> Date { start.addingTimeInterval(seconds) }

    @Test func aSlipDatedBeforeTheLastOneNeverMakesANegativeStreak() {
        var h = Habit(id: UUID(), kind: .smoking, name: "Cigarettes", lastDoneAt: at(1_000), costPerDay: nil, minutesPerDay: nil)
        h.bankedSeconds = 100 // tracking since at(900)
        // Slips dated before tracking began (e.g. logged with an earlier time) end streaks of zero, not negative ones.
        let slips = [Slip(habitId: h.id, at: at(800), trigger: nil), Slip(habitId: h.id, at: at(500), trigger: nil)]
        let streaks = h.streaks(slips: slips, now: at(1_200))
        #expect(streaks.allSatisfy { $0.seconds >= 0 && ($0.end ?? $0.start) >= $0.start })
        #expect(streaks.map(\.seconds) == [0, 0, 200])
        #expect(streaks.last?.start == at(1_000))
    }

    @Test func theCurrentStreakStartsNoEarlierThanTheLastSlip() {
        let h = Habit(id: UUID(), kind: .smoking, name: "Cigarettes", lastDoneAt: at(0), costPerDay: nil, minutesPerDay: nil)
        let streaks = h.streaks(slips: [Slip(habitId: h.id, at: at(300), trigger: nil)], now: at(1_000))
        #expect(streaks.last == Streak(start: at(300), end: nil, seconds: 700))
    }

    @Test func aNameCutAtFortyCharactersLosesItsTrailingSpace() {
        let name = String(repeating: "a", count: 39) + " tail"
        #expect(PersonalGoal.cleanName(name) == String(repeating: "a", count: 39))
    }

    @Test func csvTimesAreUTCWithWholeSeconds() {
        let id = UUID()
        let when = Date(timeIntervalSince1970: 1_795_471_531.789) // 2026-11-23T22:05:31.789Z
        let habit = Habit(id: id, kind: .smoking, name: "Cigarettes", lastDoneAt: when, costPerDay: nil, minutesPerDay: nil)
        let csv = buildExportCSV(habits: [habit], slips: [Slip(habitId: id, at: when, trigger: nil)], reasons: [])
        let rows = csv.components(separatedBy: "\r\n")
        #expect(rows[1] == "habit,Cigarettes,smoking,2026-11-23T22:05:31Z,,")
        #expect(rows[2] == "slip,Cigarettes,,2026-11-23T22:05:31Z,,")
    }
}
