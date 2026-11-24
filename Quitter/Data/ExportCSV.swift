import Foundation

/// One CSV with a row per habit, slip, urge, reason and personal goal, so it opens in any spreadsheet.
/// Times are UTC in ISO 8601, e.g. 2026-11-18T21:30:00Z.
func buildExportCSV(
    habits: [Habit],
    slips: [Slip],
    urges: [(habitId: UUID, startedAt: Date, endedAt: Date)],
    reasons: [(habitId: UUID, createdAt: Date, text: String)],
    goals: [PersonalGoal] = []
) -> String {
    let names = Dictionary(habits.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    // ISO-8601 in UTC with whole seconds, e.g. 2026-11-23T22:05:31Z (the same on Android).
    let time = { (date: Date) in date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: false, timeZone: .gmt)) }
    var rows = [["type", "habit", "kind", "start", "end", "detail"]]
    for habit in habits {
        let detail = [
            habit.costPerDay.map { "cost per day: \($0)" },
            habit.minutesPerDay.map { "minutes per day: \($0)" },
        ].compactMap { $0 }.joined(separator: "; ")
        rows.append(["habit", habit.name, habit.kind.rawValue, time(habit.trackingSince), "", detail])
    }
    for slip in slips {
        rows.append(["slip", names[slip.habitId] ?? "", "", time(slip.at), "", slip.trigger?.rawValue ?? ""])
    }
    for urge in urges {
        rows.append(["urge", names[urge.habitId] ?? "", "", time(urge.startedAt), time(urge.endedAt), ""])
    }
    for reason in reasons {
        rows.append(["reason", names[reason.habitId] ?? "", "", time(reason.createdAt), "", reason.text])
    }
    for goal in goals {
        let detail = ["days: \(goal.days)", goal.name.map { "name: \($0)" }].compactMap { $0 }.joined(separator: "; ")
        rows.append(["goal", names[goal.habitId] ?? "", "", time(goal.createdAt), "", detail])
    }
    return rows.map { $0.map(csvField).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
}

/// "quitter-2026-11-23.csv", dated with the local calendar day.
func exportFileName(on date: Date, calendar: Calendar) -> String {
    let day = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "quitter-%04d-%02d-%02d.csv", day.year ?? 0, day.month ?? 0, day.day ?? 0)
}

/// Quotes a field when it holds a comma, quote or line break, doubling any quotes inside.
private func csvField(_ value: String) -> String {
    guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return value }
    return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
}
