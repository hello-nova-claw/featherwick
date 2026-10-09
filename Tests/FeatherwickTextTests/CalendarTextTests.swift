import FeatherwickCore
import FeatherwickText
import Foundation
import Testing

/// The village days' words: every event and refusal has words, later years read differently from the
/// first, and nothing names a chick's sex or breed before it shows (rule 8).
struct CalendarTextTests {
    static func game() -> GameState {
        var rng = SeededRNG(seed: 4)
        var s = Engine.newGame(earlyGame: false, using: &rng)
        _ = Engine.apply(.chooseStarter(index: 0, name: "Pip"), to: &s, using: &rng)
        return s
    }

    @Test func yearTwoWordsDifferFromYearOne() {
        var s = Self.game()
        for v in VillageDay.allCases {
            let first = villageDaySceneText(v, year: 0, s)
            let later = villageDaySceneText(v, year: 1, s)
            #expect(!first.isEmpty && !later.isEmpty)
            #expect(first != later, "\(v)")
            #expect(later == villageDaySceneText(v, year: 3, s))
        }
        let note = postNoteText(VillageDay.midwinterNote(year: 0), s)
        let nextNote = postNoteText(VillageDay.midwinterNote(year: 1), s)
        #expect(note != nil && nextNote != nil && note != nextNote)
        // The words are the year the note came, whenever they are read.
        s.day = s.rules.date(of: .midwinterLights, inYear: 2)
        #expect(postNoteText(VillageDay.midwinterNote(year: 0), s) == note)
        #expect(eventText(.noteArrived(.teddy, VillageDay.midwinterNote(year: 0)), s)?.contains("Teddy") == true)
        // Shared words hold no CLI commands.
        for v in VillageDay.allCases {
            #expect(!villageDaySceneText(v, year: 0, s).contains("give egg"))
        }
    }

    @Test func everyCalendarEventAndRefusalHasWords() {
        let s = Self.game()
        let chick = s.brooder[0].id
        var events: [GameEvent] = [
            .hatchAlongEggGiven(returnsOnDay: 12), .hatchAlongChickWaiting, .hatchAlongChickArrived(chick),
            .villageDayGift(.moultWeek, coins: 0, treats: 4), .villageDayGift(.midwinterLights, coins: 15, treats: 0),
        ]
        for v in VillageDay.allCases { events += [.villageDayScene(v, year: 0), .villageDayScene(v, year: 1)] }
        for refusal in [HatchAlongRefusal.notThisWeek, .alreadyGiven, .noFertileEgg] {
            events.append(.rejected(.hatchAlong(refusal)))
        }
        for e in events {
            let words = eventText(e, s) ?? ""
            #expect(!words.isEmpty, "\(e)")
        }
        #expect(eventText(.villageDayGift(.midwinterLights, coins: 15, treats: 0), s)?.contains("15") == true)
    }

    /// Rule 8: the Hatch-along chick's sex and breed do not show yet, so no line names them.
    @Test func theHatchAlongWordsNeverNameTheChicksSexOrBreed() {
        let s = Self.game()
        let lines = [
            eventText(.hatchAlongChickArrived(s.brooder[0].id), s), eventText(.hatchAlongChickWaiting, s),
            eventText(.hatchAlongEggGiven(returnsOnDay: 12), s),
            villageDaySceneText(.hatchAlong, year: 0, s), villageDaySceneText(.hatchAlong, year: 1, s),
        ].compactMap { $0?.lowercased() }
        let words = lines.joined(separator: " ").replacingOccurrences(of: "pip", with: "")
        for sexed in [" he ", " his ", " him ", "pullet", "cockerel", "rooster", " hen ", " roo "] {
            #expect(!words.contains(sexed), "\(sexed)")
        }
        for breed in Breed.starters {
            #expect(!words.contains(breed.definition.displayName.lowercased()), "\(breed)")
        }
    }

    @Test func theCalendarSaysWhatEachDayDoesAndTeddyIsMetByHisDrawing() {
        var s = Self.game()
        let lines = villageCalendarLines(s)
        #expect(lines.count == 4)
        for (line, next) in zip(lines, s.upcomingVillageDays(4)) {
            #expect(line.hasSuffix(villageDayEffectText(next.day)))
        }
        #expect(!hasMet(.teddy, s))
        s.notesSeen.insert(VillageDay.midwinterNote(year: 0))
        #expect(hasMet(.teddy, s))
    }

    @Test func theFarmGateNoticeFollowsTheCalendar() {
        var s = Self.game()
        let date = s.rules.date(of: .longestDay, inYear: 0)
        s.day = date - s.rules.villageDayNoticeDays - 1
        #expect(villageNotice(s) == nil)
        s.day = date - 3
        #expect(villageNotice(s) == "Longest Day in 3 days")
        s.day = date
        #expect(villageNotice(s) == "Longest Day today")
        // The Hatch-along week, with a known-fertile egg to bring.
        var rng = SeededRNG(seed: 1)
        s.day = s.rules.date(of: .hatchAlong, inYear: 1) + 1
        s.coins = 100
        _ = Engine.apply(.buy(.fertileEgg), to: &s, using: &rng)
        #expect(villageNotice(s) == "Hatch-along: bring an egg")
        #expect(hatchAlongLines(s) == ["It's Hatch-along week. Bring \(People.neighbour) an egg you know is fertile."])
    }
}
