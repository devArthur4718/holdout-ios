import Foundation
import Testing
@testable import Holdout

struct GoalsTests {
    let en = Locale(identifier: "en_US")
    let pt = Locale(identifier: "pt_BR")
    let es = Locale(identifier: "es_ES")

    func seconds(days: Int, hours: Int = 0, minutes: Int = 0, seconds: Int = 0) -> Int {
        days * 86_400 + hours * 3_600 + minutes * 60 + seconds
    }

    @Test(arguments: [(0, 1), (1, 7), (6, 7), (7, 30), (29, 30), (30, 60), (59, 60), (60, 90), (90, 180), (180, 365),
                      (365, 545), (545, 730), (729, 730), (730, 1095), (755, 1095), (1095, 1460), (9_999, 10_220)])
    func nextGoalIsTheFirstStepAfterTheDays(days: Int, expected: Int) {
        #expect(Goals.next(afterDays: days) == expected)
    }

    @Test(arguments: [(0, 0), (1, 1), (6, 1), (7, 7), (29, 7), (30, 30), (544, 365), (545, 545), (729, 545), (730, 730), (755, 730), (1_100, 1_095)])
    func previousGoalIsTheLastStepReached(days: Int, expected: Int) {
        #expect(Goals.previous(atDays: days) == expected)
    }

    @Test func fractionFillsFromTheQuitMoment() {
        #expect(Goals.fraction(elapsedSeconds: 0) == 0)
        #expect(Goals.fraction(elapsedSeconds: -50) == 0)
        #expect(abs(Goals.fraction(elapsedSeconds: seconds(days: 3, hours: 12)) - 0.5) < 0.0001)
        // 755 days of 1095: 68.9%.
        #expect(abs(Goals.fraction(elapsedSeconds: seconds(days: 755)) - 755.0 / 1095) < 0.0001)
        // Right on a goal, the next one starts.
        #expect(abs(Goals.fraction(elapsedSeconds: seconds(days: 7)) - 7.0 / 30) < 0.0001)
    }

    @Test func labelsInEnglish() {
        let labels = [1, 7, 30, 60, 90, 180, 365, 545, 730, 1095].map { Goals.label(days: $0, locale: en) }
        #expect(labels == ["1 day", "1 week", "30 days", "60 days", "90 days", "6 months", "1 year", "1½ years", "2 years", "3 years"])
    }

    @Test func labelsInPortuguese() {
        let labels = [1, 7, 30, 60, 90, 180, 365, 545, 730, 1095].map { Goals.label(days: $0, locale: pt) }
        #expect(labels == ["1 dia", "1 semana", "30 dias", "60 dias", "90 dias", "6 meses", "1 ano", "1 ano e meio", "2 anos", "3 anos"])
    }

    @Test func labelsInSpanish() {
        let labels = [1, 7, 30, 60, 90, 180, 365, 545, 730, 1095].map { Goals.label(days: $0, locale: es) }
        #expect(labels == ["1 día", "1 semana", "30 días", "60 días", "90 días", "6 meses", "1 año", "1 año y medio", "2 años", "3 años"])
    }

    @Test func underADayTheArcShowsAClock() {
        let text = ArcText(elapsedSeconds: seconds(days: 0, hours: 5, minutes: 7, seconds: 9), locale: en)
        #expect(text.big == "05:07:09")
        #expect(text.unit == nil)
        #expect(text.detail == nil)
        #expect(text.progress == "21% of the way to 1 day")
        #expect(text.goal == "1 day")
    }

    @Test func afterADayTheArcShowsDays() {
        let text = ArcText(elapsedSeconds: seconds(days: 755, hours: 13, minutes: 36, seconds: 20), locale: en)
        #expect(text.big == "755")
        #expect(text.unit == "days")
        #expect(text.detail == "13 h 36 min")
        #expect(text.progress == "69% of the way to 3 years")
        #expect(text.accessibility == "755 days, 13 hours and 36 minutes. 69% of the way to 3 years.")
    }

