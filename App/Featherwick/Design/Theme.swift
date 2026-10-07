import CoreText
import FeatherwickCore
import SwiftUI

// Design tokens from the Featherwick UI system (design handoff v4).
// White paper, ink, small dabs of watercolour. Colour only describes a bird or an egg.

// MARK: - Colour

/// The menu colours. Day and night are two palettes; the game clock picks one.
struct Palette: Equatable, Sendable {
    var paper: Color
    var ink: Color
    var inkSoft: Color
    var inkMuted: Color
    var hairline: Color
    var hairlineSoft: Color
    var unknown: Color
    var unknownBox: Color
    var artPlaceholder: Color
    var coin: Color
    /// Behind floating labels and the HUD over the farm scene.
    var floating: Color
    /// Toasts invert against the night scene.
    var toast: Color
    var toastText: Color
    var isNight: Bool

    static let day = Palette(
        paper: Color(hex: 0xFFFFFF), ink: Color(hex: 0x2A2320), inkSoft: Color(hex: 0x5A4D45),
        inkMuted: Color(hex: 0x7A6A5F), hairline: Color(hex: 0xE6DCCF), hairlineSoft: Color(hex: 0xECE5DB),
        unknown: Color(hex: 0xC9BBAE), unknownBox: Color(hex: 0xD8CDBF),
        artPlaceholder: Color(hex: 0x7A6A5F).opacity(0.30), coin: Color(hex: 0xD6A65E),
        floating: Color.white.opacity(0.9), toast: Color(hex: 0xFFFFFF), toastText: Color(hex: 0x2A2320),
        isNight: false)

    static let night = Palette(
        paper: Color(hex: 0x1B1817), ink: Color(hex: 0xF3EEE6), inkSoft: Color(hex: 0xD9CFC4),
        inkMuted: Color(hex: 0xC2B6AA), hairline: Color(hex: 0x3A3330), hairlineSoft: Color(hex: 0x3A3330),
        unknown: Color(hex: 0x6E625A), unknownBox: Color(hex: 0x5A504A),
        artPlaceholder: Color(hex: 0xC2B6AA).opacity(0.30), coin: Color(hex: 0xE8C894),
        floating: Color(hex: 0x1B1817).opacity(0.88), toast: Color(hex: 0xF3EEE6), toastText: Color(hex: 0x1B1817),
        isNight: true)

    /// Night is 18:00 to 05:59 on the device clock.
    static func forHour(_ hour: Int) -> Palette { hour >= 18 || hour < 6 ? .night : .day }

    /// The palette for this moment: the device clock, unless a tester has pinned day or night.
    static func forHour(_ hour: Int, pinned: TimeOfDayPin) -> Palette {
        switch pinned {
        case .clock: forHour(hour)
        case .day: .day
        case .night: .night
        }
    }
}

/// A tester setting (Settings ▸ For testing): follow the clock, or pin the farm to day or night.
enum TimeOfDayPin: String, CaseIterable {
    case clock, day, night

    static let key = "tester.timeOfDay"

    var label: String {
        switch self {
        case .clock: "Clock"
        case .day: "Day"
        case .night: "Night"
        }
    }
}

extension EnvironmentValues {
    @Entry var palette: Palette = .day
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255)
    }
}

/// Watercolour dabs: colour that describes a bird or an egg. Always shown with its name.
enum Pigment {
    static func feather(_ colour: FeatherColour) -> Color {
        switch colour {
        case .black: Color(hex: 0x2A2320)
        case .blue: Color(hex: 0x7E8F9C)
        case .splash: Color(hex: 0xD6DBDE)
        case .lavender: Color(hex: 0xB5AEBB)
        case .buff: Color(hex: 0xDDAE6E)
        case .white: Color(hex: 0xF4F1E8)
        }
    }

    static func egg(_ colour: EggColour) -> Color {
        switch colour {
        case .cream: Color(hex: 0xEFE3CB)
        case .brown: Color(hex: 0xA86E45)
        case .blue: Color(hex: 0xB4CFCB)
        case .olive: Color(hex: 0x868755)
        }
    }

    /// The Egg Book's shade ladder for each egg colour, lightest first.
    static func shades(_ colour: EggColour) -> [Color] {
        switch colour {
        case .cream: [0xF6EEDD, 0xEFE3CB, 0xE6D5B4].map(Color.init(hex:))
        case .brown: [0xC99A73, 0xA86E45, 0x8A5534, 0x6B3E25].map(Color.init(hex:))
        case .blue: [0xCFE0DD, 0xB4CFCB].map(Color.init(hex:))
        case .olive: [0x868755].map(Color.init(hex:))
        }
    }

    static let splashFleck = Color(hex: 0x7E8F9C)
    static let oliveSpeckle = Color(hex: 0x5C5D37)
    static let speckle = Color(hex: 0x6B3E25)
    static let buffNotice = Color(hex: 0xDDAE6E)
    static let brownNotice = Color(hex: 0xA86E45)
}

// MARK: - Type

/// Names and speech are serif (Libre Caslon). Everything you read or count is sans (Figtree).
/// Every style scales with Dynamic Type.
enum Typeface {
    static func display(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        .custom("LibreCaslonDisplay-Regular", size: size, relativeTo: style)
    }
    static func serif(_ size: CGFloat, relativeTo style: Font.TextStyle = .headline) -> Font {
        .custom("LibreCaslonText-Regular", size: size, relativeTo: style)
    }
    static func serifItalic(_ size: CGFloat, relativeTo style: Font.TextStyle = .title3) -> Font {
        .custom("LibreCaslonText-Italic", size: size, relativeTo: style)
    }
    static func sans(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Figtree-Regular", size: size, relativeTo: style)
    }
    static func sansMedium(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Figtree-Medium", size: size, relativeTo: style)
    }
    static func sansLight(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Figtree-Light", size: size, relativeTo: style)
    }

    // The named styles from the type table.
    static let displayName = display(54)
    static let title = display(38)
    static let title2 = display(30, relativeTo: .title)
    static let speech = serifItalic(24, relativeTo: .title2)
    static let epithet = serifItalic(20)
    static let place = serif(18, relativeTo: .title3)
    static let item = serif(17)
    static let body = sans(16)
    static let action = sansMedium(16)
    static let label = sans(13, relativeTo: .footnote)
    static let caption = sans(12, relativeTo: .caption)
    static let number = sansMedium(15)

    /// Registers the bundled fonts, so `Font.custom` finds them. Call once at launch.
    static func registerBundledFonts() {
        for url in Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [] {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

// MARK: - Space, radius, line

enum Space {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    /// Sheet side and bottom padding.
    static let sheetSide: CGFloat = 28
    static let sheetBottom: CGFloat = 36
}

enum Radius {
    static let sheet: CGFloat = 30
    static let control: CGFloat = 10
    static let tile: CGFloat = 12
    static let tray: CGFloat = 14
}

enum Stitch {
    /// Dashed row divider.
    static let divider = StrokeStyle(lineWidth: 1.3, dash: [4, 4])
    /// Dashed underline under names and selected tabs.
    static let underline = StrokeStyle(lineWidth: 1.5, dash: [5, 4])
    /// "Not yet" outlines.
    static let unknown = StrokeStyle(lineWidth: 1.1, dash: [3, 3])
    /// A solid, round-ended tick: something is done.
    static let tick = StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
}
