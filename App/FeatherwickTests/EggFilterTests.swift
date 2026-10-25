import Testing

@testable import Featherwick

/// The egg filter chips in the Coop sheet: which eggs each one shows. Fertile and clear show only what
/// candling has found out, so an uncandled egg is neither yet.
@Suite struct EggFilterTests {
    typealias Filter = CoopSheet.EggFilter

    /// Every filter against every egg: (candled, fertile) → shown.
    @Test(arguments: [
        (Filter.all, [true, true, true, true]),
        (Filter.fertile, [false, false, false, true]),
        (Filter.clear, [false, false, true, false]),
        (Filter.notCandled, [true, true, false, false]),
    ])
    func eachFilterShowsTheRightEggs(filter: Filter, shown: [Bool]) {
        let eggs = [(false, false), (false, true), (true, false), (true, true)]
        for ((candled, fertile), expected) in zip(eggs, shown) {
            #expect(
                filter.matches(candled: candled, fertile: fertile) == expected,
                "\(filter), candled \(candled), fertile \(fertile)")
        }
    }
}
