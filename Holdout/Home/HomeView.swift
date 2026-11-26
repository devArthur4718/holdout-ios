import SwiftUI

struct HomeView: View {
    let viewModel: HomeViewModel

    var body: some View {
        ScrollView {
            if let habit = viewModel.selected {
                // Everything below depends on the time, so redraw it every second.
                TimelineView(.periodic(from: habit.lastDoneAt, by: 1)) { context in
                    let progress = HabitProgress(habit: habit, now: context.date, personalGoals: viewModel.personalGoals)
                    VStack(spacing: 12) {
                        HabitChips(viewModel: viewModel)
                        CounterCard(habit: habit, progress: progress, actions: viewModel.actions, onLogSlip: viewModel.logSlipTapped)
                        StatTiles(progress: progress)
                        NextTrophyCard(progress: progress, action: { viewModel.actions.openDetail(habit.id) })
                        if Features.checkIn {
                            CheckInRow(action: viewModel.actions.checkIn)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            } else {
                // Every habit was deleted.
                ContentUnavailableView {
                    Text("No habits yet")
                } description: {
                    Text("Add the habit you want to quit and your counter starts.")
                } actions: {
                    Button("Add habit", action: viewModel.actions.addHabit)
                        .buttonStyle(.borderedProminent)
                }
                .containerRelativeFrame(.vertical)
            }
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("Today")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Settings", systemImage: "gearshape", action: viewModel.actions.settings)
                    .tint(Palette.onSurfaceVariant)
            }
        }
        .onAppear(perform: viewModel.reload)
        .sheet(item: Binding(get: { viewModel.slipSheetHabit }, set: { viewModel.slipSheetHabit = $0 })) { habit in
            LogSlipSheet(
                kind: habit.kind,
                onCancel: { viewModel.slipSheetHabit = nil },
                onConfirm: viewModel.confirmSlip
            )
        }
        .alert("Couldn't log the slip", isPresented: Binding(get: { viewModel.slipFailed }, set: { viewModel.slipFailed = $0 })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your counter wasn't reset. Please try again.")
        }
        .overlay(alignment: .bottom) {
            if let toast = viewModel.toast {
                Toast(text: toast) { viewModel.toast = nil }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.toast)
    }
}


private struct HabitChips: View {
    let viewModel: HomeViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.habits) { habit in
                    let isSelected = habit.id == viewModel.selected?.id
                    Button { viewModel.select(habit.id) } label: {
                        Text(habit.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(isSelected ? Palette.onPrimary : Palette.onSurfaceVariant)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 32)
                            .background(isSelected ? Palette.primary : .clear, in: .rect(cornerRadius: 8))
                            .overlay {
                                if !isSelected { RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.outline) }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
                Button(action: viewModel.actions.addHabit) {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Palette.onSurfaceVariant)
                        .frame(width: 32, height: 32)
                        .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.outline) }
                        // A 44 pt touch target around the small chip.
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add habit")
            }
            .padding(.vertical, 2)
        }
    }
}

private struct CounterCard: View {
    let habit: Habit
    let progress: HabitProgress
    let actions: HomeViewModel.Actions
    let onLogSlip: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Text(habit.kind.freeFor)
                .textCase(.uppercase)
                .font(.caption.weight(.medium))
                .tracking(0.6)
                .accessibilityAddTraits(.isHeader)

            ProgressArc(
                elapsedSeconds: progress.elapsedSeconds,
                personalGoals: progress.personalGoals,
                size: .compact,
                trackColor: Palette.onPrimaryContainer.opacity(0.12),
                contentColor: Palette.onPrimaryContainer,
                secondaryColor: Palette.onPrimaryContainer.opacity(0.85)
            )
            .padding(.vertical, 6)

            Group {
                if progress.isPersonalBest || progress.bestSeconds < HomeViewModel.notableStreak {
                    Text("Personal best — you are on it")
                } else {
                    Text("Personal best: \(HomeViewModel.streakLength(progress.bestSeconds))")
                }
            }
                .font(.footnote)
                .opacity(0.85)

