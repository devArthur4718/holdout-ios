import SwiftUI

/// Every trophy of a habit: earned ones with their date, the next one highlighted, and personal goals.
struct TrophiesView: View {
    @State private var viewModel: TrophiesViewModel
    let onAddHabit: () -> Void

    init(viewModel: TrophiesViewModel, onAddHabit: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onAddHabit = onAddHabit
    }

    var body: some View {
        Group {
            if let habit = viewModel.selected {
                ScrollView {
                    // Earned dates and the next trophy move with time, so redraw every minute.
                    TimelineView(.periodic(from: habit.lastDoneAt, by: 60)) { context in
                        content(habit: habit, now: context.date)
                    }
                }
            } else {
                NoHabitsView(message: "Add a habit to start earning trophies.", onAddHabit: onAddHabit)
            }
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("Trophies")
        .onAppear(perform: viewModel.reload)
        .sheet(item: $viewModel.form) { form in
            PersonalGoalSheet(viewModel: viewModel, form: form)
        }
        .alert("Couldn't save", isPresented: $viewModel.saveFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please try again.")
        }
    }

    private func content(habit: Habit, now: Date) -> some View {
        let progress = HabitProgress(habit: habit, now: now, personalGoals: viewModel.personalGoals)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: 3)
        return VStack(alignment: .leading, spacing: 16) {
            HabitPicker(habits: viewModel.habits, selectedId: habit.id, onSelect: viewModel.select)

            NextTrophyPanel(progress: progress)

            Text("All trophies")
                .font(.headline)
                .foregroundStyle(Palette.onSurface)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.trophies(at: now)) { item in
                    if let goal = item.personal {
                        Button { viewModel.goalTapped(goal) } label: { TrophyBadge(item: item) }
                            .buttonStyle(.plain)
                            .accessibilityHint("Edit personal goal")
                    } else {
                        TrophyBadge(item: item)
                    }
                }
            }

            Button(action: viewModel.addGoalTapped) {
                Label("Add personal goal", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: Radius.button))
            .tint(Palette.primary)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }
}

/// The current streak's next trophy, with a compact arc.
private struct NextTrophyPanel: View {
    let progress: HabitProgress

    var body: some View {
        VStack(spacing: 8) {
            ProgressArc(elapsedSeconds: progress.elapsedSeconds, personalGoals: progress.personalGoals, size: .compact)
            Text("Next trophy — \(progress.nextGoalLabel)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Palette.onSurface)
                .multilineTextAlignment(.center)
            timeToGoText(progress.secondsToNextMilestone)
                .font(.caption)
                .foregroundStyle(Palette.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Palette.surfaceContainer, in: .rect(cornerRadius: Radius.card))
    }
}

/// One trophy: a round badge, its label and, once earned, the date.
private struct TrophyBadge: View {
    let item: TrophyItem

    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 56

    var body: some View {
        let days = Goals.label(days: item.days)
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: size * 0.42))
                    .foregroundStyle(item.isEarned ? Palette.onPrimary : Palette.outline)
                    .frame(width: size, height: size)
                    .background(item.isEarned ? Palette.primary : .clear, in: .circle)
                    .overlay {
                        if !item.isEarned { Circle().strokeBorder(Palette.outlineVariant, lineWidth: 1.5) }
                    }
                    .padding(4)
                    .overlay {
                        if item.isNext { Circle().strokeBorder(Palette.primary, lineWidth: 2) }
                    }
                if item.personal != nil {
                    Image(systemName: "star.fill")
                        .font(.system(size: size * 0.24))
                        .foregroundStyle(Palette.primary)
                        .padding(3)
                        .background(Palette.background, in: .circle)
                }
            }
            if let name = item.personal?.name {
                Text(name)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(item.isEarned ? Palette.onSurface : Palette.onSurfaceVariant)
                Text(days)
                    .font(.caption2)
                    .foregroundStyle(Palette.onSurfaceVariant)
            } else {
                Text(days)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(item.isEarned ? Palette.onSurface : Palette.onSurfaceVariant)
            }
            if let earned = item.earnedAt {
                Text(earned.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(Palette.onSurfaceVariant)
            }
            if item.isNext {
                Text("Next")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Palette.primary)
            }
        }
        .multilineTextAlignment(.center)
        .lineLimit(3)
        .frame(maxWidth: .infinity)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(TrophiesViewModel.spoken(item))
    }
}

/// Add or change a personal goal: days and an optional name.
private struct PersonalGoalSheet: View {
    let viewModel: TrophiesViewModel
    @State var form: PersonalGoalForm
    @State private var confirmDelete = false
    @FocusState private var daysFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. 45", text: $form.daysText)
                        .keyboardType(.numberPad)
                        // The message goes away once the user changes the days.
                        .onChange(of: form.daysText) { viewModel.form?.problem = nil }
                        .focused($daysFocused)
                        .accessibilityIdentifier("goalDays")
                } header: {
                    Text("Days")
                } footer: {
                    if let problem = viewModel.form?.problem {
                        Text(TrophiesViewModel.message(for: problem))
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("goalProblem")
                    }
                }
                Section("Name (optional)") {
                    TextField("e.g. Beach trip", text: $form.name)
                        .accessibilityIdentifier("goalName")
                        .onChange(of: form.name) { _, new in
                            if new.count > PersonalGoal.maxNameLength { form.name = String(new.prefix(PersonalGoal.maxNameLength)) }
                        }
                }
                if let goal = form.editing {
                    Section {
                        Button("Delete goal", role: .destructive) { confirmDelete = true }
                            .confirmationDialog("Delete this goal?", isPresented: $confirmDelete, titleVisibility: .visible) {
                                Button("Delete goal", role: .destructive) { viewModel.deleteGoal(goal) }
                            }
                    }
                }
            }
            .navigationTitle(form.editing == nil ? "New personal goal" : "Edit personal goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = form
                        updated.problem = nil
                        viewModel.form = updated
                        viewModel.saveForm()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear { daysFocused = form.editing == nil }
    }
}
