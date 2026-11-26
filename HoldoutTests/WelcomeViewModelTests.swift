import Testing
@testable import Holdout

@MainActor
struct WelcomeViewModelTests {

    @Test func listsTheThreeBenefitsInOrder() {
        let vm = WelcomeViewModel()
        #expect(vm.benefits.map(\.id) == ["trophies", "free"])
    }

    @Test func addHabitTappedCallsNavigation() {
        var called = false
        let vm = WelcomeViewModel(onAddHabit: { called = true })
        vm.addHabitTapped()
        #expect(called)
    }
}
