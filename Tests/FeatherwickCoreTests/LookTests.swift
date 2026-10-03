import Foundation
import Testing
@testable import FeatherwickCore

struct LookTests {
    static let rules = Rules.standard

    static func bird(_ breed: Breed, _ sex: Sex, variety: ColourVariety? = nil, age: Int = 30, pure: Bool = true) -> Bird {
        var rng = SeededRNG(seed: 1)
        var b = Bird(id: makeID(using: &rng), name: "b", breed: breed, genome: breed.purebred(sex, variety: variety),
                     hatchDay: 0, origin: "t", revealed: true)
        b.purebredFlag = pure
        return b
    }

    static func look(_ b: Bird, age: Int = 30) -> Look { b.look(onDay: b.hatchDay + age, rules: rules) }

    /// Every bird the genetics can make, at every age, has a complete, drawable look.
    @Test func everyBirdTheGameCanMakeIsDrawable() {
        let birds = GeneticsRealismTests.population(seed: 21, generations: 4, perGeneration: 1500,
                                                    breeds: BreedTable.all.map(\.id))
        let drawings = Set(ArtChecklist.required(includePlanned: true))
        for b in birds {
            for age in [0, Self.rules.growerAge, Self.rules.adultAge, 400] {
                let look = Self.look(b, age: age)
                #expect(drawings.contains(look.art), "no drawing \(look.art)")
                #expect(Set(look.fills.keys) == Set(look.art.stage.masks), "\(look.art) masks")
                for o in look.overlays { #expect(Set(o.masks).isSubset(of: look.fills.keys)) }
                #expect(look.scale > 0.1 && look.scale < 2)
            }
        }
    }

    @Test func theArtChecklistIsSmall() {
        // 4 in-game families + "mixed", 5 stages each.
        #expect(ArtChecklist.required().count == 25)
        #expect(ArtChecklist.required(includePlanned: true).count == 35)
    }

    @Test func stagesPickTheRightDrawing() {
        let hen = Self.bird(.orpington, .hen), rooster = Self.bird(.orpington, .rooster)
        #expect(Self.look(hen, age: 0).art.stage == .chick)
        #expect(Self.look(rooster, age: 0).art.stage == .chick)
        #expect(Self.look(hen, age: Self.rules.growerAge).art.stage == .pullet)
        #expect(Self.look(rooster, age: Self.rules.growerAge).art.stage == .cockerel)
        #expect(Self.look(hen).art == ArtKey(family: "orpington", stage: .hen))
        #expect(Self.look(rooster).art.stage == .rooster)
    }

    @Test func coloursAndPatternsComeFromTheGenes() {
        let gold = Self.look(Self.bird(.wyandotte, .hen, variety: .buff))
        #expect(gold.fills[.body] == .buff && gold.fills[.tail] == .black)
        #expect(gold.overlays.map(\.pattern) == [.lacing])
        let blackWyandotte = Self.look(Self.bird(.wyandotte, .hen))
        #expect(blackWyandotte.overlays.isEmpty)  // lacing is hidden on black
        let rock = Self.look(Self.bird(.plymouthRock, .rooster))
        #expect(rock.overlays.map(\.pattern) == [.barring])
        let blueRooster = Self.look(Self.bird(.orpington, .rooster, variety: .blue))
        #expect(blueRooster.fills[.body] == .blue && blueRooster.fills[.hackle] == .darkBlue)
        let barredChick = Self.look(Self.bird(.plymouthRock, .hen), age: 0)
        #expect(barredChick.fills[.down] == .blackDown && barredChick.overlays.map(\.pattern) == [.headSpot])
    }

    @Test func breedDetails() {
        let silkie = Self.look(Self.bird(.silkie, .hen))
        #expect(silkie.fills[.comb] == .mulberry && silkie.art.family == "silkie")
        #expect(Self.look(Self.bird(.orpington, .hen, variety: .buff)).fills[.legs] == .white)
        #expect(Self.look(Self.bird(.orpington, .hen)).fills[.legs] == .slate)
    }

    @Test func crossesUseTheMixedDrawingsUnlessSilkieFeathered() {
        let cross = Self.bird(.araucana, .hen, pure: false)
        #expect(Self.look(cross).art.family == "mixed")
        var g = Breed.orpington.purebred(.hen)
        g.feathering = .homozygous(.silkie)
        var fluffy = Bird(id: UUID(), name: "f", breed: .orpington, genome: g, hatchDay: 0, origin: "t")
        fluffy.purebredFlag = false
        #expect(Self.look(fluffy).art.family == "silkie")
    }

    @Test func birdsGrowSmoothlyAndRoostersEndBigger() {
        let hen = Self.bird(.orpington, .hen), rooster = Self.bird(.orpington, .rooster)
        var last = 0.0
        for age in 0...Self.rules.adultAge + 5 {
            let s = Self.look(hen, age: age).scale
            #expect(s >= last)
            last = s
        }
        #expect(abs(Self.look(hen).scale - 1.2) < 1e-9)
        #expect(abs(Self.look(rooster).scale - 1.44) < 1e-9)
        #expect(Self.look(Self.bird(.silkie, .hen)).scale < Self.look(Self.bird(.araucana, .hen)).scale)
    }
}
