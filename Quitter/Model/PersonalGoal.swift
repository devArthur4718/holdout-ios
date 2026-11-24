import Foundation

/// A trophy the user set for one habit, e.g. 45 days for a beach trip. It joins the standard ladder.
struct PersonalGoal: Equatable, Identifiable {
    let id: UUID
    let habitId: UUID
    let days: Int
    /// nil when the user left the name empty.
    let name: String?
    let createdAt: Date

    static let maxDays = 3_650
    static let maxNameLength = 40

    /// Why the days typed can't be saved.
    enum Problem: Error, Equatable {
        /// Empty, not a whole number, or outside 1…3650.
        case daysOutOfRange
        /// A standard trophy or another personal goal of the habit already sits at these days.
        case duplicate(days: Int)
    }

    /// The days typed, checked against the standard ladder and the habit's other goals.
    /// `editing` is the goal being changed, which may keep its own days.
    static func validate(daysText: String, existing: [PersonalGoal], editing: UUID? = nil) -> Result<Int, Problem> {
        guard let days = Int(daysText.trimmingCharacters(in: .whitespaces)), (1...maxDays).contains(days) else {
            return .failure(.daysOutOfRange)
        }
        if Goals.isStandard(days) || existing.contains(where: { $0.days == days && $0.id != editing }) {
            return .failure(.duplicate(days: days))
        }
        return .success(days)
    }

    /// Trimmed and cut to `maxNameLength`; nil when nothing is left.
    static func cleanName(_ text: String) -> String? {
        let trimmed = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxNameLength))
        return trimmed.isEmpty ? nil : trimmed
    }
}
