import Foundation
import SwiftData

/// The one place screens read and write habits. ViewModels depend on this, not on SwiftData.
@MainActor
protocol HabitStore {
    /// Saves the draft and returns the new habit's id.
    func add(_ draft: HabitDraft) throws -> UUID
    func habit(id: UUID) -> Habit?
    /// All habits, oldest first.
    func allHabits() -> [Habit]
    func hasHabits() -> Bool
    /// Records a slip and restarts the habit's counter from `date`.
    /// Returns the habit as it is now, or nil if it doesn't exist.
    func logSlip(habitId: UUID, at date: Date, trigger: SlipTrigger?) throws -> Habit?
    /// A habit's slips, oldest first.
    func slips(habitId: UUID) -> [Slip]
    /// A habit's reasons, oldest first.
    func reasons(habitId: UUID) -> [Reason]
    func addReason(habitId: UUID, text: String, at date: Date) throws
    func updateReason(id: UUID, text: String) throws
    func deleteReason(id: UUID) throws
    /// Changes what can be edited after the start. When the user last did it can't change.
    func updateDetails(id: UUID, kind: HabitKind, name: String, costPerDay: Decimal?, minutesPerDay: Int?) throws
    /// A habit's personal goals, fewest days first.
    func personalGoals(habitId: UUID) -> [PersonalGoal]
    func addPersonalGoal(habitId: UUID, days: Int, name: String?, at date: Date) throws
    func updatePersonalGoal(id: UUID, days: Int, name: String?) throws
    func deletePersonalGoal(id: UUID) throws
    /// Deletes the habit with its slips, reasons and personal goals.
    func delete(id: UUID) throws
    /// Deletes everything the app has stored.
    func deleteAll() throws
    /// Everything the app has stored, as CSV text.
    func exportCSV() -> String
}

@MainActor
final class SwiftDataHabitStore: HabitStore {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    /// Keeps the container alive: a context whose container is gone crashes when used.
    init(container: ModelContainer) {
        self.container = container
    }

    func add(_ draft: HabitDraft) throws -> UUID {
        let record = HabitRecord(draft: draft)
        context.insert(record)
        try context.save()
        habitsChanged()
        return record.id
    }

    /// Trophy notifications follow the habits; see MilestoneNotifier.
    private func habitsChanged() {
        NotificationCenter.default.post(name: .habitsChanged, object: nil)
    }

    func habit(id: UUID) -> Habit? {
        record(id: id)?.habit
    }

