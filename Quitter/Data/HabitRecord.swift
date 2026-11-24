import Foundation
import SwiftData

/// How a habit is stored on disk. Screens use `Habit` instead.
@Model
final class HabitRecord {
    @Attribute(.unique) var id: UUID
    /// `HabitKind` raw value.
    var kind: String
    var name: String
    var lastDoneAt: Date
    /// Exact decimal as text, e.g. "11.90", to avoid floating-point rounding.
    var costPerDay: String?
    var minutesPerDay: Int?
    var createdAt: Date
    // Added after the first release; the defaults let SwiftData migrate older stores.
    var bestSeconds: Int = 0
    var bankedSeconds: Int = 0

    init(draft: HabitDraft, createdAt: Date = .now) {
        id = UUID()
        kind = draft.kind.rawValue
        name = draft.name
        lastDoneAt = draft.lastDoneAt
        costPerDay = draft.costPerDay.map { "\($0)" }
        minutesPerDay = draft.minutesPerDay
        self.createdAt = createdAt
    }

    var habit: Habit {
        var habit = Habit(
            id: id,
            kind: HabitKind(rawValue: kind) ?? .smoking,
            name: name,
            lastDoneAt: lastDoneAt,
            costPerDay: costPerDay.flatMap { Decimal(string: $0, locale: Locale(identifier: "en_US_POSIX")) },
            minutesPerDay: minutesPerDay
        )
        habit.bestSeconds = bestSeconds
        habit.bankedSeconds = bankedSeconds
        return habit
    }
}

/// A reason for quitting.
@Model
final class ReasonRecord {
    @Attribute(.unique) var id: UUID
    var habitId: UUID
    var text: String
    var createdAt: Date

    init(habitId: UUID, text: String, createdAt: Date) {
        id = UUID()
        self.habitId = habitId
        self.text = text
        self.createdAt = createdAt
    }
}

/// An urge the user rode out.
@Model
final class UrgeRecord {
    var habitId: UUID
    var startedAt: Date
    var endedAt: Date

    init(habitId: UUID, startedAt: Date, endedAt: Date) {
        self.habitId = habitId
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}

/// One logged slip, kept for insights later.
@Model
final class SlipRecord {
    var habitId: UUID
    var at: Date
    /// `SlipTrigger` raw value, or nil when none was picked.
    var trigger: String?

    init(habitId: UUID, at: Date, trigger: SlipTrigger?) {
        self.habitId = habitId
        self.at = at
        self.trigger = trigger?.rawValue
    }

    var slip: Slip {
        Slip(habitId: habitId, at: at, trigger: trigger.flatMap(SlipTrigger.init(rawValue:)))
    }
}

/// A personal goal (trophy) for one habit. Added in SchemaV2.
@Model
final class PersonalGoalRecord {
    @Attribute(.unique) var id: UUID
    var habitId: UUID
    var days: Int
    var name: String?
    var createdAt: Date

    init(habitId: UUID, days: Int, name: String?, createdAt: Date) {
        id = UUID()
        self.habitId = habitId
        self.days = days
        self.name = name
        self.createdAt = createdAt
    }

    var goal: PersonalGoal {
        PersonalGoal(id: id, habitId: habitId, days: days, name: name, createdAt: createdAt)
    }
}
