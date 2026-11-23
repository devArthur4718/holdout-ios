import SwiftUI

struct HabitDetailView: View {
    @State private var viewModel: HabitDetailViewModel
    @Environment(\.dismiss) private var dismiss
    /// The reason being edited, or a new one.
    @State private var editing: ReasonEditor.Target?
    @State private var confirmDelete = false
    private let onEdit: () -> Void

    init(viewModel: HabitDetailViewModel, onEdit: @escaping () -> Void = {}) {
        _viewModel = State(initialValue: viewModel)
        self.onEdit = onEdit
    }

    var body: some View {
        Group {
            if let habit = viewModel.habit {
                TimelineView(.periodic(from: habit.lastDoneAt, by: 1)) { context in
                    content(habit: habit, now: context.date)
                }
            } else {
                Color.clear.onAppear { dismiss() } // Deleted while open.
            }
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit habit", systemImage: "pencil", action: onEdit)
                    Button("Delete habit", systemImage: "trash", role: .destructive) { confirmDelete = true }
                } label: {
                    Label("More options", systemImage: "ellipsis")
                }
            }
        }
        .confirmationDialog(
            "Delete \(viewModel.habit?.name ?? "")?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: viewModel.deleteHabit)
        } message: {
            Text("Its counter, slips, urges and reasons are deleted for good. This can't be undone.")
        }
        .safeAreaInset(edge: .bottom) { actionBar }
        .onAppear(perform: viewModel.reload)
        .sheet(isPresented: $viewModel.slipSheetOpen) {
            if let habit = viewModel.habit {
                LogSlipSheet(kind: habit.kind, onCancel: { viewModel.slipSheetOpen = false }, onConfirm: viewModel.confirmSlip)
            }
        }
        .sheet(item: $editing) { target in
            ReasonEditor(target: target, onSave: { text in
                switch target {
                case .new: viewModel.addReason(text)
                case .existing(let reason): viewModel.updateReason(id: reason.id, text: text)
                }
            }, onDelete: {
                if case .existing(let reason) = target { viewModel.deleteReason(id: reason.id) }
            })
        }
        .fullScreenCover(item: $viewModel.urge) { urge in
            UrgeView(viewModel: urge, onClose: { viewModel.urge = nil })
        }
        .alert("Couldn't save", isPresented: $viewModel.saveFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please try again.")
        }
        .overlay(alignment: .bottom) {
            if let toast = viewModel.toast {
                Toast(text: toast) { viewModel.toast = nil }
                    .padding(.bottom, 72)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.toast)
    }

    private func content(habit: Habit, now: Date) -> some View {
        let progress = HabitProgress(habit: habit, now: now)
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name)
                        .font(.largeTitle)
                        .foregroundStyle(Palette.onSurface)
                        .accessibilityAddTraits(.isHeader)
                    Text("Tracking since \(habit.trackingSince.formatted(date: .abbreviated, time: .omitted))")
                        .font(.subheadline)
                        .foregroundStyle(Palette.onSurfaceVariant)
                }
                ElapsedText(seconds: progress.elapsedSeconds)

                Picker("Section", selection: $viewModel.tab) {
                    ForEach(DetailTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 4)

                switch viewModel.tab {
                case .stats: StatsSection(habit: habit, progress: progress, savings: habit.savingsByMonth(now: now, calendar: viewModel.calendar), calendar: viewModel.calendar)
                case .calendar: CalendarSection(viewModel: viewModel, now: now)
                case .reasons: ReasonsSection(reasons: viewModel.reasons, onEdit: { editing = .existing($0) }, onAdd: { editing = .new })
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button(action: viewModel.urgeTapped) {
                Label("Urge timer", systemImage: "bolt.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .foregroundStyle(Palette.onPrimary)
            .background(Palette.primary, in: .rect(cornerRadius: Radius.button))

            Button { viewModel.slipSheetOpen = true } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.headline)
                    .frame(width: 50, height: 50)
            }
            .foregroundStyle(Palette.onErrorContainer)
            .background(Palette.errorContainer, in: .rect(cornerRadius: Radius.button))
            .accessibilityLabel("Log slip")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Palette.background)
    }
}

/// "18d 06h 42m 10s" in the primary color, read aloud as "18 days, 6 hours, 42 minutes".
private struct ElapsedText: View {
    let seconds: Int
    @ScaledMetric(relativeTo: .largeTitle) private var daysSize: CGFloat = 46
    @ScaledMetric(relativeTo: .title) private var partSize: CGFloat = 26

