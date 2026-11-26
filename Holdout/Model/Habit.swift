import Foundation

enum HabitKind: String, CaseIterable, Identifiable {
    case smoking, alcohol, sugar, vaping, socialMedia, gambling

    var id: String { rawValue }

    var label: LocalizedStringResource {
        switch self {
        case .smoking: "Smoking"
        case .alcohol: "Alcohol"
        case .sugar: "Sugar"
        case .vaping: "Vaping"
        case .socialMedia: "Social media"
        case .gambling: "Gambling"
        }
    }

    /// Heading on the home counter, e.g. "Smoke-free for".
    var freeFor: LocalizedStringResource {
        switch self {
        case .smoking: "Smoke-free for"
        case .alcohol: "Alcohol-free for"
        case .sugar: "Sugar-free for"
        case .vaping: "Vape-free for"
        case .socialMedia: "Scroll-free for"
        case .gambling: "Bet-free for"
        }
    }

    /// Name suggested in the Name field when this kind is picked.
    var defaultName: String {
        switch self {
        case .smoking: String(localized: "Cigarettes")
        default: String(localized: label)
        }
    }
}

/// A habit the user has filled in but that is not saved yet.
struct HabitDraft: Equatable {
    let kind: HabitKind
    let name: String
    let lastDoneAt: Date
    let costPerDay: Decimal?
    let minutesPerDay: Int?
}

/// A saved habit. Its counter runs from `lastDoneAt`.
struct Habit: Equatable, Identifiable {
    let id: UUID
    let kind: HabitKind
    let name: String
    let lastDoneAt: Date
    let costPerDay: Decimal?
    let minutesPerDay: Int?
    /// Longest finished streak. The current run can beat it.
    var bestSeconds = 0
    /// Clean time from finished streaks, so money and time kept survive a slip.
    var bankedSeconds = 0

    /// When tracking began. Slips restart the counter immediately, so no time is ever untracked.
    var trackingSince: Date { lastDoneAt.addingTimeInterval(-Double(bankedSeconds)) }

    /// The habit after a slip at `date`: the current run is banked, the longest streak
    /// is kept, and the counter starts again from `date`.
    func afterSlip(at date: Date) -> Habit {
        let run = max(0, Int(date.timeIntervalSince(lastDoneAt)))
        var habit = Habit(
            id: id, kind: kind, name: name, lastDoneAt: max(date, lastDoneAt),
            costPerDay: costPerDay, minutesPerDay: minutesPerDay
        )
        habit.bestSeconds = max(bestSeconds, run)
        habit.bankedSeconds = bankedSeconds + run
        return habit
    }
}

/// What led to a slip. Optional: people can reset without saying why.
enum SlipTrigger: String, CaseIterable, Identifiable {
    case stress, social, boredom, alcohol, noReason

    var id: String { rawValue }

    var label: LocalizedStringResource {
        switch self {
        case .stress: "Stress"
        case .social: "Social"
        case .boredom: "Boredom"
        case .alcohol: "Alcohol"
        case .noReason: "No reason"
        }
    }

    /// "Alcohol" makes no sense as a trigger for an alcohol habit.
    static func forKind(_ kind: HabitKind) -> [SlipTrigger] {
        allCases.filter { !(kind == .alcohol && $0 == .alcohol) }
    }
}

/// Why the user is quitting, in their own words. Shown on the habit.
struct Reason: Equatable, Identifiable {
    let id: UUID
    let text: String

    /// Longest text accepted.
    static let maxLength = 200
}

/// One logged slip.
struct Slip: Equatable {
    let habitId: UUID
    let at: Date
    let trigger: SlipTrigger?
}
