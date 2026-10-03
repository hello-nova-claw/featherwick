import Foundation

/// A deterministic version-4 UUID drawn from the game RNG.
///
/// IDs are global (ready for trading later) but still replayable from a seed.
func makeID<R: RandomNumberGenerator>(using rng: inout R) -> UUID {
    var bytes = [UInt8](repeating: 0, count: 16)
    for half in 0..<2 {
        var value = rng.next()
        for i in 0..<8 {
            bytes[half * 8 + i] = UInt8(truncatingIfNeeded: value)
            value >>= 8
        }
    }
    bytes[6] = (bytes[6] & 0x0F) | 0x40  // version 4
    bytes[8] = (bytes[8] & 0x3F) | 0x80  // RFC 4122 variant
    return UUID(uuid: (
        bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
        bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
    ))
}

extension Double {
    /// A roll in 0..<1. True with the given chance.
    static func roll<R: RandomNumberGenerator>(_ chance: Double, using rng: inout R) -> Bool {
        Double.random(in: 0..<1, using: &rng) < chance
    }
}
