import SwiftUI

/// When slips and urges happen, and every streak so far.
struct InsightsView: View {
    @State private var viewModel: InsightsViewModel
    let onAddHabit: () -> Void

    init(viewModel: InsightsViewModel, onAddHabit: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onAddHabit = onAddHabit
    }

    var body: some View {
        Group {
            if let habit = viewModel.selected {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HabitPicker(habits: viewModel.habits, selectedId: habit.id, onSelect: viewModel.select)
                        HardestSection(times: viewModel.hardestTimes)
                        // The current streak is live.
                        TimelineView(.periodic(from: habit.lastDoneAt, by: 60)) { context in
                            HistorySection(rows: viewModel.streakRows(at: context.date))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            } else {
                NoHabitsView(message: "Add a habit to see when it's hardest and how your streaks add up.", onAddHabit: onAddHabit)
            }
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("Insights")
        .onAppear(perform: viewModel.reload)
    }
}

private enum InsightColors {
    static let slips = Palette.primary
    static let urges = Palette.primary.opacity(0.4)
}

private struct HardestSection: View {
    let times: HardestTimes

    var body: some View {
        let maxTotal = max(1, (times.byPart.map(\.count.total) + times.byWeekday.map(\.count.total)).max() ?? 1)
        VStack(alignment: .leading, spacing: 14) {
            Text("When it's hardest")
                .font(.headline)
                .foregroundStyle(Palette.onSurface)
                .accessibilityAddTraits(.isHeader)

            Group {
                if let hardest = times.hardest {
                    Text("Your hardest time: \(String(localized: hardest.label))")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Palette.onSurface)
                } else {
                    Text("Not enough data yet — this fills in as you log slips and urges.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.onSurfaceVariant)
                }
            }
            .accessibilityIdentifier("hardestTakeaway")

            HStack(spacing: 14) {
                legend(InsightColors.slips, "Slips")
                legend(InsightColors.urges, "Urges")
            }
            .accessibilityHidden(true)

            Text("Time of day")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.onSurfaceVariant)
            VStack(spacing: 8) {
                ForEach(times.byPart, id: \.part) { entry in
                    BarRow(label: String(localized: entry.part.label), count: entry.count, maxTotal: maxTotal)
                }
            }

            Text("Day of the week")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.onSurfaceVariant)
            VStack(spacing: 8) {
                ForEach(times.byWeekday, id: \.weekday) { day in
                    BarRow(label: day.label, count: day.count, maxTotal: maxTotal)
                }
            }
        }
        .padding(16)
        .background(Palette.surfaceContainer, in: .rect(cornerRadius: Radius.card))
    }

    private func legend(_ color: Color, _ label: LocalizedStringKey) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 12, height: 12)
            Text(label).font(.caption).foregroundStyle(Palette.onSurfaceVariant)
        }
    }
}

/// A label, a bar split into slips and urges, and the total.
private struct BarRow: View {
    let label: String
    let count: EventCount
    let maxTotal: Int

    @ScaledMetric(relativeTo: .caption) private var labelWidth: CGFloat = 88

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Palette.onSurface)
                .frame(width: labelWidth, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            GeometryReader { geo in
                let unit = geo.size.width / CGFloat(maxTotal)
                HStack(spacing: 0) {
                    Rectangle().fill(InsightColors.slips).frame(width: unit * CGFloat(count.slips))
                    Rectangle().fill(InsightColors.urges).frame(width: unit * CGFloat(count.urges))
                }
                .clipShape(.rect(cornerRadius: 3))
                .frame(maxHeight: .infinity)
            }
            .frame(height: 12)
            .background(Palette.outlineVariant.opacity(0.4), in: .rect(cornerRadius: 3))
            Text(count.total.formatted())
                .font(.caption.monospacedDigit())
                .foregroundStyle(Palette.onSurfaceVariant)
                .frame(minWidth: 20, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(InsightsViewModel.spoken(label, count))
    }
}

private struct HistorySection: View {
    let rows: [StreakRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Streak history")
                .font(.headline)
                .foregroundStyle(Palette.onSurface)
                .accessibilityAddTraits(.isHeader)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                StreakRowView(row: row)
            }
            if rows.count == 1 {
                Text("Past streaks show up here after a slip.")
                    .font(.footnote)
                    .foregroundStyle(Palette.onSurfaceVariant)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surfaceContainer, in: .rect(cornerRadius: Radius.card))
    }
}

private struct StreakRowView: View {
    let row: StreakRow

    var body: some View {
        let streak = row.streak
        let start = streak.start.formatted(date: .abbreviated, time: .omitted)
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(HomeViewModel.streakLength(streak.seconds))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Palette.onSurface)
                Group {
                    if let end = streak.end {
                        Text(verbatim: "\(start) → \(end.formatted(date: .abbreviated, time: .omitted))")
                    } else {
                        Text("Since \(start)")
                    }
                }
                .font(.caption)
                .foregroundStyle(Palette.onSurfaceVariant)
            }
            Spacer(minLength: 8)
            FlowLayout(spacing: 6, lineSpacing: 6) {
                if streak.isCurrent { tag("Current", filled: true) }
                if row.isBest { tag("Best", filled: false) }
            }
            .fixedSize()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func tag(_ text: LocalizedStringKey, filled: Bool) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(filled ? Palette.onPrimary : Palette.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(filled ? Palette.primary : .clear, in: .capsule)
            .overlay { if !filled { Capsule().strokeBorder(Palette.primary) } }
    }
}
