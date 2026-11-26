import Observation
import SwiftUI

/// The habit picked on the Trophies tab, kept while the app runs.
@MainActor
@Observable
final class HabitSelection {
    var habitId: UUID?
}

/// Chips to pick a habit, in the same style as the Today screen. Hidden with fewer than two habits.
struct HabitPicker: View {
    let habits: [Habit]
    let selectedId: UUID?
    let onSelect: (UUID) -> Void

    var body: some View {
        if habits.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(habits) { habit in
                        let isSelected = habit.id == selectedId
                        Button { onSelect(habit.id) } label: {
                            Text(habit.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(isSelected ? Palette.onPrimary : Palette.onSurfaceVariant)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 32)
                                .background(isSelected ? Palette.primary : .clear, in: .rect(cornerRadius: 8))
                                .overlay {
                                    if !isSelected { RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.outline) }
                                }
                                .frame(minHeight: 44)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
            }
        }
    }
}

/// The "no habits" state of the Trophies tab.
struct NoHabitsView: View {
    let message: LocalizedStringKey
    let onAddHabit: () -> Void

    var body: some View {
        ContentUnavailableView {
            EmptyView()
        } description: {
            Text(message)
        } actions: {
            Button(action: onAddHabit) {
                Label("Add habit", systemImage: "plus").frame(minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            .tint(Palette.primary)
        }
    }
}
