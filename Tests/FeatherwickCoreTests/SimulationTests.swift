import Foundation
import Testing

@testable import FeatherwickCore

/// The balance-sim harness: seeded games stay bounded and productive.
/// These are the guards that catch a tuning change making the economy or the flock run away (or die).
struct SimulationTests {
    @Test(arguments: [UInt64(1), 2, 3, 7, 42, 100])
    func gamesStayBoundedAndProductive(seed: UInt64) {
        let r = Simulation.run(seed: seed, days: 180)
        #expect(r.days == 180)
        #expect(r.finalFlock >= 1)  // never-zero-birds invariant holds under real play
        #expect(r.peakFlock <= 100)  // nothing explodes
        #expect(r.finalCoins >= 0)
        #expect(r.finalCoins < 1_000_000)  // the economy doesn't diverge
        #expect(r.eggsLaid > 0)  // the game actually gets somewhere
        #expect(r.chicksHatched > 0)
        #expect(r.breedBook >= 1)
    }

    @Test func reportsAreDeterministic() {
        #expect(Simulation.run(seed: 5, days: 90) == Simulation.run(seed: 5, days: 90))
    }

    @Test func theStandardRulesArePlayable() {
        for seed in UInt64(1)...6 {
            let r = Simulation.run(seed: seed, days: 150, rules: .standard)
            #expect(r.finalFlock >= 1)
            #expect(r.finalCoins >= 0 && r.finalCoins < 1_000_000)
            #expect(r.eggsLaid > 0)
        }
    }

    /// A higher lay chance lays more eggs. Only the lay chance differs between the two runs.
    @Test func aHigherLayChanceLaysMoreEggs() {
        func meanEggs(_ layChance: [Season: Double]) -> Double {
            // Job and goal coins change what the keeper buys, which hides the lay chance. Leave them out.
            var rules = Rules.standard
            rules.layChance = layChance
            rules.jobsRewardCoins = 0
            rules.seasonGoalRewardCoins = 0
            let xs = Simulation.runMany(seeds: 1...12, days: 150, rules: rules).map { Double($0.eggsLaid) }
            return xs.reduce(0, +) / Double(xs.count)
        }
        // A higher lay chance should show up as more eggs over the same games.
        // (Final coins is a poor signal here: the keeper reinvests its coins into stock and upgrades.)
        let high: [Season: Double] = [.spring: 0.95, .summer: 0.9, .autumn: 0.6, .winter: 0.7]
        let low: [Season: Double] = [.spring: 0.75, .summer: 0.65, .autumn: 0.25, .winter: 0.3]
        #expect(meanEggs(high) > meanEggs(low))
    }

    /// The market board is a top-up, not the economy: a keeper who fills every card it can ends with
    /// more coins, but not wildly more than a keeper with no board. Much of the gap is spare adults: the
    /// sim keeper gives them to bird cards, and keeps them (for no coins) when there is no board.
    @Test func theMarketBoardTopsUpCoinsWithoutTakingOver() {
        // No wanted cards. (Moving the board's day is not enough: Mr Okafor's note opens it early.)
        var off = Rules.standard
        off.marketCardsMin = 0
        off.marketCardsMax = 0
        func mean(_ rules: Rules, _ f: (Simulation.Report) -> Int) -> Double {
            let xs = Simulation.runMany(seeds: 1...6, days: 180, rules: rules).map { Double(f($0)) }
            return xs.reduce(0, +) / Double(xs.count)
        }
        let without = mean(off, \.finalCoins)
        let with = mean(.standard, \.finalCoins)
        #expect(mean(off, \.coinsFromMarket) == 0)
        #expect(mean(.standard, \.coinsFromMarket) > 0)
        #expect(with > without)
        #expect(with < without * 1.75)
    }

    @Test func textReportRuns() {
        let report = Simulation.textReport(days: 60, games: 5)
        #expect(report.contains("Balance report"))
        #expect(report.contains("coins"))
        #expect(report.contains("speckledEgg"))  // the ladder line names every milestone
    }

    /// Issue #64: rungs the shipped breeds could not reach. A plain keeper, with no eye for genes, gets a
    /// speckled egg in some games of a year, and keeps a hen long enough for "Grand old lady" in most.
    @Test func aYearOfPlayClimbsTheOnceUnreachableRungs() {
        let reports = Simulation.runMany(seeds: 1...10, days: 365)
        #expect(reports.contains { $0.milestones.contains("speckledEgg") })
        #expect(reports.count(where: { $0.milestones.contains("elderHen") }) >= 5)
    }
}
