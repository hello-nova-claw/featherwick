import FeatherwickCore
import SwiftUI

// Small marks: eggs, feathers, dabs and dots. Colour never stands alone: each mark sits next to
// a word, and each group reads as one sentence to VoiceOver.

/// An egg: rounder at the bottom, taller at the top (CSS radius 50%/60%/40%).
struct EggShape: Shape {
    func path(in r: CGRect) -> Path {
        let k: CGFloat = 0.5523  // circle-to-Bézier constant
        let cx = r.midX
        let w = r.width / 2
        let split = r.minY + r.height * 0.6
        let top = split - r.minY
        let bottom = r.maxY - split
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: split))
        p.addCurve(
            to: CGPoint(x: cx, y: r.minY), control1: CGPoint(x: r.minX, y: split - k * top),
            control2: CGPoint(x: cx - k * w, y: r.minY))
        p.addCurve(
            to: CGPoint(x: r.maxX, y: split), control1: CGPoint(x: cx + k * w, y: r.minY),
            control2: CGPoint(x: r.maxX, y: split - k * top))
        p.addCurve(
            to: CGPoint(x: cx, y: r.maxY), control1: CGPoint(x: r.maxX, y: split + k * bottom),
            control2: CGPoint(x: cx + k * w, y: r.maxY))
        p.addCurve(
            to: CGPoint(x: r.minX, y: split), control1: CGPoint(x: cx - k * w, y: r.maxY),
            control2: CGPoint(x: r.minX, y: split + k * bottom))
        p.closeSubpath()
        return p
    }
}

/// A feather: a pointed vane over a short quill.
struct FeatherShape: Shape {
    func path(in r: CGRect) -> Path {
        let cx = r.midX
        let vaneBottom = r.minY + r.height * 0.8
        var p = Path()
        p.move(to: CGPoint(x: cx, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: cx, y: vaneBottom), control: CGPoint(x: r.maxX + r.width * 0.15, y: r.midY))
        p.addQuadCurve(to: CGPoint(x: cx, y: r.minY), control: CGPoint(x: r.minX - r.width * 0.15, y: r.midY))
        p.closeSubpath()
        return p
    }
}

/// A straight horizontal line, for dashed stitches.
struct HLine: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        return p
    }
}

/// A tick: a short stroke down, then a long one up.
struct TickShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX + r.width * 0.08, y: r.minY + r.height * 0.55))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.38, y: r.minY + r.height * 0.85))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.92, y: r.minY + r.height * 0.15))
        return p
    }
}

