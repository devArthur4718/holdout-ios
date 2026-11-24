import SwiftUI

/// The app after onboarding: Today, Trophies and Insights.
struct MainTabView: View {
    let store: HabitStore
    var onAllDeleted: () -> Void = {}

    private enum Tab { case today, trophies, insights }

    @State private var tab = Tab.today
    @State private var homePath: [Route] = []
    @State private var home: HomeViewModel?
    @State private var trophies: TrophiesViewModel?
    @State private var insights: InsightsViewModel?

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

            NavigationStack {
                if let insights { InsightsView(viewModel: insights, onAddHabit: addHabit) }
            }
            .tabItem { Label("Insights", systemImage: "chart.bar") }
            .tag(Tab.insights)
        }
        .onAppear {
            guard home == nil else { return }
            let selection = HabitSelection()
            trophies = TrophiesViewModel(store: store, selection: selection)
            insights = InsightsViewModel(store: store, selection: selection)
            home = HomeViewModel(store: store, actions: .init(
                addHabit: { homePath.append(.newHabit) },
                openDetail: { homePath.append(.habitDetail(habitId: $0)) },
                settings: { homePath.append(.settings) }
            ))
        }
    }

    /// From an empty Trophies or Insights tab: back to Today, on the New habit form.
    private func addHabit() {
        tab = .today
        homePath = [.newHabit]
    }
}
