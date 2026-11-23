import SwiftUI

/// The app after onboarding: Habits, Rewards, Trophies and Insights.
struct MainTabView: View {
    let store: HabitStore
    var onAllDeleted: () -> Void = {}

    @State private var homePath: [Route] = []
    @State private var home: HomeViewModel?

    var body: some View {
        TabView {
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
            .tabItem { Label("Habits", systemImage: "checkmark.circle") }

            placeholderTab("Rewards", title: "Rewards", symbol: "gift")
            placeholderTab("Trophies", title: "Trophy room", symbol: "trophy")
            placeholderTab("Insights", title: "Insights", symbol: "chart.line.uptrend.xyaxis")
        }
        .onAppear {
            guard home == nil else { return }
            home = HomeViewModel(store: store, actions: .init(
                addHabit: { homePath.append(.newHabit) },
                openDetail: { homePath.append(.habitDetail(habitId: $0)) },
                checkIn: { homePath.append(.comingSoon("Evening check-in")) },
                settings: { homePath.append(.settings) }
            ))
        }
    }

    private func placeholderTab(_ label: LocalizedStringKey, title: LocalizedStringKey, symbol: String) -> some View {
        NavigationStack { PlaceholderView(title: title) }
            .tabItem { Label(label, systemImage: symbol) }
    }
}