    var body: some View {
        let t = seconds
        let unit = Font.subheadline
        let number = Font.system(size: partSize, design: .monospaced)
        let d = Text("\(t / 86_400)").font(.system(size: daysSize, weight: .medium, design: .monospaced)).tracking(-2)
        let h = Text(String(format: "%02d", t / 3_600 % 24)).font(number)
        let m = Text(String(format: "%02d", t / 60 % 60)).font(number)
        let s = Text(String(format: "%02d", t % 60)).font(number)
        return Text("\(d)\(Text("d").font(unit))  \(h)\(Text("h").font(unit))  \(m)\(Text("m").font(unit))  \(s)\(Text("s").font(unit))")
            .foregroundStyle(Palette.primary)
            .accessibilityLabel(Duration.seconds(t).formatted(.units(allowed: [.days, .hours, .minutes], width: .wide)))
    }
}

private struct StatsSection: View {
    let habit: Habit
    let progress: HabitProgress
    let savings: [MonthSavings]
    let calendar: Calendar

    private var currencyCode: String { Locale.current.currency?.identifier ?? "USD" }

    var body: some View {
        if progress.moneyKept == nil && progress.hoursBack == nil {
            Text("This habit has no daily cost or time, so there is nothing to add up yet.")
                .font(.subheadline)
                .foregroundStyle(Palette.onSurfaceVariant)
        } else {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    if let money = progress.moneyKept, let cost = habit.costPerDay {
                        tile("Money kept", money.formatted(.currency(code: currencyCode).precision(.fractionLength(0))),
                             rate: String(localized: "\(cost.formatted(.currency(code: currencyCode))) / day"))
                    }
                    if let hours = progress.hoursBack, let minutes = habit.minutesPerDay {
                        tile("Time back", String(localized: "\(hours) h"), rate: String(localized: "\(minutes) min / day"))
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                if !savings.isEmpty { chart }
            }
        }
    }

    private func tile(_ label: LocalizedStringKey, _ value: String, rate: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(Palette.onSurfaceVariant)
            Text(value)
                .font(.system(.title2, design: .monospaced))
                .foregroundStyle(Palette.onSurface)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(rate).font(.caption2).foregroundStyle(Palette.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .background(Palette.surfaceContainer, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    private var chart: some View {
        let maxTotal = max(savings.map(\.total).max() ?? 1, 0.01)
        let money = { (value: Decimal) in value.formatted(.currency(code: currencyCode).precision(.fractionLength(0))) }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Savings over time").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.onSurface)
                Spacer()
                Text("^[\(savings.count) month](inflect: true)").font(.caption).foregroundStyle(Palette.onSurfaceVariant)
            }
            VStack(spacing: 6) {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(savings.enumerated()), id: \.offset) { index, month in
                        let fraction = max(0.04, min(1, NSDecimalNumber(decimal: month.total / maxTotal).doubleValue))
                        UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4)
                            .fill(index == savings.count - 1 ? Palette.primary : Palette.outlineVariant)
                            .frame(maxWidth: .infinity)
                            .frame(height: 76 * fraction)
                    }
                }
                .frame(height: 76, alignment: .bottom)
                HStack(spacing: 8) {
                    ForEach(Array(savings.enumerated()), id: \.offset) { _, month in
                        Text(month.month.formatted(.dateTime.month(.abbreviated)))
                            .font(.caption2)
                            .foregroundStyle(Palette.onSurfaceVariant)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(savings.map { "\($0.month.formatted(.dateTime.month(.wide))): \(money($0.total))" }.joined(separator: ", "))
        }
        .padding(16)
        .background(Palette.surfaceContainer, in: .rect(cornerRadius: 16))
    }
}

private struct CalendarSection: View {
    let viewModel: HabitDetailViewModel
    let now: Date