/// A quiet ink tick for something done. It always sits next to a word ("Done").
struct TickMark: View {
    @Environment(\.palette) private var palette
    var size: CGFloat = 14
    var body: some View {
        TickShape().stroke(palette.inkMuted, style: Stitch.tick)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// The signature dashed stitch between rows.
struct StitchDivider: View {
    @Environment(\.palette) private var palette
    var body: some View {
        HLine().stroke(palette.hairline, style: Stitch.divider).frame(height: 2)
            .accessibilityHidden(true)
    }
}

/// An egg filled with its colour and a 1pt ink outline. Speckled eggs get a few darker flecks.
struct EggMark: View {
    @Environment(\.palette) private var palette
    let colour: EggColour
    var speckled = false
    var size = CGSize(width: 14, height: 18)

    var body: some View {
        ZStack {
            EggShape().fill(Pigment.egg(colour))
            if speckled || colour == .olive {
                Speckles(colour: colour == .olive ? Pigment.oliveSpeckle : Pigment.speckle)
                    .clipShape(EggShape())
            }
            EggShape().strokeBorder(palette.ink, lineWidth: 1)
        }
        .frame(width: size.width, height: size.height)
    }
}

/// Fixed speckle positions, so an egg looks the same every time it is drawn.
private struct Speckles: View {
    let colour: Color
    private static let spots: [(CGFloat, CGFloat, CGFloat)] = [
        (0.3, 0.35, 0.08), (0.65, 0.3, 0.06), (0.5, 0.55, 0.07), (0.3, 0.7, 0.05), (0.7, 0.68, 0.07),
    ]
    var body: some View {
        GeometryReader { g in
            ForEach(Array(Self.spots.enumerated()), id: \.offset) { _, s in
                Circle().fill(colour)
                    .frame(width: g.size.width * s.2 * 2, height: g.size.width * s.2 * 2)
                    .position(x: g.size.width * s.0, y: g.size.height * s.1)
            }
        }
    }
}

extension EggShape: InsettableShape {
    func inset(by amount: CGFloat) -> some InsettableShape { InsetEgg(amount: amount) }
}

private struct InsetEgg: InsettableShape {
    var amount: CGFloat
    func path(in r: CGRect) -> Path { EggShape().path(in: r.insetBy(dx: amount, dy: amount)) }
    func inset(by more: CGFloat) -> InsetEgg { InsetEgg(amount: amount + more) }
}

/// "Brown eggs": egg shape plus words.
struct EggSwatch: View {
    let colour: EggColour
    var speckled = false
    var body: some View {
        HStack(spacing: Space.s) {
            EggMark(colour: colour, speckled: speckled)
            Text("\(speckled ? "Speckled " : "")\(colour.rawValue.capitalized) eggs").font(Typeface.body)
        }
        .accessibilityElement(children: .combine)
    }
}

/// "Buff": a feather in the bird's colour, plus words.
struct FeatherSwatch: View {
    @Environment(\.palette) private var palette
    let colour: FeatherColour
    let name: String

    var body: some View {
        HStack(spacing: Space.s) {
            ZStack {
                FeatherShape().fill(Pigment.feather(colour))
                if colour == .splash {
                    Speckles(colour: Pigment.splashFleck).clipShape(FeatherShape())
                }
                FeatherShape().stroke(palette.ink, lineWidth: 1)
                Path { p in
                    p.move(to: CGPoint(x: 7, y: 6))
                    p.addLine(to: CGPoint(x: 7, y: 24))
                }
                .stroke(palette.ink, lineWidth: 1)
            }
            .frame(width: 14, height: 24)
            Text(name.prefix(1).uppercased() + name.dropFirst()).font(Typeface.body)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A round watercolour dab. A stand-in until the artist paints the real ones.
struct Dab: View {
    let colour: Color
    var size: CGFloat = 16
    var body: some View {
        Circle()
            .fill(colour.opacity(0.85))
            .overlay(Circle().fill(colour).scaleEffect(0.62).blur(radius: size * 0.08))
            .frame(width: size, height: size)
    }
}

/// A dashed "not yet" circle.
struct UnknownDot: View {
    @Environment(\.palette) private var palette
    var size: CGFloat = 16
    var body: some View {
        Circle().stroke(palette.unknown, style: Stitch.unknown).frame(width: size, height: size)
    }
}

/// Four dabs, wild → lap chicken. Earned ones are filled; the rest are dashed.
struct FriendlinessDabs: View {
    @Environment(\.palette) private var palette
    let level: Friendliness
    var body: some View {
        let earned = (Friendliness.allCases.firstIndex(of: level) ?? 0) + 1
        HStack(spacing: Space.xs) {
            ForEach(0..<4, id: \.self) { i in
                if i < earned { Dab(colour: palette.inkMuted) } else { UnknownDot() }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Friendliness: \(friendlinessName(level)), \(earned) of 4")
    }
}

/// Three dots of growing size: chick, pullet or cockerel, hen or rooster.
struct AgeDots: View {
    let stage: LifeStage
    var body: some View {
        let reached = LifeStage.allCases.firstIndex(of: stage) ?? 0
        HStack(alignment: .bottom, spacing: Space.xs) {
            ForEach(Array([CGFloat(8), 12, 17].enumerated()), id: \.offset) { i, size in
                if i <= reached { Dab(colour: Pigment.buffNotice, size: size) } else { UnknownDot(size: size) }
            }
        }
        .accessibilityHidden(true)
    }
}

/// The gold coin disc.
struct CoinDisc: View {
    @Environment(\.palette) private var palette
    var size: CGFloat = 10
    var body: some View { Circle().fill(palette.coin).frame(width: size, height: size) }
}

/// The sun on the HUD's day track: a coin-gold disc with a thin ink rim.
struct SunMark: View {
    @Environment(\.palette) private var palette
    var size: CGFloat = Space.m
    var body: some View {
        Circle().fill(palette.coin)
            .overlay(Circle().stroke(palette.ink, lineWidth: 1))
            .frame(width: size, height: size)
    }
}

/// The day's light on the HUD: a dashed track with one place per slot of daylight, and the sun on the
/// slot spent next. Once every slot is spent, the sun has set at the end of the track.
struct SunTrack: View {
    @Environment(\.palette) private var palette
    let slots: Int
    let used: Int
    /// How long the sun takes to slide one place: the length of the rest scene, else a short ease.
    var slide: Double = 0.3

    var body: some View {
        let step = Space.xl
        let places = max(1, slots)
        let at = min(used, places)
        ZStack(alignment: .leading) {
            HLine().stroke(palette.inkMuted, style: Stitch.unknown)
            ForEach(Array(0...places), id: \.self) { i in
                Circle().fill(i < at ? palette.inkMuted : palette.unknown)
                    .frame(width: Space.xs, height: Space.xs)
                    .offset(x: step * CGFloat(i) - Space.xs / 2)
            }
            SunMark()
                .opacity(at == places ? 0.5 : 1)
                .offset(x: step * CGFloat(at) - Space.m / 2)
                .animation(.easeInOut(duration: slide), value: at)
        }
        .frame(width: step * CGFloat(places), height: Space.m, alignment: .leading)
    }
}

/// Treats: an ink diamond.
struct TreatDiamond: View {
    @Environment(\.palette) private var palette
    var size: CGFloat = 8
    var body: some View {
        Rectangle().fill(palette.ink).frame(width: size, height: size).rotationEffect(.degrees(45))
    }
}

/// A show rosette with two tails, in ink: colour is kept for birds and eggs.
/// 1st is filled, 2nd a solid outline, 3rd a dashed one. Always shown next to the placing in words.
struct RibbonMark: View {
    @Environment(\.palette) private var palette
    let placing: Int
    var size: CGFloat = 14

    var body: some View {
        ZStack {
            tail(angle: 14).offset(x: -size * 0.16, y: size * 0.42)
            tail(angle: -14).offset(x: size * 0.16, y: size * 0.42)
            Circle().fill(placing == 1 ? palette.ink : palette.paper)
                .overlay(Circle().strokeBorder(palette.ink, style: rim))
                .frame(width: size, height: size)
                .offset(y: -size * 0.2)
        }
        .frame(width: size, height: size * 1.4)
        .accessibilityHidden(true)
    }

    private var rim: StrokeStyle { placing == 3 ? Stitch.unknown : StrokeStyle(lineWidth: 1.1) }

    private func tail(angle: Double) -> some View {
        Rectangle().fill(palette.ink).frame(width: size * 0.26, height: size * 0.6).rotationEffect(.degrees(angle))
    }
}

/// Where painted art will go: a dashed box with a quiet label.
struct ArtPlaceholder: View {
    @Environment(\.palette) private var palette
    let label: String
    var radius: CGFloat = Radius.tile
    var body: some View {
        RoundedRectangle(cornerRadius: radius)
            .stroke(palette.artPlaceholder, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            .overlay(Text(label).font(.system(.caption2, design: .monospaced)).foregroundStyle(palette.inkMuted))
            .accessibilityHidden(true)
    }
}

func friendlinessName(_ f: Friendliness) -> String {
    switch f {
    case .wild: "Wild"
    case .skittish: "Skittish"
    case .friendly: "Friendly"
    case .lapChicken: "Lap chicken"
    }
}
