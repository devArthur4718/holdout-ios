import Foundation
import SwiftData
import Testing
@testable import Quitter

@MainActor
struct DatabaseMigrationTests {
    @Test func aStoreOnDiskOpensAgainThroughTheMigrationPlan() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("holdout.store")

        do {
            let store = SwiftDataHabitStore(container: try .holdout(url: url))
            _ = try store.add(HabitDraft(kind: .vaping, name: "Vape", lastDoneAt: .now, costPerDay: nil, minutesPerDay: 30))
        }
        let reopened = SwiftDataHabitStore(container: try .holdout(url: url))
        #expect(reopened.allHabits().map(\.name) == ["Vape"])
        #expect(HoldoutMigrationPlan.schemas.count == 3)
    }

    @Test func aVersionOneStoreIsMigratedAndTakesPersonalGoals() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("holdout.store")

        // A database as the first release wrote it, without personal goals.
        do {
            let v1 = Schema(versionedSchema: SchemaV1.self)
            let container = try ModelContainer(for: v1, configurations: ModelConfiguration(schema: v1, url: url))
            container.mainContext.insert(HabitRecord(draft: HabitDraft(kind: .sugar, name: "Sweets", lastDoneAt: .now, costPerDay: 3, minutesPerDay: nil)))
            try container.mainContext.save()
        }

        let store = SwiftDataHabitStore(container: try .holdout(url: url))
        let habit = try #require(store.allHabits().first)
        #expect(habit.name == "Sweets")
        try store.addPersonalGoal(habitId: habit.id, days: 45, name: "Beach trip", at: .now)
        #expect(store.personalGoals(habitId: habit.id).map(\.days) == [45])
    }

    @Test func aVersionTwoStoreWithUrgesIsMigratedAndKeepsEverythingElse() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("holdout.store")
        let start = Date(timeIntervalSince1970: 1_795_000_000)

        // A database from before the urge timer was removed.
        let habitId: UUID
        do {
            let v2 = Schema(versionedSchema: SchemaV2.self)
            let container = try ModelContainer(for: v2, configurations: ModelConfiguration(schema: v2, url: url))
            let context = container.mainContext
            let habit = HabitRecord(draft: HabitDraft(kind: .smoking, name: "Cigarettes", lastDoneAt: start, costPerDay: 5, minutesPerDay: nil))
            habitId = habit.id
            context.insert(habit)
            context.insert(SlipRecord(habitId: habitId, at: start.addingTimeInterval(-86_400), trigger: .stress))
            context.insert(UrgeRecord(habitId: habitId, startedAt: start, endedAt: start.addingTimeInterval(300)))
            context.insert(ReasonRecord(habitId: habitId, text: "For my lungs", createdAt: start))
            context.insert(PersonalGoalRecord(habitId: habitId, days: 45, name: "Beach trip", createdAt: start))
            try context.save()
        }

        let store = SwiftDataHabitStore(container: try .holdout(url: url))
        #expect(store.allHabits().map(\.name) == ["Cigarettes"])
        #expect(store.slips(habitId: habitId).map(\.trigger) == [.stress])
        #expect(store.reasons(habitId: habitId).map(\.text) == ["For my lungs"])
        #expect(store.personalGoals(habitId: habitId).map(\.name) == ["Beach trip"])
        #expect(!store.exportCSV().contains("urge"))
    }
}

struct ExportFileNameTests {
    @Test func theFileIsNamedAfterTheLocalDay() throws {
        var saoPaulo = Calendar(identifier: .gregorian)
        saoPaulo.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        // 01:30 UTC on 24 November is still 23 November in São Paulo.
        let date = try Date("2026-11-24T01:30:00Z", strategy: .iso8601)
        #expect(exportFileName(on: date, calendar: saoPaulo) == "holdout-2026-11-23.csv")
    }
}
