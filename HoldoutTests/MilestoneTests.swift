import Foundation
import Testing
import UserNotifications
@testable import Holdout

struct MilestoneTests {
    var utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    func date(_ iso: String) -> Date { try! Date(iso, strategy: .iso8601) }
    func habit(_ lastDoneAt: String, name: String = "Cigarettes") -> Habit {
        Habit(id: UUID(), kind: .smoking, name: name, lastDoneAt: date(lastDoneAt), costPerDay: nil, minutesPerDay: nil)
    }

    @Test func daytimeMilestonesArriveOnTime() {
        let h = habit("2026-11-18T10:00:00Z")
        #expect(h.milestoneAlerts(now: h.lastDoneAt, calendar: utc, count: 3) == [
            MilestoneAlert(days: 1, at: date("2026-11-19T10:00:00Z")),
            MilestoneAlert(days: 7, at: date("2026-11-25T10:00:00Z")),
            MilestoneAlert(days: 30, at: date("2026-12-18T10:00:00Z")),
        ])
    }

    @Test func lateEveningMilestonesWaitUntilEightTheNextMorning() {
        let h = habit("2026-11-18T23:30:00Z")
        #expect(h.milestoneAlerts(now: h.lastDoneAt, calendar: utc, count: 1).first?.at == date("2026-11-20T08:00:00Z"))
    }

    @Test func earlyMorningMilestonesWaitUntilEight() {
        let h = habit("2026-11-18T03:00:00Z")
        #expect(h.milestoneAlerts(now: h.lastDoneAt, calendar: utc, count: 1).first?.at == date("2026-11-19T08:00:00Z"))
    }

    @Test func aMilestoneReachedInTheNightIsStillDueAtEight() {
        let h = habit("2026-11-18T03:00:00Z")
        #expect(h.milestoneAlerts(now: date("2026-11-25T05:00:00Z"), calendar: utc, count: 1)
            == [MilestoneAlert(days: 7, at: date("2026-11-25T08:00:00Z"))])
    }

    @Test func onceDeliveredTheNextMilestoneFollows() {
        let h = habit("2026-11-18T03:00:00Z")
        #expect(h.milestoneAlerts(now: date("2026-11-25T08:00:00Z"), calendar: utc, count: 1).first?.days == 30)
    }

    @Test func milestonesAlreadyPassedInTheDayAreNotSent() {
        let h = habit("2026-11-01T10:00:00Z")
        #expect(h.milestoneAlerts(now: date("2026-11-18T12:00:00Z"), calendar: utc, count: 1).first?.days == 30)
    }

    @Test func theLadderGoesOnToEveryYearAfterTwo() {
        let h = habit("2026-01-01T12:00:00Z")
        #expect(h.milestoneAlerts(now: h.lastDoneAt, calendar: utc, count: 10).map(\.days)
            == [1, 7, 30, 60, 90, 180, 365, 545, 730, 1095])
    }

    @Test func afterAYearAndAHalfTheNextIsTwoYears() {
        let h = habit("2025-01-01T12:00:00Z")
        #expect(h.milestoneAlerts(now: date("2026-08-01T12:00:00Z"), calendar: utc, count: 2).map(\.days) == [730, 1095])
    }

    @Test func quietHoursFollowTheLocalClock() {
        var saoPaulo = Calendar(identifier: .gregorian)
        saoPaulo.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        let h = habit("2026-11-18T01:00:00Z") // 22:00 in São Paulo
        #expect(h.milestoneAlerts(now: h.lastDoneAt, calendar: saoPaulo, count: 1).first?.at == date("2026-11-19T11:00:00Z"))
    }

    @Test func notificationsReadNaturally() throws {
        let h = habit("2026-11-18T10:00:00Z")
        let first = try #require(MilestoneNotifier.requests(habits: [h], now: h.lastDoneAt, calendar: utc).first)
        #expect(first.content.title == "Smoke-free for 1 day")
        #expect(first.content.body == "Cigarettes: you made it to 1 day. Another trophy — keep going.")
        #expect(MilestoneNotifier.title(kind: .alcohol, days: 730) == "Alcohol-free for 2 years")
        #expect(MilestoneNotifier.title(kind: .alcohol, days: 545) == "Alcohol-free for 1½ years")
        #expect(MilestoneNotifier.title(kind: .sugar, days: 180) == "Sugar-free for 6 months")
    }

    @Test func notificationsAreTranslated() {
        let pt = Locale(identifier: "pt-BR"), es = Locale(identifier: "es")
        #expect(MilestoneNotifier.title(kind: .smoking, days: 7, locale: pt) == "Sem fumar há 1 semana")
        #expect(MilestoneNotifier.body(name: "Cigarro", days: 545, locale: pt) == "Cigarro: você completou 1 ano e meio. Mais um troféu — continue assim.")
        #expect(MilestoneNotifier.title(kind: .smoking, days: 1095, locale: es) == "Sin fumar desde hace 3 años")
        #expect(MilestoneNotifier.body(name: "Tabaco", days: 30, locale: es) == "Tabaco: cumpliste 30 días. Otro trofeo — sigue así.")
    }

    @Test func personalGoalsJoinThePlanWithTheirName() throws {
        let h = habit("2026-11-18T10:00:00Z")
        let beach = PersonalGoal(id: UUID(), habitId: h.id, days: 45, name: "Beach trip", createdAt: h.lastDoneAt)
        let plain = PersonalGoal(id: UUID(), habitId: h.id, days: 50, name: nil, createdAt: h.lastDoneAt)
        #expect(h.milestoneAlerts(now: date("2026-12-20T10:00:00Z"), calendar: utc, count: 3, personal: [beach, plain]).map(\.days)
            == [45, 50, 60])
        let requests = MilestoneNotifier.requests(
            habits: [h], now: date("2026-12-20T10:00:00Z"), calendar: utc, personalGoals: [h.id: [beach, plain]]
        )
        #expect(requests.first?.content.title == "Smoke-free for Beach trip")
        #expect(requests.first?.content.body == "Cigarettes: you made it to Beach trip. Another trophy — keep going.")
        #expect(requests.dropFirst().first?.content.title == "Smoke-free for 50 days")
    }

    @Test func neverMoreThanIOSAllowsAndNearestFirst() {
        let habits = (0..<20).map { habit("2026-11-18T10:00:00Z", name: "Habit \($0)") }
        let requests = MilestoneNotifier.requests(habits: habits, now: date("2026-11-18T10:00:00Z"), calendar: utc)
        #expect(requests.count == MilestoneNotifier.limit)
        let times = requests.compactMap { ($0.trigger as? UNTimeIntervalNotificationTrigger)?.timeInterval }
        #expect(times == times.sorted())
        #expect(Set(requests.map(\.identifier)).count == requests.count)
    }
}

