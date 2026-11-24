import SwiftData
import SwiftUI
import UserNotifications

@main
struct QuitterApp: App {
    /// UI tests launch with `-uiTesting` to start from an empty, throwaway database.
    private static let inMemory = ProcessInfo.processInfo.arguments.contains("-uiTesting")

    /// nil when the database couldn't be opened; the app then offers to try again instead of crashing.
    @State private var services = AppServices.open(inMemory: Self.inMemory)
    private let foregroundNotifications = ForegroundNotifications()

    init() {
        UNUserNotificationCenter.current().delegate = foregroundNotifications
    }

    var body: some Scene {
        WindowGroup {
            if let services {
                RootView(store: services.store)
                    .environment(\.milestones, services.milestones)
                    .onScenePhaseActive { services.milestones.reschedule() }
                    .modelContainer(services.container)
            } else {
                DatabaseErrorView { services = AppServices.open(inMemory: Self.inMemory) }
            }
        }
    }
}

/// The database and what's built on it, created together once it opens.
@MainActor
final class AppServices {
    let container: ModelContainer
    let store: SwiftDataHabitStore
    let milestones: MilestoneNotifier

    private init(container: ModelContainer) {
        self.container = container
        store = SwiftDataHabitStore(container: container)
        milestones = MilestoneNotifier(store: store)
    }

    /// nil when the database can't be opened, e.g. the disk is full.
    static func open(inMemory: Bool) -> AppServices? {
        guard let services = (try? ModelContainer.quitter(inMemory: inMemory)).map(AppServices.init(container:)) else { return nil }
        if inMemory { services.seedForUITests() }
        return services
    }

    /// UI tests can start with a habit last done N days ago: `-uiTestingHabitDaysAgo N`.
    /// Only for the throwaway in-memory database.
    private func seedForUITests() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-uiTestingHabitDaysAgo"), index + 1 < arguments.count,
              let days = Int(arguments[index + 1]) else { return }
        _ = try? store.add(HabitDraft(
            kind: .smoking, name: "Cigarettes", lastDoneAt: .now.addingTimeInterval(-Double(days) * 86_400),
            costPerDay: nil, minutesPerDay: nil
        ))
    }
}

/// Shown instead of crashing when the database can't be opened. Nothing is deleted.
struct DatabaseErrorView: View {
    let onTryAgain: () -> Void

    var body: some View {
        ContentUnavailableView {
            Text("Couldn't open your data")
        } description: {
            Text("Something went wrong while opening your habits. Nothing was deleted.")
        } actions: {
            Button("Try again", action: onTryAgain)
                .buttonStyle(.borderedProminent)
                .tint(Palette.primary)
        }
        .background(Palette.background.ignoresSafeArea())
    }
}

enum Route: Hashable {
    case newHabit
    case counterRunning(habitId: UUID)
    case habitDetail(habitId: UUID)
    case editHabit(habitId: UUID)
    case settings
}

private extension View {
    /// The plan of trophy notifications is redone each time the app comes to the front,
    /// in case the clock, time zone or day moved on.
    func onScenePhaseActive(_ action: @escaping () -> Void) -> some View {
        modifier(ScenePhaseActive(action: action))
    }
}

private struct ScenePhaseActive: ViewModifier {
    let action: () -> Void
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content.onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { action() }
        }
    }
}

/// Picks onboarding or the main tabs. People who already have a habit skip onboarding.
struct RootView: View {
    let store: HabitStore

    private enum Phase { case onboarding, main }
    @State private var phase: Phase?

    var body: some View {
        Group {
            switch phase {
            case .onboarding?: OnboardingFlow(store: store, onFinished: { phase = .main })
            case .main?: MainTabView(store: store, onAllDeleted: { phase = .onboarding })
            case nil: Color.clear
            }
        }
        .tint(Palette.primary)
        .onAppear {
            if phase == nil { phase = store.hasHabits() ? .main : .onboarding }
        }
    }
}

/// Welcome → New habit → Counter. Owns its navigation; ViewModels report through closures.
private struct OnboardingFlow: View {
    let store: HabitStore
    let onFinished: () -> Void

    @State private var path: [Route] = []
    @State private var welcome: WelcomeViewModel?

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let welcome { WelcomeView(viewModel: welcome) }
            }
            .navigationDestination(for: Route.self) { route in
                RouteDestination(route: route, store: store, path: $path, onGoToHabits: { _ in onFinished() })
            }
        }
        .onAppear {
            if welcome == nil {
                welcome = WelcomeViewModel(onAddHabit: { path.append(.newHabit) })
            }
        }
    }
}

/// Screens that can be pushed from more than one place.
struct RouteDestination: View {
    let route: Route
    let store: HabitStore
    @Binding var path: [Route]
    /// Called with the habit just created.
    let onGoToHabits: (UUID) -> Void
    /// Called after "Delete all data", so the app can start over.
    var onAllDeleted: () -> Void = {}
    @Environment(\.milestones) private var milestones

    var body: some View {
        switch route {
        case .newHabit:
            NewHabitView(viewModel: NewHabitViewModel(store: store, onStarted: { id in
                // The habit is saved; going back to the form would only make a duplicate.
                path = [.counterRunning(habitId: id)]
            }))
        case .counterRunning(let id):
            CounterView(viewModel: CounterViewModel(habitId: id, store: store, milestones: milestones, onGoToHabits: {
                onGoToHabits(id)
            }))
            .navigationBarBackButtonHidden()
        case .habitDetail(let id):
            HabitDetailView(
                viewModel: HabitDetailViewModel(habitId: id, store: store),
                onEdit: { path.append(.editHabit(habitId: id)) }
            )
        case .editHabit(let id):
            NewHabitView(viewModel: NewHabitViewModel(store: store, editingId: id, onStarted: { _ in
                path.removeLast()
            }))
        case .settings:
            SettingsView(viewModel: SettingsViewModel(store: store, milestones: milestones, onAllDeleted: onAllDeleted))
        }
    }
}
