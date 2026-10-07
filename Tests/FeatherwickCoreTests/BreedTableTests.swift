import Foundation
import Testing

@testable import FeatherwickCore

/// Every breed table entry, planned ones too, must make real-looking birds that breed true.
struct BreedTableTests {
    static var everyBreedAndVariety: [(BreedDefinition, ColourVariety)] {
        BreedTable.all.flatMap { def in def.varieties.map { (def, $0) } }
    }

    @Test func tableEntriesAreWellFormed() {
        let ids = BreedTable.all.map(\.id)
        #expect(Set(ids).count == ids.count, "duplicate breed id")
        for def in BreedTable.all {
            #expect(!def.varieties.isEmpty, "\(def.id) has no colours")
            #expect((0...1).contains(def.broodiness), "\(def.id) broodiness")
            #expect(def.id.rawValue == def.id.rawValue.lowercased(), "\(def.id) id must be lower case")
            for gene in def.signature + def.varieties.flatMap(\.genes) {
                let locus = Loci.definition(gene.locus)
                #expect(locus != nil, "\(def.id): unknown gene \(gene.locus)")
                #expect(locus.map { $0.isValid(gene.first) && $0.isValid(gene.second) } ?? false)
            }
        }
        #expect(Breed.starters.count == 3, "the player chooses from 3 starter chicks")
        #expect(Breed.starters.allSatisfy { $0.definition.isInGame })
    }

    @Test func geneRegistryIsWellFormed() {
        let ids = Loci.all.map(\.id)
        #expect(Set(ids).count == ids.count, "duplicate gene")
        for locus in Loci.all { #expect(locus.isValid(locus.defaultAllele)) }
    }

    /// Purebred parents of one variety: every chick keeps the breed signature, carries no gene
    /// from outside the breed, and (for hens) lays the breed's egg colour.
    @Test func everyBreedAndVarietyBreedsTrue() throws {
        var rng = SeededRNG(seed: 31)
        for (def, variety) in Self.everyBreedAndVariety {
            let mother = def.id.purebred(.hen, variety: variety)
            let father = def.id.purebred(.rooster, variety: variety)
            let touched = Set((def.signature + def.varieties.flatMap(\.genes)).map(\.locus))
            for _ in 0..<200 {
                let chick = try Breeding.cross(mother: mother, father: father, using: &rng)
                for gene in def.signature {
                    let locus = try #require(Loci.definition(gene.locus))
                    #expect(Set(chick.alleles(at: locus)) == [gene.first], "\(def.id) \(variety.id) lost \(gene.locus)")
                }
                // Shell depth is set for every breed; purebred parents pass on exactly their own.
                let depth = QuantitativeTrait.brownDepth
                #expect(depth.score(chick) == depth.score(mother), "\(def.id) \(variety.id) shell depth drifted")
                let depthLoci = Set(depth.loci.map(\.id))
                for locus in Loci.all where !touched.contains(locus.id) && !depthLoci.contains(locus.id) {
                    #expect(
                        chick.alleles(at: locus).allSatisfy { $0 == locus.defaultAllele },
                        "\(def.id) \(variety.id) chick has stray \(locus.id)")
                }
                let p = Phenotype(chick)
                if chick.sex == .hen { #expect(p.eggColour == def.eggColour) }
                #expect(!(p.isLaced && p.colour != .buff) && !(p.isBarred && p.colour == .buff))
            }
        }
    }

    @Test func plannedBreedsNeverAppearInAGame() {
        let planned = Set(BreedTable.all.filter { !$0.isInGame }.map(\.id))
        #expect(!planned.isEmpty)
        for seed in UInt64(1)...300 {
            var rng = SeededRNG(seed: seed)
            let s = Engine.newGame(using: &rng)
            guard case .choosingStarter(let chicks) = s.phase else {
                Issue.record("no starters")
                return
            }
            #expect(chicks.allSatisfy { !planned.contains($0.breed) })
            for sex in Sex.allCases {
                #expect(!planned.contains(Engine.youngBird(sex, origin: "t", s, &rng).breed))
            }
        }
    }

    @Test func plannedBreedsLookRight() {
        let rock = Phenotype(Breed.plymouthRock.purebred(.hen))
        #expect(rock.isBarred && rock.colour == .black && rock.eggColour == .brown)
        let australorp = Phenotype(Breed.australorp.purebred(.rooster))
        #expect(australorp.colour == .black && !australorp.isBarred && australorp.eggColour == nil)
    }

    @Test func tableReplacesTheOldHardcodedRules() {
        #expect(Breed.silkie.definition.fixes(Feathering.silkie))
        #expect(Breed.wyandotte.definition.fixes(Lacing.laced))
        #expect(Breed.araucana.definition.eggColour == .blue)
        #expect(Breed.orpington.definition.eggColour == .brown)
        #expect(Breed.silkie.definition.eggColour == .cream)
        #expect(Rules.standard.broodyChance[.silkie] == 0.6)
    }

    // MARK: - Saves and unknown data

    @Test func anUnknownBreedLoadsAsAPlaceholder() throws {
        let breed = try JSONDecoder().decode(Breed.self, from: Data("\"dodo\"".utf8))
        #expect(breed.definition.status == .planned)
        #expect(breed.purebred(.hen).sex == .hen)
    }

    @Test func aGeneMissingFromASaveIsTheDefault() throws {
        // As if the save was made before the speckle and lacing genes existed.
        let json = #"{"sex":"hen","autosomal":{"feathering":{"first":"h","second":"h"}},"z":{}}"#
        let g = try JSONDecoder().decode(Genome.self, from: Data(json.utf8))
        #expect(g.feathering.isHomozygous(for: .silkie))
        #expect(g.speckle == .homozygous(.plain) && g.lacing == .homozygous(.solid))
        #expect(
            g
                == {
                    var x = Genome(sex: .hen)
                    x.feathering = .homozygous(.silkie)
                    return x
                }())
    }

