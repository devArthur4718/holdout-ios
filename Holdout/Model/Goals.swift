import Foundation

/// The goal ladder, in days. Each step is a trophy, and the next step is what the progress arc fills up to.
/// After two years, a goal lands every year. A habit's personal goals join the same ladder.
enum Goals {
    static let ladder = [1, 7, 30, 60, 90, 180, 365, 545, 730]
    static let secondsPerDay = 86_400

    /// True for a step of the standard ladder, including every yearly one after two years.
    static func isStandard(_ days: Int) -> Bool {
        ladder.contains(days) || (days > 730 && days % 365 == 0)
    }

    /// The first standard goal strictly after `days` whole days.
    private static func nextStandard(afterDays days: Int) -> Int {
        ladder.first { $0 > days } ?? (max(0, days) / 365 + 1) * 365
    }

    /// The first goal, standard or personal, strictly after `days` whole days.
    static func next(afterDays days: Int, personal: [PersonalGoal] = []) -> Int {
        let personalNext = personal.map(\.days).filter { $0 > days }.min() ?? .max
        return min(nextStandard(afterDays: days), personalNext)
    }

    /// The last goal, standard or personal, reached after `days` whole days, or 0 when none is.
    static func previous(atDays days: Int, personal: [PersonalGoal] = []) -> Int {
        let standard = days >= ladder[ladder.count - 1] ? days / 365 * 365 : (ladder.last { $0 <= days } ?? 0)
        return max(standard, personal.map(\.days).filter { $0 <= days }.max() ?? 0)
    }

    /// The goal being worked towards after this many seconds.
    static func current(elapsedSeconds: Int, personal: [PersonalGoal] = []) -> Int {
        next(afterDays: max(0, elapsedSeconds) / secondsPerDay, personal: personal)
    }

    /// 0 to 1: how much of the current goal is done, counted from the quit moment.
    static func fraction(elapsedSeconds: Int, personal: [PersonalGoal] = []) -> Double {
        let goal = current(elapsedSeconds: elapsedSeconds, personal: personal)
        return min(1, max(0, Double(elapsedSeconds) / Double(goal * secondsPerDay)))
    }

    /// A goal's name: a personal goal's own name when it has one, otherwise its day label.
    static func label(days: Int, personal: [PersonalGoal], locale: Locale = .current) -> String {
        personal.first { $0.days == days }?.name ?? label(days: days, locale: locale)
    }

    /// "1 day", "1 week", "30 days", "6 months", "1 year", "1½ years", "2 years"…
    static func label(days: Int, locale: Locale = .current) -> String {
        let resource: LocalizedStringResource = switch days {
        case 7: LocalizedStringResource("1 week", locale: locale)
        case 180: LocalizedStringResource("\(6) months", locale: locale)
        case 545: LocalizedStringResource("1½ years", locale: locale)
        case let d where d >= 365 && d % 365 == 0: LocalizedStringResource("\(d / 365) years", locale: locale)
        default: LocalizedStringResource("\(days) days", locale: locale)
        }
        return String(localized: resource)
    }
}

/// The words around the progress arc, worked out from the elapsed time alone.
struct ArcText: Equatable {
    /// "755", or the clock "05:07:09" before the first day is over.
    let big: String
    /// "days" under the big number; nil under a day.
    let unit: String?
    /// "13 h 36 min" under the unit; nil under a day.
    let detail: String?
    /// "69% of the way to 3 years".
    let progress: String
    /// The goal label at the end of the arc, e.g. "3 years".
    let goal: String
    /// Everything at once for VoiceOver.
    let accessibility: String

    init(elapsedSeconds: Int, personal: [PersonalGoal] = [], locale: Locale = .current) {
        let t = max(0, elapsedSeconds)
        let days = t / Goals.secondsPerDay
        let hours = t / 3_600 % 24
        let minutes = t / 60 % 60
        let goalDays = Goals.current(elapsedSeconds: t, personal: personal)
        goal = Goals.label(days: goalDays, personal: personal, locale: locale)

        // Whole percent in integer maths, so it floors exactly and 100% only shows once the goal is reached.
        let percent = min(100, max(0, t * 100 / (goalDays * Goals.secondsPerDay)))
        let percentText = (Double(percent) / 100).formatted(.percent.precision(.fractionLength(0)).locale(locale))
        progress = String(localized: LocalizedStringResource("\(percentText) of the way to \(goal)", locale: locale))

        let spoken: String
        if days == 0 {
            big = String(format: "%02d:%02d:%02d", hours, minutes, t % 60)
            unit = nil
            detail = nil
            let seconds = Self.spoken(t % 60, .seconds, locale)
            spoken = hours > 0
                ? String(localized: LocalizedStringResource("\(Self.spoken(hours * 3_600, .hours, locale)) and \(Self.spoken(minutes * 60, .minutes, locale))", locale: locale))
                : String(localized: LocalizedStringResource("\(Self.spoken(minutes * 60, .minutes, locale)) and \(seconds)", locale: locale))
        } else {
            big = Self.grouped(days, locale: locale)
            // Days are never 0 here, so only 1 is singular in English, Portuguese and Spanish.
            unit = String(localized: days == 1 ? LocalizedStringResource("day", locale: locale) : LocalizedStringResource("days", locale: locale))
            detail = String(localized: LocalizedStringResource("\(hours) h \(minutes) min", locale: locale))
            // Read ungrouped ("9999 days"), as on Android; the word order is the same in all three languages.
            let spokenDays = "\(String(days)) \(unit ?? "")"
            spoken = String(localized: LocalizedStringResource(
                "\(spokenDays), \(Self.spoken(hours * 3_600, .hours, locale)) and \(Self.spoken(minutes * 60, .minutes, locale))",
                locale: locale))
        }
        accessibility = "\(spoken). \(progress)."
    }

    /// "9,999" or "9.999": always grouped in threes with the locale's separator, as Android shows it.
    /// (Apple's formatter follows CLDR and leaves four-digit numbers ungrouped in Spanish.)
    static func grouped(_ number: Int, locale: Locale) -> String {
        let separator = locale.groupingSeparator ?? ","
        var digits = String(number)
        var groups: [Substring] = []
        while digits.count > 3 {
            groups.insert(digits.suffix(3), at: 0)
            digits = String(digits.dropLast(3))
        }
        groups.insert(Substring(digits), at: 0)
        return groups.joined(separator: separator)
    }

    private static func spoken(_ seconds: Int, _ unit: Duration.UnitsFormatStyle.Unit, _ locale: Locale) -> String {
        SpokenDuration.unit(seconds, unit, locale: locale)
    }
}

/// Durations as VoiceOver reads them.
enum SpokenDuration {
    /// "13 hours", "0 minutes", "1 second": one unit, spelled out, even when it's zero.
    static func unit(_ seconds: Int, _ unit: Duration.UnitsFormatStyle.Unit, locale: Locale = .current) -> String {
        Duration.seconds(seconds).formatted(.units(allowed: [unit], width: .wide, zeroValueUnits: .show(length: 1)).locale(locale))
    }

}
