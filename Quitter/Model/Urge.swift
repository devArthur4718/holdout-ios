import Foundation

/// How long the urge timer runs. Most cravings peak and fade within a few minutes.
let urgeSeconds = 300

/// What the coach says, by how much of the timer is left.
enum UrgePhase: Equatable {
    case breathe, peak, fading, done

    init(remaining seconds: Int) {
        switch seconds {
        case 181...: self = .breathe
        case 61...: self = .peak
        case 1...: self = .fading
        default: self = .done
        }
    }

    var coach: LocalizedStringResource {
        switch self {
        case .breathe: "Breathe in for four. Hold for four. Out for six."
        case .peak: "This is the peak. It falls from here — stay with it."
        case .fading: "Almost through. Notice it already fading."
        case .done: "Five minutes. The urge passed — you rode it out."
        }
    }
}