    @Test func oneDayIsSingular() {
        #expect(ArcText(elapsedSeconds: seconds(days: 1), locale: en).unit == "day")
        #expect(ArcText(elapsedSeconds: seconds(days: 1), locale: pt).unit == "dia")
        #expect(ArcText(elapsedSeconds: seconds(days: 1), locale: es).unit == "día")
    }

    @Test func theArcIsTranslated() {
        let t = seconds(days: 755, hours: 13, minutes: 36)
        let portuguese = ArcText(elapsedSeconds: t, locale: pt)
        #expect(portuguese.unit == "dias")
        #expect(portuguese.progress == "69% do caminho até 3 anos")
        let spanish = ArcText(elapsedSeconds: t, locale: es)
        #expect(spanish.unit == "días")
        #expect(spanish.progress == "69\u{00A0}% del camino hacia 3 años")
    }

    @Test func voiceOverJoinsTheTimeWithAnd() {
        #expect(ArcText(elapsedSeconds: seconds(days: 0, hours: 2, minutes: 5, seconds: 30), locale: en).accessibility
            == "2 hours and 5 minutes. 8% of the way to 1 day.")
        #expect(ArcText(elapsedSeconds: seconds(days: 0, minutes: 4, seconds: 10), locale: en).accessibility
            == "4 minutes and 10 seconds. 0% of the way to 1 day.")
        #expect(ArcText(elapsedSeconds: seconds(days: 1, minutes: 1), locale: en).accessibility
            == "1 day, 0 hours and 1 minute. 14% of the way to 1 week.")
        let t = seconds(days: 755, hours: 13, minutes: 36)
        #expect(ArcText(elapsedSeconds: t, locale: pt).accessibility == "755 dias, 13 horas e 36 minutos. 69% do caminho até 3 anos.")
        #expect(ArcText(elapsedSeconds: t, locale: es).accessibility == "755 días, 13 horas y 36 minutos. 69\u{00A0}% del camino hacia 3 años.")
    }

    @Test func theBigNumberIsGroupedButReadUngrouped() {
        let t = seconds(days: 9_999)
        #expect(ArcText(elapsedSeconds: t, locale: en).big == "9,999")
        #expect(ArcText(elapsedSeconds: t, locale: pt).big == "9.999")
        #expect(ArcText(elapsedSeconds: t, locale: es).big == "9.999")
        #expect(ArcText(elapsedSeconds: seconds(days: 999), locale: es).big == "999")
        #expect(ArcText(elapsedSeconds: seconds(days: 12_345), locale: en).big == "12,345")
        #expect(ArcText(elapsedSeconds: t, locale: en).accessibility.hasPrefix("9999 days, 0 hours and 0 minutes."))
        // Portuguese treats 0 as singular (CLDR), as Android's plurals do.
        #expect(ArcText(elapsedSeconds: t, locale: pt).accessibility.hasPrefix("9999 dias, 0 hora e 0 minuto."))
    }

    @Test func theMinutesLimitIsGroupedInEveryLanguage() {
        #expect(ArcText.grouped(1_440, locale: en) == "1,440")
        #expect(ArcText.grouped(1_440, locale: pt) == "1.440")
        #expect(ArcText.grouped(1_440, locale: es) == "1.440")
    }

    @Test func percentIsWholeIntegerMaths() {
        // 0.29 × 100 is 28.999… in floating point; integer maths says 29.
        let goal = 7 * 86_400
        #expect(ArcText(elapsedSeconds: goal * 29 / 100, locale: en).progress == "29% of the way to 1 week")
    }

    @Test func percentNeverRoundsUpToTheGoal() {
        #expect(ArcText(elapsedSeconds: seconds(days: 6, hours: 23, minutes: 59), locale: en).progress == "99% of the way to 1 week")
    }
}
