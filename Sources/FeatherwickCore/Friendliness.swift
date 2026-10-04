// Friendliness: how much a bird trusts people.
//
// Two parts, as in real chickens:
//   - temperament (40%): the calm genes, inherited, and stronger in calm breeds
//   - tameness (60%): learned. Handling and treats raise it, fastest in the first weeks of life.
//     A fright from the fox and time lost lower it.
//
// Cozy rules: tameness never drops from neglect, only from frights and time lost.
// No gaming: handling and treats count once a day per bird, gains shrink as a bird gets tamer,
// and the score can never pass 1.

public enum Friendliness: String, Hashable, Codable, Sendable, CaseOrdered {
    case wild, skittish, friendly, lapChicken

    public init(_ score: Double) {
        self = score >= 0.75 ? .lapChicken : score >= 0.5 ? .friendly : score >= 0.25 ? .skittish : .wild
    }
}

extension Bird {
    /// Tameness for a bird from before this trait existed.
    public static let defaultTameness = 0.3

    public var currentTameness: Double { tameness ?? Bird.defaultTameness }

    /// 0...1. 40% temperament genes, 60% learned tameness.
    public var friendlinessScore: Double {
        0.4 * QuantitativeTrait.calm.fraction(genome) + 0.6 * currentTameness
    }

    public var friendliness: Friendliness { Friendliness(friendlinessScore) }

    func withTameness(_ value: Double) -> Bird {
        var copy = self
        copy.tameness = value
        return copy
    }

    mutating func changeTameness(by delta: Double) {
        tameness = min(1, max(0, currentTameness + delta))
    }
}

/// How handling and treats change a bird.
public enum Handling: String, Hashable, Codable, Sendable {
    case pet, treat

    /// Tameness gained, before the once-a-day check.
    /// Chicks learn fastest. A mother hen keeps her chicks wary of people, so they learn at half speed.
    static func gain(_ kind: Handling, for bird: Bird, withMotherHen: Bool, day: Int, rules r: Rules) -> Double {
        let base = kind == .pet ? r.petTamenessGain : r.treatTamenessGain
        let stage =
            switch bird.stage(onDay: day, rules: r) {
            case .chick: r.chickHandlingBoost
            case .grower: r.growerHandlingBoost
            case .adult: 1.0
            }
        let mother = withMotherHen ? r.motherHenHandlingFactor : 1
        return base * stage * mother * (1 - bird.currentTameness)
    }
}