@MainActor
final class FakeMilestones: MilestoneNotifying {
    var systemSaysYes = true
    var wanted = false
    func isOn() async -> Bool { wanted && systemSaysYes }
    func turnOn() async -> Bool { wanted = systemSaysYes; return systemSaysYes }
    func turnOff() async { wanted = false }
}

@MainActor
struct MilestoneToggleTests {
    let store = SwiftDataHabitStore.inMemory()

    @Test func settingsTurnsThemOnAndOff() async {
        let fake = FakeMilestones()
        let vm = SettingsViewModel(store: store, milestones: fake, onAllDeleted: {})
        await vm.refreshNotifications()
        #expect(!vm.milestonesOn)
        await vm.setMilestones(true)
        #expect(vm.milestonesOn)
        await vm.setMilestones(false)
        #expect(!vm.milestonesOn)
        #expect(!fake.wanted)
    }

    @Test func refusedPermissionLeavesThemOffAndSaysSo() async {
        let fake = FakeMilestones()
        fake.systemSaysYes = false
        let vm = SettingsViewModel(store: store, milestones: fake, onAllDeleted: {})
        await vm.setMilestones(true)
        #expect(!vm.milestonesOn)
        #expect(vm.notificationsBlocked)
    }

    @Test func counterOffersThemAfterTheFirstStart() async throws {
        let id = try store.add(HabitDraft(kind: .smoking, name: "Cigarettes", lastDoneAt: .now, costPerDay: nil, minutesPerDay: nil))
        let fake = FakeMilestones()
        let vm = CounterViewModel(habitId: id, store: store, milestones: fake)
        await vm.refreshNotifications()
        #expect(!vm.notificationsOn)
        await vm.notifyTapped()
        #expect(vm.notificationsOn)
        #expect(!vm.notificationsBlocked)
    }
}
