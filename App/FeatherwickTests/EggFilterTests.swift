import Testing

@testable import Featherwick

/// The egg filter chips in the Coop sheet: which eggs each one shows.
@Suite struct EggFilterTests {
    @Test func allShowsEveryEgg() {
        for candled in [false, true] {
            for fertile in [false, true] {
                #expect(CoopSheet.EggFilter.all.matches(candled: candled, fertile: fertile))
            }
        }
    }

    /// Fertile and clear show only what candling has found out; an uncandled egg is neither yet.
    @Test func fertileAndClearShowOnlyCandledEggs() {
        #expect(CoopSheet.EggFilter.fertile.matches(candled: true, fertile: true))
        #expect(!CoopSheet.EggFilter.fertile.matches(candled: true, fertile: false))
        #expect(!CoopSheet.EggFilter.fertile.matches(candled: false, fertile: true))
        #expect(CoopSheet.EggFilter.clear.matches(candled: true, fertile: false))
        #expect(!CoopSheet.EggFilter.clear.matches(candled: true, fertile: true))
        #expect(!CoopSheet.EggFilter.clear.matches(candled: false, fertile: false))
    }

    @Test func notCandledShowsEggsWaitingForTheLamp() {
        #expect(CoopSheet.EggFilter.notCandled.matches(candled: false, fertile: true))
        #expect(CoopSheet.EggFilter.notCandled.matches(candled: false, fertile: false))
        #expect(!CoopSheet.EggFilter.notCandled.matches(candled: true, fertile: true))
    }
}