    @Test func badAllelesAndUnknownGenesDoNotBreakAGenome() throws {
        let json =
            #"{"sex":"rooster","autosomal":{"blue":{"first":"zz","second":"Bl"},"comb":{"first":"R","second":"r"}},"z":{"barring":["B"]}}"#
        let g = try JSONDecoder().decode(Genome.self, from: Data(json.utf8))
        #expect(g.blue == .homozygous(.notBlue))  // bad allele → default
        #expect(g.zAlleles(Barring.self) == [.plain, .plain])  // wrong copy count → default
        let round = try JSONDecoder().decode(Genome.self, from: JSONEncoder().encode(g))
        #expect(round == g)  // unknown "comb" gene kept, not lost
    }

    @Test func migrationsRunInOrderAndReachObjectsAtAnyDepth() throws {
        let input: [String: Any] = ["a": [["tag": 1], ["b": ["tag": 2]]]]
        let out = try #require(
            SaveFormat.transformObjects(in: input, where: { $0["tag"] != nil }) { $0["seen"] = true } as? [String: Any])
        let a = try #require(out["a"] as? [[String: Any]])
        #expect(a[0]["seen"] as? Bool == true)
        #expect((a[1]["b"] as? [String: Any])?["seen"] as? Bool == true)
        #expect(a[1]["seen"] == nil)

        // A future v1 → v2 step runs after the real v0 → v1 step.
        let v0 = try SaveFormatTests.fixture("save-v0")
        let steps: [Int: SaveFormat.Migration] = [
            0: SaveFormat.migrateGenomesToRegistry,
            1: { root in
                var state = root["state"] as? [String: Any] ?? [:]
                state["coins"] = 999
                root["state"] = state
            },
        ]
        #expect(try SaveFormat.decode(v0, migrations: steps, currentVersion: 2).state.coins == 999)
        #expect(throws: SaveFormat.LoadError.noMigration(from: 1)) {
            try SaveFormat.decode(v0, migrations: [0: SaveFormat.migrateGenomesToRegistry], currentVersion: 2)
        }
    }
}
