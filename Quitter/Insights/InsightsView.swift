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
                    VStack(alignment: .leading, spacing: 12) {
                        HabitPicker(habits: viewModel.habits, selectedId: habit.id, onSelect: viewModel.select)
                        SectionTitle("When it's hardest")
                        HardestSection(times: viewModel.hardestTimes)
                        SectionTitle("Streak history")
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

private struct SectionTitle: View {
    let text: LocalizedStringKey
    init(_ text: LocalizedStringKey) { self.text = text }

    var body: some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(Palette.onSurface)
            .padding(.top, 8)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct HardestSection: View {
    let times: HardestTimes

    var body: some View {
        // Each section is scaled to its own largest single count.
        let partMax = times.byPart.map { max($0.count.slips, $0.count.urges) }.max() ?? 0
        let dayMax = times.byWeekday.map { max($0.count.slips, $0.count.urges) }.max() ?? 0
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if let hardest = times.hardest {
                    Text("Your hardest time: \(String(localized: hardest.label))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.onSurface)
                } else {
                    Text("Not enough data yet — this fills in as you log slips and urges.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.onSurfaceVariant)
                }
            }
            .accessibilityIdentifier("hardestTakeaway")

            FlowLayout(spacing: 16, lineSpacing: 6) {
                legend(InsightColors.slips, "Slips")
                legend(InsightColors.urges, "Urges")
            }
            .accessibilityHidden(true)

            subTitle("Time of day")
            ForEach(times.byPart, id: \.part) { entry in
                BarRow(label: String(localized: entry.part.label), count: entry.count, max: partMax)
            }

            subTitle("Day of the week")
            ForEach(times.byWeekday, id: \.weekday) { day in
                BarRow(label: day.label, count: day.count, max: dayMax)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surfaceContainer, in: .rect(cornerRadius: Radius.card))
    }

    private func subTitle(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Palette.onSurfaceVariant)
            .padding(.top, 8)
            .accessibilityAddTraits(.isHeader)
    }

    private func legend(_ color: Color, _ label: LocalizedStringKey) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label).font(.caption).foregroundStyle(Palette.onSurfaceVariant)
        }
    }
}

/// A label, then a slips bar and an urges bar, each with its count.
private struct BarRow: View {
    let label: String
    let count: EventCount
    let max: Int

    var body: some View {
        SplitRow(leading: 0.38, spacing: 10) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Palette.onSurface)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 3) {
                Bar(value: count.slips, max: max, color: InsightColors.slips)
                Bar(value: count.urges, max: max, color: InsightColors.urges)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(InsightsViewModel.spoken(label, count))
    }
}

private struct Bar: View {
    let value: Int
    let max: Int
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            GeometryReader { geo in
                if value > 0 && max > 0 {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(value) / CGFloat(max))
                }
            }
            .frame(height: 8)
            Text(value.formatted())
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Palette.onSurfaceVariant)
                .frame(minWidth: 20, alignment: .trailing)
        }
    }
}

/// Two views side by side sharing the width as `leading` : 1 − `leading`, vertically centred.
private struct SplitRow: Layout {
    let leading: CGFloat
    let spacing: CGFloat

    private func widths(_ total: CGFloat) -> (CGFloat, CGFloat) {
        let free = Swift.max(0, total - spacing)
        return (free * leading, free * (1 - leading))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        let (a, b) = widths(width)
        let heights = zip(subviews, [a, b]).map { $0.sizeThatFits(ProposedViewSize(width: $1, height: nil)).height }
        return CGSize(width: width, height: heights.max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let (a, b) = widths(bounds.width)
        var x = bounds.minX
        for (view, width) in zip(subviews, [a, b]) {
            let size = view.sizeThatFits(ProposedViewSize(width: width, height: nil))
            view.place(at: CGPoint(x: x, y: bounds.midY - size.height / 2), proposal: ProposedViewSize(width: width, height: size.height))
            x += width + spacing
        }
    }
}

private struct HistorySection: View {
    let rows: [StreakRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                StreakRowView(row: row)
                if index < rows.count - 1 { Divider().overlay(Palette.outlineVariant) }
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
        VStack(alignment: .leading, spacing: 2) {
            // The tags follow the length and wrap under it when there's no room.
            FlowLayout(spacing: 8, lineSpacing: 4) {
                Text(HomeViewModel.streakLength(streak.seconds))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.onSurface)
                if streak.isCurrent { tag("Current", background: Palette.primary, content: Palette.onPrimary) }
                if row.isBest { tag("Best", background: Palette.primaryContainer, content: Palette.onPrimaryContainer) }
            }
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func tag(_ text: LocalizedStringKey, background: Color, content: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(content)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(background, in: .capsule)
    }
}
