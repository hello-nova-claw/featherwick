import Foundation
import Testing

@testable import FeatherwickCore

struct LookTests {
    static let rules = Rules.standard

    static func bird(_ breed: Breed, _ sex: Sex, variety: ColourVariety? = nil, pure: Bool = true) -> Bird {
        var rng = SeededRNG(seed: 1)
        var b = Bird(
            id: makeID(using: &rng), name: "b", breed: breed, genome: breed.purebred(sex, variety: variety),
            hatchDay: 0, origin: "t", revealed: true)
        b.purebredFlag = pure
        return b
    }

    static func look(_ b: Bird, age: Int = 30) -> Look { b.look(onDay: b.hatchDay + age, rules: rules) }

    /// Every bird the genetics can make, at every age, is built only from parts in the kit,
    /// with every mask filled.
    @Test func everyBirdTheGameCanMakeUsesOnlyKitParts() {
        let birds = GeneticsRealismTests.population(
            seed: 21, generations: 4, perGeneration: 1500,
            breeds: BreedTable.all.map(\.id))
        let kit = Set(ArtChecklist.required(includePlanned: true))
        var used: Set<PartKey> = []
        for b in birds {
            for age in [0, Self.rules.growerAge, Self.rules.adultAge, 400] {
                let look = Self.look(b, age: age)
                for placed in look.parts {
                    #expect(kit.contains(placed.part), "not in the kit: \(placed.part)")
                    #expect(Set(placed.fills.keys) == Set(placed.part.masks), "\(placed.part) masks")
                    #expect(placed.scale > 0 && placed.scale <= 1)
                    used.insert(placed.part)
                }
                let masks = Set(look.parts.flatMap { $0.fills.keys })
                for o in look.overlays { #expect(Set(o.masks).isSubset(of: masks)) }
                #expect(look.scale > 0.1 && look.scale < 2)
            }
        }
        #expect(used == kit, "kit parts no bird uses: \(kit.subtracting(used))")
    }

    @Test func theKitIsSmallAndPlannedBreedsNeedNoNewParts() {
        #expect(ArtChecklist.required().count == 21)
        #expect(ArtChecklist.required(includePlanned: true).count == 21)
    }

    @Test func breedsShareParts() {
        let orp = Self.look(Self.bird(.orpington, .hen))
        let aus = Self.look(Self.bird(.australorp, .hen))
        #expect(orp.part(.body)?.part == aus.part(.body)?.part)
        #expect(orp.part(.legs)?.part == Self.look(Self.bird(.araucana, .hen)).part(.legs)?.part)
        #expect(Self.look(Self.bird(.wyandotte, .hen)).part(.comb)?.part.shape == "rose")
        #expect(Self.look(Self.bird(.araucana, .hen)).part(.comb)?.part.shape == "pea")
    }

    @Test func pulletsAndCockerelsAreTheAdultPartsGrowingIn() {
        let hen = Self.bird(.orpington, .hen)
        let rooster = Self.bird(.orpington, .rooster)
        #expect(Self.look(hen, age: 0).parts.map(\.part.slot) == [.chick])
        let pullet = Self.look(hen, age: Self.rules.growerAge)
        let adult = Self.look(hen)
        #expect(pullet.stage == .pullet && adult.stage == .hen)
        #expect(pullet.parts.map(\.part) == adult.parts.map(\.part))
        #expect(pullet.part(.comb)!.scale < adult.part(.comb)!.scale)
        #expect(pullet.part(.tail)!.scale < adult.part(.tail)!.scale)
        let cock = Self.look(rooster)
        #expect(cock.stage == .rooster && cock.part(.tail)?.part.shape == "rooster")
        #expect(cock.part(.comb)!.scale > adult.part(.comb)!.scale)  // same comb drawing, bigger
        #expect(cock.part(.body)?.part.sex == .rooster)
    }

    @Test func coloursAndPatternsComeFromTheGenes() {
        let gold = Self.look(Self.bird(.wyandotte, .hen, variety: .buff))
        #expect(gold.tone(.body) == .buff && gold.tone(.tail) == .black)
        #expect(gold.overlays.map(\.pattern) == [.lacing])
        #expect(Self.look(Self.bird(.wyandotte, .hen)).overlays.isEmpty)  // lacing is hidden on black
        #expect(Self.look(Self.bird(.plymouthRock, .rooster)).overlays.map(\.pattern) == [.barring])
        let blueRooster = Self.look(Self.bird(.orpington, .rooster, variety: .blue))
        #expect(blueRooster.tone(.body) == .blue && blueRooster.tone(.hackle) == .darkBlue)
        let barredChick = Self.look(Self.bird(.plymouthRock, .hen), age: 0)
        #expect(barredChick.tone(.down) == .blackDown && barredChick.overlays.map(\.pattern) == [.headSpot])
    }

    @Test func silkiesAndSilkieCrosses() {
        let silkie = Self.look(Self.bird(.silkie, .hen))
        #expect(silkie.tone(.comb) == .mulberry)
        #expect(
            silkie.parts.map(\.part.description) == [
                "tail/fluffy", "legs/featheredFiveToe", "body/fluffy/hen", "head/crested", "comb/walnut",
            ])
        // A silkie-feathered cross gets the fluffy body (a real gene) but the plain farmyard head, comb and legs.
        var g = Breed.orpington.purebred(.hen)
        g.feathering = .homozygous(.silkie)
        var cross = Bird(id: UUID(), name: "f", breed: .orpington, genome: g, hatchDay: 0, origin: "t")
        cross.purebredFlag = false
        let look = Self.look(cross)
        #expect(look.part(.body)?.part.shape == "fluffy" && look.part(.head)?.part.shape == "plain")
        #expect(Self.look(cross, age: 0).part(.chick)?.part.shape == "fluffy")
    }

    @Test func legColours() {
        #expect(Self.look(Self.bird(.orpington, .hen, variety: .buff)).tone(.legs) == .white)
        #expect(Self.look(Self.bird(.orpington, .hen)).tone(.legs) == .slate)
        #expect(Self.look(Self.bird(.wyandotte, .hen)).tone(.legs) == .yellow)
    }

    @Test func birdsGrowSmoothlyAndRoostersEndBigger() {
        let hen = Self.bird(.orpington, .hen)
        let rooster = Self.bird(.orpington, .rooster)
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
