import SwiftUI

struct CounterView: View {
    /// Kept in state, so a rebuilt navigation destination can't re-decide the intro text.
    @State private var viewModel: CounterViewModel

    init(viewModel: CounterViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    /// The visible height, so short content can be centred and the button pushed to the bottom.
    @State private var viewportHeight: CGFloat = 0
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Centres the content when it fits, scrolls when it doesn't (large text).
                Spacer(minLength: 0)

                Text(viewModel.intro.title)
                    .font(.title)
                    .foregroundStyle(Palette.onSurface)
                    .accessibilityAddTraits(.isHeader)

                Text(viewModel.intro.body)
                    .font(.body)
                    .foregroundStyle(Palette.onSurfaceVariant)
                    .frame(maxWidth: 280)

                arc.padding(.top, 18)

                Text(viewModel.habit?.name ?? "")
                    .font(.subheadline)
                    .foregroundStyle(Palette.onSurfaceVariant)

                notifications.padding(.top, 16)

                Spacer(minLength: 0)

                // Scrolls with the content, as on Android, rather than being pinned to the bottom.
                Button(action: viewModel.goToHabitsTapped) {
                    Text("Go to my habits")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: Radius.button))
                .tint(Palette.primary)
                .foregroundStyle(Palette.onPrimary)
                .padding(.top, 28)

                if Features.ads {
                    Text("Quitter is free and ad-supported. Ads never appear during urge or slip flows.")
                        .font(.caption2)
                        .foregroundStyle(Palette.outline)
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, minHeight: viewportHeight)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { viewportHeight = $0 }
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

    private var arc: some View {
        // Ticks on the same fraction of a second as the start, so seconds never skip.
        TimelineView(.periodic(from: viewModel.habit?.lastDoneAt ?? .now, by: 1)) { context in
            ProgressArc(elapsedSeconds: viewModel.elapsedSeconds(at: context.date), size: .large)
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