    var body: some View {
        let calendar = viewModel.calendar
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let weekdays = (0..<7).map { symbols[(calendar.firstWeekday - 1 + $0) % 7] }
        let columns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 7)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(viewModel.month.formatted(.dateTime.month(.wide).year()))
                    .font(.headline)
                    .foregroundStyle(Palette.onSurface)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Previous month", systemImage: "chevron.left", action: viewModel.showPreviousMonth)
                    .disabled(!viewModel.canGoBack)
                    .frame(width: 44, height: 44)
                Button("Next month", systemImage: "chevron.right", action: viewModel.showNextMonth)
                    .disabled(!viewModel.canGoForward)
                    .frame(width: 44, height: 44)
            }
            .labelStyle(.iconOnly)
            LazyVGrid(columns: columns, spacing: 7) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol).font(.caption2.weight(.medium)).foregroundStyle(Palette.onSurfaceVariant)
                        .accessibilityHidden(true)
                }
                ForEach(Array(viewModel.days(at: now).enumerated()), id: \.offset) { _, day in
                    if let day { DayCell(day: day) } else { Color.clear.aspectRatio(1, contentMode: .fit) }
                }
            }
            HStack(spacing: 14) {
                legend(Palette.primary, "Clean")
                legend(Palette.errorContainer, "Slip")
            }
            .padding(.top, 2)
        }
        .padding(16)
        .background(Palette.surfaceContainer, in: .rect(cornerRadius: 16))
    }

    private func legend(_ color: Color, _ label: LocalizedStringKey) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label).font(.caption2).foregroundStyle(Palette.onSurfaceVariant)
        }
    }
}

private struct DayCell: View {
    let day: CalendarDay

    var body: some View {
        let (background, content): (Color, Color) = switch day.state {
        case .clean: (Palette.primary, Palette.onPrimary)
        case .slip: (Palette.errorContainer, Palette.onErrorContainer)
        case .untracked: (.clear, Palette.onSurfaceVariant)
        case .future: (.clear, Palette.outline)
        }
        let state: LocalizedStringKey = switch day.state {
        case .clean: "Clean"
        case .slip: "Slip"
        case .untracked: "not tracked"
        case .future: "not yet"
        }
        // The circle takes the column's width; the number sits on top, so it never gets cut off.
        Circle()
            .fill(background)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                Text("\(day.day)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(content)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .overlay { if day.isToday { Circle().strokeBorder(Palette.primary, lineWidth: 2) } }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(day.date.formatted(date: .long, time: .omitted)))
            .accessibilityValue(Text(state))
    }
}

private struct ReasonsSection: View {
    let reasons: [Reason]
    let onEdit: (Reason) -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            if reasons.isEmpty {
                Text("Why are you quitting? Write it in your own words. You will see it when an urge hits.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.onSurfaceVariant)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(reasons) { reason in
                Button { onEdit(reason) } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "heart.fill").foregroundStyle(Palette.primary).accessibilityHidden(true)
                        Text(reason.text)
                            .foregroundStyle(Palette.onSurface)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(15)
                    .background(Palette.surfaceContainer, in: .rect(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Edit reason")
            }
            Button(action: onAdd) {
                HStack(spacing: 12) {
                    Image(systemName: "plus")
                    Text("Add a reason")
                    Spacer()
                }
                .foregroundStyle(Palette.outline)
                .padding(15)
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.outlineVariant, style: StrokeStyle(lineWidth: 1, dash: [8, 6])))
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }
}

/// Adds or edits a reason.
struct ReasonEditor: View {
    enum Target: Identifiable {
        case new
        case existing(Reason)
        var id: String {
            switch self {
            case .new: "new"
            case .existing(let reason): reason.id.uuidString
            }
        }
    }

    let target: Target
    let onSave: (String) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. I want to keep up with my kids", text: $text, axis: .vertical)
                        .lineLimit(3...6)
                        .focused($focused)
                        .onChange(of: text) { _, new in
                            if new.count > Reason.maxLength { text = String(new.prefix(Reason.maxLength)) }
                        }
                } footer: {
                    Text("\(text.count) / \(Reason.maxLength)")
                }
                if case .existing = target {
                    Section {
                        Button("Delete reason", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "Add a reason" : "Edit reason")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(text)
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            if case .existing(let reason) = target { text = reason.text }
            focused = true
        }
    }

    private var isNew: Bool {
        if case .new = target { true } else { false }
    }
}

#Preview {
    let store = SwiftDataHabitStore.inMemory()
    let id = try! store.add(HabitDraft(kind: .smoking, name: "Cigarettes", lastDoneAt: .now.addingTimeInterval(-5_000_000), costPerDay: Decimal(string: "11.90"), minutesPerDay: 90))
    try! store.addReason(habitId: id, text: "My daughter asked me to stop.", at: .now)
    return NavigationStack { HabitDetailView(viewModel: HabitDetailViewModel(habitId: id, store: store)) }
}
