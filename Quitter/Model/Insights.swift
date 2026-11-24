import Foundation

/// A part of the day, by the local hour.
enum DayPart: CaseIterable {
    /// 05:00–11:59, 12:00–16:59, 17:00–21:59 and 22:00–04:59.
    case morning, afternoon, evening, night

    init(hour: Int) {
        switch hour {
        case 5..<12: self = .morning
        case 12..<17: self = .afternoon
        case 17..<22: self = .evening
        default: self = .night
        }
    }

    var label: LocalizedStringResource {
        switch self {
        case .morning: "Morning"
        case .afternoon: "Afternoon"
        case .evening: "Evening"
        case .night: "Night"
        }
    }
}

/// How many slips and urges fell in one bar.
struct EventCount: Equatable {
    var slips = 0
    var urges = 0
    var total: Int { slips + urges }
}

/// When slips and urges happen, in the phone's local time.
struct HardestTimes: Equatable {
    struct Weekday: Equatable {
        /// Calendar weekday, 1 = Sunday.
        let weekday: Int
        /// The locale's short name, e.g. "Mon".
        let label: String
        let count: EventCount
    }

    /// In the order Morning, Afternoon, Evening, Night.
    let byPart: [(part: DayPart, count: EventCount)]
    /// Seven days, starting on the locale's first weekday.
    let byWeekday: [Weekday]
    /// The part of the day with the most events; nil with fewer than `minimumEvents`.
    let hardest: DayPart?

    /// Fewer events than this say nothing yet.
    static let minimumEvents = 3

    init(slips: [Date], urges: [Date], calendar: Calendar) {
        var parts = Dictionary(uniqueKeysWithValues: DayPart.allCases.map { ($0, EventCount()) })
        var days = [Int: EventCount]()
        for (date, isSlip) in slips.map({ ($0, true) }) + urges.map({ ($0, false) }) {
            let part = DayPart(hour: calendar.component(.hour, from: date))
            let weekday = calendar.component(.weekday, from: date)
            if isSlip {
                parts[part, default: EventCount()].slips += 1
                days[weekday, default: EventCount()].slips += 1
            } else {
                parts[part, default: EventCount()].urges += 1
                days[weekday, default: EventCount()].urges += 1
            }
        }
        byPart = DayPart.allCases.map { ($0, parts[$0] ?? EventCount()) }
        let symbols = calendar.shortStandaloneWeekdaySymbols
        byWeekday = (0..<7).map { offset in
            let weekday = (calendar.firstWeekday - 1 + offset) % 7 + 1
            return Weekday(weekday: weekday, label: symbols[weekday - 1], count: days[weekday] ?? EventCount())
        }
        // The first part with the most events wins a tie.
        let top = byPart.reduce(byPart[0]) { $1.count.total > $0.count.total ? $1 : $0 }
        hardest = slips.count + urges.count >= Self.minimumEvents ? top.part : nil
    }

    static func == (lhs: HardestTimes, rhs: HardestTimes) -> Bool {
        lhs.byPart.map(\.count) == rhs.byPart.map(\.count) && lhs.byWeekday == rhs.byWeekday && lhs.hardest == rhs.hardest
    }
}
