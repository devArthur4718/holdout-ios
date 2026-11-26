import SwiftUI

/// The app after onboarding: Today and Trophies.
struct MainTabView: View {
    let store: HabitStore
    var onAllDeleted: () -> Void = {}

    private enum Tab { case today, trophies }

    @State private var tab = Tab.today
    @State private var homePath: [Route] = []
    @State private var home: HomeViewModel?
    @State private var trophies: TrophiesViewModel?

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack(path: $homePath) {
                Group {
                    if let home { HomeView(viewModel: home) }
                }
                .navigationDestination(for: Route.self) { route in
                    RouteDestination(route: route, store: store, path: $homePath, onGoToHabits: { id in
                        homePath = []
                        home?.reload()
                        home?.select(id)
                    }, onAllDeleted: onAllDeleted)
                }
            }
            .tabItem { Label("Today", systemImage: "checkmark.circle") }
            .tag(Tab.today)

            NavigationStack {
                if let trophies { TrophiesView(viewModel: trophies, onAddHabit: addHabit) }
            }
            .tabItem { Label("Trophies", systemImage: "trophy") }
            .tag(Tab.trophies)
        }
        .onAppear {
            guard home == nil else { return }
            let selection = HabitSelection()
            trophies = TrophiesViewModel(store: store, selection: selection)
            home = HomeViewModel(store: store, actions: .init(
                addHabit: { homePath.append(.newHabit) },
                openDetail: { homePath.append(.habitDetail(habitId: $0)) },
                settings: { homePath.append(.settings) }
            ))
        }
    }

    /// From an empty Trophies tab: back to Today, on the New habit form.
    private func addHabit() {
        tab = .today
        homePath = [.newHabit]
    }
}
