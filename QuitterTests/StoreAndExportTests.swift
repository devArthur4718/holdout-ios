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
        let url = folder.appendingPathComponent("quitter.store")

        do {
            let store = SwiftDataHabitStore(container: try .quitter(url: url))
            _ = try store.add(HabitDraft(kind: .vaping, name: "Vape", lastDoneAt: .now, costPerDay: nil, minutesPerDay: 30))
        }
        let reopened = SwiftDataHabitStore(container: try .quitter(url: url))
        #expect(reopened.allHabits().map(\.name) == ["Vape"])
        #expect(QuitterMigrationPlan.schemas.count == 2)
    }

    @Test func aVersionOneStoreIsMigratedAndTakesPersonalGoals() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("quitter.store")

        // A database as the first release wrote it, without personal goals.
        do {
            let v1 = Schema(versionedSchema: SchemaV1.self)
            let container = try ModelContainer(for: v1, configurations: ModelConfiguration(schema: v1, url: url))
            container.mainContext.insert(HabitRecord(draft: HabitDraft(kind: .sugar, name: "Sweets", lastDoneAt: .now, costPerDay: 3, minutesPerDay: nil)))
            try container.mainContext.save()
        }

        let store = SwiftDataHabitStore(container: try .quitter(url: url))
        let habit = try #require(store.allHabits().first)
        #expect(habit.name == "Sweets")
        try store.addPersonalGoal(habitId: habit.id, days: 45, name: "Beach trip", at: .now)
        #expect(store.personalGoals(habitId: habit.id).map(\.days) == [45])
    }
}

struct ExportFileNameTests {
    @Test func theFileIsNamedAfterTheLocalDay() throws {
        var saoPaulo = Calendar(identifier: .gregorian)
        saoPaulo.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        // 01:30 UTC on 24 November is still 23 November in São Paulo.
        let date = try Date("2026-11-24T01:30:00Z", strategy: .iso8601)
        #expect(exportFileName(on: date, calendar: saoPaulo) == "quitter-2026-11-23.csv")
    }
}

struct UrgeTimeLeftTests {
    @Test func readsMinutesAndSecondsLeftInEachLanguage() {
        #expect(SpokenDuration.timeLeft(250, locale: Locale(identifier: "en_US")) == "4 minutes 10 seconds left")
        #expect(SpokenDuration.timeLeft(250, locale: Locale(identifier: "pt_BR")) == "faltam 4 minutos e 10 segundos")
        #expect(SpokenDuration.timeLeft(61, locale: Locale(identifier: "es_ES")) == "quedan 1 minuto y 1 segundo")
    }
}
