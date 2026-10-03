import FeatherwickCore

// Genetics demo. Usage: swift run featherwick [seed]
// The full command loop (look, feed, collect, pair, pass night) comes next.

let seed = CommandLine.arguments.dropFirst().first.flatMap { UInt64($0) } ?? 1
var rng = SeededRNG(seed: seed)

let clover = Bird(name: "Clover", breed: .araucana, genome: Breed.araucana.purebred(.hen))
let duke = Bird(name: "Duke", breed: .orpington, genome: Breed.orpington.purebred(.rooster, colour: .blue))

print("Featherwick genetics demo · seed \(seed)")
print("Mother  \(clover.name) (\(clover.breed.rawValue)): \(clover.phenotype.summary)")
print("Father  \(duke.name) (\(duke.breed.rawValue)): \(duke.phenotype.summary)")
print("")

for i in 1...8 {
    let chick = try Breeding.hatch(mother: clover, father: duke, name: "Chick \(i)", using: &rng)
    print("\(chick.name): \(chick.phenotype.summary)")
}
