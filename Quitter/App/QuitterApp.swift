import SwiftData
import SwiftUI
import UserNotifications

@main
struct QuitterApp: App {
    /// UI tests launch with `-uiTesting` to start from an empty, throwaway database.
    private let container = ModelContainer.quitter(
        inMemory: ProcessInfo.processInfo.arguments.contains("-uiTesting")
    )

    private let store: SwiftDataHabitStore
    private let milestones: MilestoneNotifier
    private let foregroundNotifications = ForegroundNotifications()

    init() {
        store = SwiftDataHabitStore(container: container)
        milestones = MilestoneNotifier(store: store)
        UNUserNotificationCenter.current().delegate = foregroundNotifications
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
                .environment(\.milestones, milestones)
                .onScenePhaseActive { milestones.reschedule() }
        }
        .modelContainer(container)
    }
}

enum Route: Hashable {
    case newHabit
    case counterRunning(habitId: UUID)
    case habitDetail(habitId: UUID)
    case editHabit(habitId: UUID)
    case settings
    /// A screen that isn't built yet, by title.
    case comingSoon(String)
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
        case .comingSoon(let title):
            ComingSoonView(title: title)
        }
    }
}