            // Opens the slip sheet, which asks before anything is reset.
            Button(action: onLogSlip) {
                Text("Reset Counter")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 6)
                    .frame(minHeight: 30)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(Palette.background)
            .foregroundStyle(Palette.primary)
            .padding(.top, 14)
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(Palette.onPrimaryContainer)
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Palette.primaryContainer, in: .rect(cornerRadius: 28))
    }

}

private struct StatTiles: View {
    let progress: HabitProgress

    private var currencyCode: String { Locale.current.currency?.identifier ?? "USD" }

    var body: some View {
        if progress.moneyKept != nil || progress.hoursBack != nil {
            HStack(spacing: 10) {
                if let money = progress.moneyKept {
                    tile("banknote", money.formatted(.currency(code: currencyCode).precision(.fractionLength(0))), label: "money kept")
                }
                if let hours = progress.hoursBack {
                    tile("clock", "\(hours) h", label: "time back")
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func tile(_ symbol: String, _ value: String, label: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Image(systemName: symbol)
                .foregroundStyle(Palette.primary)
                .frame(height: 24) // Icons differ in height; keep the values level.
                .accessibilityHidden(true)
            Text(value)
                .font(.system(.title2, design: .monospaced))
                .foregroundStyle(Palette.onSurface)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.caption)
                .foregroundStyle(Palette.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .background(Palette.surfaceContainer, in: .rect(cornerRadius: Radius.card))
        .accessibilityElement(children: .combine)
    }
}

private struct NextTrophyCard: View {
    let progress: HabitProgress
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ViewThatFits(in: .horizontal) {
                    HStack {
                        title
                        Spacer()
                        timeToGo
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        title
                        timeToGo
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surfaceContainer, in: .rect(cornerRadius: Radius.card))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var title: some View {
        Text("Next trophy — \(progress.nextGoalLabel)")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Palette.onSurface)
    }

    private var timeToGo: some View {
        timeToGoText(progress.secondsToNextMilestone)
            .font(.caption)
            .foregroundStyle(Palette.onSurfaceVariant)
    }
}

/// "12 days to go", "5 hours to go" or "3 minutes to go", rounded up.
func timeToGoText(_ s: Int) -> Text {
    if s >= 86_400 {
        Text("^[\((s + 86_399) / 86_400) day](inflect: true) to go")
    } else if s >= 3_600 {
        Text("^[\((s + 3_599) / 3_600) hour](inflect: true) to go")
    } else {
        Text("^[\(max(1, (s + 59) / 60)) minute](inflect: true) to go")
    }
}

private struct CheckInRow: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(Palette.onPrimaryContainer)
                    .frame(width: 38, height: 38)
                    .background(Palette.primaryContainer, in: .rect(cornerRadius: 12))
                    .accessibilityHidden(true)
                VStack(alignment: .leading) {
                    Text("Evening check-in")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Palette.onSurface)
                    Text("A minute, once a day")
                        .font(.caption)
                        .foregroundStyle(Palette.onSurfaceVariant)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.onSurfaceVariant)
            }
            .padding(14)
            .background(Palette.surfaceContainer, in: .rect(cornerRadius: Radius.card))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Light") {
    let store = SwiftDataHabitStore.inMemory()
    _ = try? store.add(HabitDraft(kind: .alcohol, name: "Alcohol", lastDoneAt: .now.addingTimeInterval(-5_400_000), costPerDay: 8, minutesPerDay: 120))
    _ = try? store.add(HabitDraft(kind: .smoking, name: "Cigarettes", lastDoneAt: .now.addingTimeInterval(-1_580_000), costPerDay: Decimal(string: "11.90"), minutesPerDay: 90))
    return NavigationStack { HomeView(viewModel: HomeViewModel(store: store)) }
}

#Preview("Dark, largest text") {
    let store = SwiftDataHabitStore.inMemory()
    _ = try? store.add(HabitDraft(kind: .smoking, name: "Cigarettes", lastDoneAt: .now.addingTimeInterval(-1_580_000), costPerDay: Decimal(string: "11.90"), minutesPerDay: 90))
    return NavigationStack { HomeView(viewModel: HomeViewModel(store: store)) }
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility3)
}
