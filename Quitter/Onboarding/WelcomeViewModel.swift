import Foundation
import Observation

struct Benefit: Identifiable, Equatable {
    let id: String
    /// SF Symbol name.
    let symbol: String
    let text: LocalizedStringResource
}

@MainActor
@Observable
final class WelcomeViewModel {
    let benefits: [Benefit] = [
        Benefit(id: "savings", symbol: "dollarsign.circle",
                text: "See the money and time you didn't spend add up, live"),
        Benefit(id: "trophies", symbol: "trophy",
                text: "A trophy at every goal: 1 day, 1 week, 30 days, 6 months, 1 year…"),
        Features.ads
            ? Benefit(id: "ads", symbol: "megaphone",
                      text: "Free forever, funded by ads — never on relapse screens")
            : Benefit(id: "free", symbol: "hand.raised",
                      text: "Free, with no ads and nothing to sign up for"),
    ]

    private let onAddHabit: () -> Void

    init(onAddHabit: @escaping () -> Void = {}) {
        self.onAddHabit = onAddHabit
    }

    func addHabitTapped() {
        onAddHabit()
    }
}
