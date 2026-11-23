import Foundation
import Testing
@testable import Quitter

@MainActor
struct SettingsTests {
    let store = SwiftDataHabitStore.inMemory()
    let start = Date(timeIntervalSince1970: 1_795_000_000)

    func addHabit() throws -> UUID {
        let id = try store.add(HabitDraft(kind: .alcohol, name: "Wine", lastDoneAt: start, costPerDay: 8, minutesPerDay: 60))
        try store.addReason(habitId: id, text: "Sleep", at: start)
        try store.logUrge(habitId: id, startedAt: start, endedAt: start.addingTimeInterval(300))
        _ = try store.logSlip(habitId: id, at: start.addingTimeInterval(86_400), trigger: .stress)
        return id
    }

    @Test func editingFillsTheFormAndSavesWithoutTouchingTheCounter() throws {
        let id = try addHabit()
        let before = try #require(store.habit(id: id))
        var saved: UUID?
        let vm = NewHabitViewModel(store: store, editingId: id, onStarted: { saved = $0 })
        #expect(vm.isEditing)
        #expect(vm.name == "Wine")
        #expect(vm.costText == "8")
        #expect(vm.minutesText == "60")

        vm.updateName("Red wine")
        vm.updateCost("")
        vm.startTapped()

        #expect(saved == id)
        let after = try #require(store.habit(id: id))
        #expect(after.name == "Red wine")
        #expect(after.costPerDay == nil)
        #expect(after.lastDoneAt == before.lastDoneAt)
        #expect(after.bestSeconds == before.bestSeconds)
        #expect(store.allHabits().count == 1)
    }

    @Test func deletingAHabitRemovesItsHistory() throws {
        let id = try addHabit()
        let other = try store.add(HabitDraft(kind: .sugar, name: "Sweets", lastDoneAt: start, costPerDay: nil, minutesPerDay: nil))
        let vm = HabitDetailViewModel(habitId: id, store: store)
        vm.deleteHabit()
        #expect(vm.habit == nil)
        #expect(store.slips(habitId: id).isEmpty)
        #expect(store.reasons(habitId: id).isEmpty)
        #expect(store.countUrges(habitId: id, since: .distantPast) == 0)
        #expect(store.allHabits().map(\.id) == [other])
    }

    @Test func deleteAllEmptiesTheStoreAndStartsOver() throws {
        _ = try addHabit()
        var startedOver = false
        let vm = SettingsViewModel(store: store, onAllDeleted: { startedOver = true })
        vm.deleteAll()
        #expect(startedOver)
        #expect(!store.hasHabits())
        #expect(HomeViewModel(store: store).selected == nil)
    }

    @Test func exportHasOneRowPerItemAndQuotesWhereNeeded() throws {
        let id = UUID()
        let habit = Habit(id: id, kind: .smoking, name: "Cigs, rolled", lastDoneAt: start, costPerDay: Decimal(string: "11.9"), minutesPerDay: 90)
        let csv = buildExportCSV(
            habits: [habit],
            slips: [Slip(habitId: id, at: start, trigger: .stress)],
            urges: [(habitId: id, startedAt: start, endedAt: start.addingTimeInterval(300))],
            reasons: [(habitId: id, createdAt: start, text: "She said \"stop\"")]
        )
        let rows = csv.components(separatedBy: "\r\n")
        #expect(rows[0] == "type,habit,kind,start,end,detail")
        #expect(rows[1] == "habit,\"Cigs, rolled\",smoking,2026-11-18T11:06:40Z,,cost per day: 11.9; minutes per day: 90")
        #expect(rows[2] == "slip,\"Cigs, rolled\",,2026-11-18T11:06:40Z,,stress")
        #expect(rows[3] == "urge,\"Cigs, rolled\",,2026-11-18T11:06:40Z,2026-11-18T11:11:40Z,")
        #expect(rows[4] == "reason,\"Cigs, rolled\",,2026-11-18T11:06:40Z,,\"She said \"\"stop\"\"\"")
    }
}
