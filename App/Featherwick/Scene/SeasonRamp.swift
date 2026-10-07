import FeatherwickCore
import SwiftUI

/// The scene's colours. Art is drawn in value (light and dark) and material (sky, grass, leaves);
/// the `seasonRamp` shader (`SeasonRamp.metal`) maps each value along the ramp of its material for
/// the season. So one painting serves every season and the night, and each tree can tint its own leaves.
///
/// Placeholder art, so these colours are not palette tokens: they are the scene's paint.
struct SeasonRamp {
    /// Four colour stops, dark to light, evenly spaced along the value.
    let stops: [UInt32]

    /// Which four ramps the shader picks from. Material bits in the art's G and B channels choose one.
    enum MaterialSet: Float {
        /// G B: 0 0 sky, 1 0 far hill, 1 1 grass, 0 1 pond. The landscape PNGs and the grass tufts.
        case land = 0
        /// G B: 0 0 leaves, 1 0 trunk, 1 1 evergreen, 0 1 leaves. Drawn trees.
        case trees = 1
    }

    /// The colour a shape fills with so the shader reads it as `material` at `value` (0 dark ... 1 light).
    /// Not shown as is: the shader replaces it.
    static func paint(_ material: Material, value: Double) -> Color {
        let bits: (g: Double, b: Double) = material.bits
        return Color(red: value, green: bits.g, blue: bits.b)
    }

    /// A material, with its bits in the art's G and B channels. Neighbours differ in one bit,
    /// so a soft edge between them never blends in a third material.
    enum Material {
        case sky, farHill, grass, pond
        case leaves, trunk, evergreen

        var bits: (g: Double, b: Double) {
            switch self {
            case .sky, .leaves: (g: 0, b: 0)
            case .farHill, .trunk: (g: 1, b: 0)
            case .grass, .evergreen: (g: 1, b: 1)
            case .pond: (g: 0, b: 1)
            }
        }
    }

    /// The ramps for one season, as the shader reads them: the land set, then the tree set, in bit
    /// order (00, 10, 11, 01). 4 stops × 3 floats per ramp. Made once per season, not per draw.
    static func floats(for season: Season) -> [Float] {
        packed[season] ?? []
    }

    private static let packed: [Season: [Float]] = Dictionary(
        uniqueKeysWithValues: Season.allCases.map { ($0, pack(ramps(for: $0))) })

    private static func pack(_ r: Ramps) -> [Float] {
        let order: [SeasonRamp] = [r.sky, r.farHill, r.grass, r.pond, r.leaves, r.trunk, r.evergreen, r.leaves]
        var out: [Float] = []
        out.reserveCapacity(order.count * 12)
        for ramp in order {
            for hex in ramp.stops {
                out.append(Float((hex >> 16) & 0xFF) / 255)
                out.append(Float((hex >> 8) & 0xFF) / 255)
                out.append(Float(hex & 0xFF) / 255)
            }
        }
        return out
    }

    /// The shader for one draw. `hueShift` is in radians and turns tree leaves only.
    static func shader(season: Season, set: MaterialSet, hueShift: Double = 0, night: Bool) -> Shader {
        let dark: Float = night ? 1 : 0
        return ShaderLibrary.seasonRamp(
            .floatArray(floats(for: season)), .float(set.rawValue), .float(Float(hueShift)), .float(dark))
    }

    /// Every ramp of one season.
    struct Ramps {
        let sky, farHill, grass, pond, leaves, trunk, evergreen: SeasonRamp
    }

    /// Spring is fresh green, summer deep green, autumn gold grass under red trees, winter pale.
    static func ramps(for season: Season) -> Ramps {
        switch season {
        case .spring: spring
        case .summer: summer
        case .autumn: autumn
        case .winter: winter
        }
    }

    private static let trunk = SeasonRamp(stops: [0x3F2E23, 0x5E4535, 0x82654E, 0xA88A6E])

    static let spring = Ramps(
        sky: SeasonRamp(stops: [0x8DB4D6, 0xB0CDE4, 0xD3E4EF, 0xF4F6F0]),
        farHill: SeasonRamp(stops: [0x6E8F86, 0x8DAC9C, 0xADC6B2, 0xD0DEC8]),
        grass: SeasonRamp(stops: [0x4F7A34, 0x74A345, 0x9CC660, 0xCDE38F]),
        pond: SeasonRamp(stops: [0x2F5868, 0x4F7E8E, 0x82AAB3, 0xC8E0E0]),
        leaves: SeasonRamp(stops: [0x4C7A30, 0x76A643, 0xA2C964, 0xD6EBA0]),
        trunk: trunk,
        evergreen: SeasonRamp(stops: [0x22402F, 0x355A45, 0x4D785B, 0x76997A]))

    static let summer = Ramps(
        sky: SeasonRamp(stops: [0x7FA6C9, 0xA3C3DD, 0xC9DCEA, 0xEEF3F2]),
        farHill: SeasonRamp(stops: [0x5E7F7A, 0x7F9E92, 0xA2BBAA, 0xC8D6C4]),
        grass: SeasonRamp(stops: [0x3E5F2E, 0x5F8A3C, 0x86AE55, 0xB5CF7E]),
        pond: SeasonRamp(stops: [0x2F5566, 0x4D7A8A, 0x7FA6B0, 0xC4DCDD]),
        leaves: SeasonRamp(stops: [0x2E4A26, 0x4A6E32, 0x6E9443, 0x9DBC66]),
        trunk: trunk,
        evergreen: SeasonRamp(stops: [0x1F3A2C, 0x2F5240, 0x456E55, 0x6A8F72]))

    static let autumn = Ramps(
        sky: SeasonRamp(stops: [0x8E9FB3, 0xB2BFC9, 0xD4D7D2, 0xF0E8D8]),
        farHill: SeasonRamp(stops: [0x7A7A68, 0x99957A, 0xB7AF92, 0xD5CDB0]),
        grass: SeasonRamp(stops: [0x6B6230, 0x9A8B3E, 0xC4AF5A, 0xE4D28C]),
        pond: SeasonRamp(stops: [0x34505A, 0x56727A, 0x8299A0, 0xC2D0CF]),
        leaves: SeasonRamp(stops: [0x6E2A1A, 0xA84321, 0xD9752E, 0xF0B04C]),
        trunk: trunk,
        evergreen: SeasonRamp(stops: [0x23392C, 0x37503F, 0x506B55, 0x788F74]))

    static let winter = Ramps(
        sky: SeasonRamp(stops: [0x9AA8B8, 0xBCC6D0, 0xDCE1E6, 0xF6F7F8]),
        farHill: SeasonRamp(stops: [0x8E98A0, 0xAEB6BC, 0xCDD2D6, 0xEAEDEF]),
        grass: SeasonRamp(stops: [0x7D8574, 0xA3A898, 0xC8CBBF, 0xE9EBE4]),
        pond: SeasonRamp(stops: [0x5E7584, 0x8399A6, 0xB0C2CC, 0xE2EBEF]),
        leaves: SeasonRamp(stops: [0x6A6058, 0x8A8078, 0xAAA198, 0xCCC5BD]),
        trunk: trunk,
        evergreen: SeasonRamp(stops: [0x2C4236, 0x3F5A4B, 0x5C7766, 0x8EA597]))
}

extension View {
    /// Colours value-and-material art through the season ramp (`SeasonRamp`), with the night tint.
    func seasonRamp(_ season: Season, set: SeasonRamp.MaterialSet, hueShift: Double = 0, night: Bool) -> some View {
        colorEffect(SeasonRamp.shader(season: season, set: set, hueShift: hueShift, night: night))
    }
}
