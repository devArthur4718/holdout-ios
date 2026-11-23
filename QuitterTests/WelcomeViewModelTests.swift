import Testing
@testable import Quitter

@MainActor
struct WelcomeViewModelTests {

    @Test func listsTheThreeBenefitsInOrder() {
        let vm = WelcomeViewModel()
        #expect(vm.benefits.map(\.id) == ["savings", "trophies", "free"])
    }

    @Test func addHabitTappedCallsNavigation() {
        var called = false
        let vm = WelcomeViewModel(onAddHabit: { called = true })
        vm.addHabitTapped()
        #expect(called)
    }
}
