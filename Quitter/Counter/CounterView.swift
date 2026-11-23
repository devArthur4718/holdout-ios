import SwiftUI

struct CounterView: View {
    let viewModel: CounterViewModel
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @ScaledMetric(relativeTo: .largeTitle) private var tileSize: CGFloat = 112
    @ScaledMetric(relativeTo: .largeTitle) private var tileIconSize: CGFloat = 52
    @ScaledMetric(relativeTo: .largeTitle) private var clockSize: CGFloat = 44

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Image(systemName: "timer")
                    .font(.system(size: tileIconSize, weight: .medium))
                    .foregroundStyle(Palette.onPrimaryContainer)
                    .frame(width: tileSize, height: tileSize)
                    .background(Palette.primaryContainer, in: .circle)
                    .padding(.bottom, 8)
                    .accessibilityHidden(true)

                Text("Your counter is running")
                    .font(.title)
                    .foregroundStyle(Palette.onSurface)
                    .accessibilityAddTraits(.isHeader)

                Text("From now on every minute counts for something. The first trophy lands at 24 hours.")
                    .font(.body)
                    .foregroundStyle(Palette.onSurfaceVariant)
                    .frame(maxWidth: 300)

                clock.padding(.top, 18)

                Text(viewModel.habit?.name ?? "")
                    .font(.subheadline)
                    .foregroundStyle(Palette.onSurfaceVariant)

                notifications.padding(.top, 16)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            // Centres the content when it fits, scrolls when it doesn't (large text).
            .containerRelativeFrame(.vertical) { height, _ in height }
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Button(action: viewModel.goToHabitsTapped) {
                    Text("Go to my habits")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: Radius.button))
                .tint(Palette.primary)
                .foregroundStyle(Palette.onPrimary)

                if Features.ads {
                    Text("Quitter is free and ad-supported. Ads never appear during urge or slip flows.")
                        .font(.caption2)
                        .foregroundStyle(Palette.outline)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Palette.background)
        }
        .background(Palette.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task(id: scenePhase) { await viewModel.refreshNotifications() }
    }

    @ViewBuilder private var notifications: some View {
        if viewModel.notificationsOn {
            Label("You'll get a notification at each trophy.", systemImage: "bell.badge")
                .font(.subheadline)
                .foregroundStyle(Palette.onSurfaceVariant)
        } else if viewModel.notificationsBlocked {
            VStack(spacing: 4) {
                Text("Notifications are off for Quitter.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.onSurfaceVariant)
                Button("Open Settings") { openNotificationSettings(openURL) }
            }
        } else {
            Button {
                Task { await viewModel.notifyTapped() }
            } label: {
                Label("Notify me at each trophy", systemImage: "bell")
                    .frame(minHeight: 36)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
        }
    }

    private var clock: some View {
        // Ticks on the same fraction of a second as the start, so seconds never skip.
        TimelineView(.periodic(from: viewModel.habit?.lastDoneAt ?? .now, by: 1)) { context in
            let seconds = viewModel.elapsedSeconds(at: context.date)
            Text(CounterViewModel.format(seconds: seconds))
                .font(.system(size: clockSize, weight: .medium, design: .monospaced))
                .foregroundStyle(Palette.primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .accessibilityLabel(Duration.seconds(seconds).formatted(.units(allowed: [.days, .hours, .minutes, .seconds], width: .wide)))
                .accessibilityIdentifier("elapsed")
        }
    }
}

#Preview("Light") {
    let store = SwiftDataHabitStore.inMemory()
    let id = try! store.add(HabitDraft(kind: .smoking, name: "Cigarettes", lastDoneAt: .now, costPerDay: nil, minutesPerDay: nil))
    CounterView(viewModel: CounterViewModel(habitId: id, store: store))
}

#Preview("Dark, largest text") {
    let store = SwiftDataHabitStore.inMemory()
    let id = try! store.add(HabitDraft(kind: .smoking, name: "Cigarettes", lastDoneAt: .now.addingTimeInterval(-200_000), costPerDay: nil, minutesPerDay: nil))
    CounterView(viewModel: CounterViewModel(habitId: id, store: store))
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility3)
}

/// Quitter's notification page in the Settings app.
@MainActor
func openNotificationSettings(_ openURL: OpenURLAction) {
    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
}