    private func record(id: UUID) -> HabitRecord? {
        var descriptor = FetchDescriptor<HabitRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    func logSlip(habitId: UUID, at date: Date, trigger: SlipTrigger?) throws -> Habit? {
        guard let record = record(id: habitId) else { return nil }
        let updated = record.habit.afterSlip(at: date)
        record.lastDoneAt = updated.lastDoneAt
        record.bestSeconds = updated.bestSeconds
        record.bankedSeconds = updated.bankedSeconds
        context.insert(SlipRecord(habitId: habitId, at: date, trigger: trigger))
        do {
            try context.save() // Both changes land together, or neither does.
            habitsChanged()
        } catch {
            context.rollback()
            throw error
        }
        return updated
    }

    func reasons(habitId: UUID) -> [Reason] {
        let descriptor = FetchDescriptor<ReasonRecord>(
            predicate: #Predicate { $0.habitId == habitId },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return ((try? context.fetch(descriptor)) ?? []).map { Reason(id: $0.id, text: $0.text) }
    }

    func addReason(habitId: UUID, text: String, at date: Date) throws {
        context.insert(ReasonRecord(habitId: habitId, text: text, createdAt: date))
        try context.save()
    }

    func updateReason(id: UUID, text: String) throws {
        guard let record = reasonRecord(id: id) else { return }
        record.text = text
        try context.save()
    }

    func deleteReason(id: UUID) throws {
        guard let record = reasonRecord(id: id) else { return }
        context.delete(record)
        try context.save()
    }

    private func reasonRecord(id: UUID) -> ReasonRecord? {
        var descriptor = FetchDescriptor<ReasonRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    func updateDetails(id: UUID, kind: HabitKind, name: String, costPerDay: Decimal?, minutesPerDay: Int?) throws {
        guard let record = record(id: id) else { return }
        record.kind = kind.rawValue
        record.name = name
        record.costPerDay = costPerDay.map { "\($0)" }
        record.minutesPerDay = minutesPerDay
        try context.save()
        habitsChanged()
    }

    func personalGoals(habitId: UUID) -> [PersonalGoal] {
        let descriptor = FetchDescriptor<PersonalGoalRecord>(
            predicate: #Predicate { $0.habitId == habitId },
            sortBy: [SortDescriptor(\.days)]
        )
        return ((try? context.fetch(descriptor)) ?? []).map(\.goal)
    }

    func addPersonalGoal(habitId: UUID, days: Int, name: String?, at date: Date) throws {
        context.insert(PersonalGoalRecord(habitId: habitId, days: days, name: name, createdAt: date))
        try saveGoals()
    }

    func updatePersonalGoal(id: UUID, days: Int, name: String?) throws {
        guard let record = goalRecord(id: id) else { return }
        record.days = days
        record.name = name
        try saveGoals()
    }

    func deletePersonalGoal(id: UUID) throws {
        guard let record = goalRecord(id: id) else { return }
        context.delete(record)
        try saveGoals()
    }

    private func goalRecord(id: UUID) -> PersonalGoalRecord? {
        var descriptor = FetchDescriptor<PersonalGoalRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    /// Personal goals change the trophy notifications, so they are re-planned.
    private func saveGoals() throws {
        do {
            try context.save()
            habitsChanged()
        } catch {
            context.rollback()
            throw error
        }
    }

    func delete(id: UUID) throws {
        try context.delete(model: PersonalGoalRecord.self, where: #Predicate { $0.habitId == id })
        try context.delete(model: SlipRecord.self, where: #Predicate { $0.habitId == id })
        try context.delete(model: ReasonRecord.self, where: #Predicate { $0.habitId == id })
        try context.delete(model: HabitRecord.self, where: #Predicate { $0.id == id })
        try context.save()
        habitsChanged()
    }

    func deleteAll() throws {
        try context.delete(model: PersonalGoalRecord.self)
        try context.delete(model: SlipRecord.self)
        try context.delete(model: ReasonRecord.self)
        try context.delete(model: HabitRecord.self)
        try context.save()
        habitsChanged()
    }

    func exportCSV() -> String {
        let reasons = (try? context.fetch(FetchDescriptor<ReasonRecord>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        let slips = (try? context.fetch(FetchDescriptor<SlipRecord>(sortBy: [SortDescriptor(\.at)]))) ?? []
        let goals = (try? context.fetch(FetchDescriptor<PersonalGoalRecord>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        return buildExportCSV(
            habits: allHabits(),
            slips: slips.map(\.slip),
            reasons: reasons.map { (habitId: $0.habitId, createdAt: $0.createdAt, text: $0.text) },
            goals: goals.map(\.goal)
        )
    }

    func slips(habitId: UUID) -> [Slip] {
        let descriptor = FetchDescriptor<SlipRecord>(
            predicate: #Predicate { $0.habitId == habitId },
            sortBy: [SortDescriptor(\.at)]
        )
        return ((try? context.fetch(descriptor)) ?? []).map(\.slip)
    }

    func allHabits() -> [Habit] {
        let descriptor = FetchDescriptor<HabitRecord>(sortBy: [SortDescriptor(\.createdAt)])
        return ((try? context.fetch(descriptor)) ?? []).map(\.habit)
    }

    func hasHabits() -> Bool {
        ((try? context.fetchCount(FetchDescriptor<HabitRecord>())) ?? 0) > 0
    }
}

/// The database layout as first shipped.
enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [HabitRecord.self, SlipRecord.self, UrgeRecord.self, ReasonRecord.self]
    }
}

/// Adds personal goals. The other models are unchanged.
enum SchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [HabitRecord.self, SlipRecord.self, UrgeRecord.self, ReasonRecord.self, PersonalGoalRecord.self]
    }
}

/// Drops urges: the urge timer was removed. Their rows are deleted with the table.
enum SchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] {
        [HabitRecord.self, SlipRecord.self, ReasonRecord.self, PersonalGoalRecord.self]
    }
}

/// How an older database on the phone is brought up to the current schema.
enum HoldoutMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self, SchemaV3.self] }
    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self),
            .lightweight(fromVersion: SchemaV2.self, toVersion: SchemaV3.self),
        ]
    }
}

extension ModelContainer {
    /// The app's database, opened through the migration plan. `inMemory` is for tests and previews:
    /// nothing is written to disk. `url` places it somewhere else, for tests.
    static func holdout(inMemory: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV3.self)
        let config = if let url {
            ModelConfiguration(schema: schema, url: url)
        } else {
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        }
        return try ModelContainer(for: schema, migrationPlan: HoldoutMigrationPlan.self, configurations: config)
    }
}

extension SwiftDataHabitStore {
    /// A throwaway store for previews and tests.
    static func inMemory() -> SwiftDataHabitStore {
        // An in-memory database can't fail to open the way a file on disk can.
        SwiftDataHabitStore(container: try! .holdout(inMemory: true))
    }
}
