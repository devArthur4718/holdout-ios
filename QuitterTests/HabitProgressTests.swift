import Foundation
import Testing
@testable import Quitter

struct HabitProgressTests {
    let start = Date(timeIntervalSince1970: 1_795_000_000)

    func habit(cost: Decimal? = Decimal(string: "11.90"), minutes: Int? = 90) -> Habit {
        Habit(id: UUID(), kind: .smoking, name: "Cigarettes", lastDoneAt: start, costPerDay: cost, minutesPerDay: minutes)
    }

    func days(_ d: Double) -> Date { start.addingTimeInterval(d * 86_400) }

    @Test func moneyAndTimeGrowWithElapsedTime() {
        let p = HabitProgress(habit: habit(), now: days(18))
        #expect(p.moneyKept == Decimal(string: "214.2"))
        #expect(p.hoursBack == 27) // 90 min × 18 days = 27 h
    }

    @Test func noCostOrTimeGivesNil() {
        let p = HabitProgress(habit: habit(cost: nil, minutes: nil), now: days(2))
        #expect(p.moneyKept == nil)
        #expect(p.hoursBack == nil)
    }

    @Test func firstTrophyIsOneDay() {
        let p = HabitProgress(habit: habit(), now: days(0.5))
        #expect(p.nextMilestoneDays == 1)
        #expect(p.previousMilestoneDays == 0)
        #expect(p.secondsToNextMilestone == 43_200)
        #expect(abs(p.goalFraction - 0.5) < 0.0001)
    }

    @Test func aPersonalGoalCanComeFirst() {
        let beach = PersonalGoal(id: UUID(), habitId: UUID(), days: 45, name: "Beach trip", createdAt: start)
        let p = HabitProgress(habit: habit(), now: days(31), personalGoals: [beach])
        #expect(p.nextMilestoneDays == 45)
        #expect(p.previousMilestoneDays == 30)
        #expect(p.nextGoalLabel == "Beach trip")
        #expect(abs(p.goalFraction - 31.0 / 45) < 0.0001)
    }

    @Test func progressFillsFromTheQuitMomentNotFromThePreviousGoal() {
        let p = HabitProgress(habit: habit(), now: days(45)) // between 30 and 60
        #expect(p.nextMilestoneDays == 60)
        #expect(p.previousMilestoneDays == 30)
        #expect(abs(p.goalFraction - 0.75) < 0.0001)
    }

    @Test func afterTwoYearsAGoalLandsEveryYear() {
        let p = HabitProgress(habit: habit(), now: days(755))
        #expect(p.nextMilestoneDays == 1095)
        #expect(p.previousMilestoneDays == 730)
    }

    @Test func futureLastDoneCountsAsZero() {
        #expect(HabitProgress(habit: habit(), now: start.addingTimeInterval(-60)).elapsedSeconds == 0)
    }

    @Test func slipBanksTheRunAndKeepsTheLongestStreak() {
        let slipped = habit().afterSlip(at: days(18))
        #expect(slipped.lastDoneAt == days(18))
        #expect(slipped.bestSeconds == 18 * 86_400)
        #expect(slipped.bankedSeconds == 18 * 86_400)

        // A shorter second run keeps the old best.
        let again = slipped.afterSlip(at: days(20))
        #expect(again.bestSeconds == 18 * 86_400)
        #expect(again.bankedSeconds == 20 * 86_400)
    }

    @Test func moneyKeptSurvivesASlip() {
        let p = HabitProgress(habit: habit().afterSlip(at: days(18)), now: days(19))
        #expect(p.elapsedSeconds == 86_400)
        #expect(p.moneyKept == Decimal(string: "226.1")) // 19 clean days × 11.90
        #expect(p.hoursBack == 28) // 90 min × 19 days = 28.5 h
    }

    @Test func personalBestUntilTheCurrentRunOvertakesIt() {
        let slipped = habit().afterSlip(at: days(5))
        let behind = HabitProgress(habit: slipped, now: days(8))
        #expect(!behind.isPersonalBest)
        #expect(behind.bestSeconds == 5 * 86_400)

        let ahead = HabitProgress(habit: slipped, now: days(11))
        #expect(ahead.isPersonalBest)
        #expect(ahead.bestSeconds == 6 * 86_400)
    }

    @Test func noAlcoholTriggerForAnAlcoholHabit() {
        #expect(!SlipTrigger.forKind(.alcohol).contains(.alcohol))
        #expect(SlipTrigger.forKind(.smoking).contains(.alcohol))
    }
}
