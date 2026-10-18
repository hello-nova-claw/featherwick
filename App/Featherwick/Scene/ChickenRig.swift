import FeatherwickCore
import SwiftUI

// A placeholder chicken drawn with simple shapes, on the shared skeleton (`ChickenSkeleton.swift`):
//
//   thigh, shank, toes   each leg: the drumstick swings at the hip, the shank bends at the hock, the toes curl
//   body       tilts at the hip to peck      (the wing rides on it; the tail flicks on it)
//     neck     swings down at the shoulder   (the lower neck; the upper neck bends at mid-neck)
//       head   dips at the throat, turns to look (comb, beak, eye, wattle ride on it)
//         eyelid  grows down over the eye to blink
//
// How the parts move: every part is a `Path` in the same full-size frame, at its rest position, and rides
// one bone (`riding`). `BoneEffect` places it by that bone's turn and every bone's above it, as nested
// groups would. It animates on its own, so a `withAnimation` blink or glance needs no redraw loop. A
// painted kit (`PaintedChickenRig`) replaces the paths for its body shape, on the same skeleton.
//
// The frame's bottom centre is the ground point, between the feet. The scene places chickens by it.

/// The colours of one bird's rig, from its look. The same tokens `BirdSwatch` uses.
struct ChickenColours: Equatable, Sendable {
    var feathers: Color
    /// Neck and head feathers.
    var hackle: Color
    var tail: Color
    var comb: Color
    /// The skin patch that closes over the eye: comb-red on a grown bird, down on a chick.
    var eyelid: Color
    var beak: Color
    var legs: Color
    var eye: Color = Color(white: 0.1)
    var shine: Color = Color.white.opacity(0.8)
    var outline: Color = Color.black.opacity(0.35)
    /// Darkens the wing and the far leg a little, so they read as separate parts.
    var shade: Color = Color.black.opacity(0.1)
    /// Barring, lacing or a chick's head spot, if the bird shows one.
    var pattern: FeatherwickCore.Pattern?
    var patternColour: Color = Color.white
    /// Comb and wattle size: they grow in with age, and a hen's are smaller.
    var combSize: Double
    /// Chicks draw as a round ball of down with tiny legs and no comb.
    var isChick: Bool
    /// The body shape the look uses. A painted kit for it (`PartKit`) replaces the path rig. Nil: none.
    var build: BodyShape? = nil
    /// A grown hen: she is drawn with the hen kit (`Art/Parts/hen/`), whatever her body shape.
    var isGrownHen: Bool = false
    /// Test tools only: draw with this kit, whatever the bird is (a kit no bird uses yet, such as `hen-b`).
    var kitOverride: KitName? = nil

    /// A buff hen, for the rig lab when there is no bird to show.
    static let sample = ChickenColours(
        feathers: Tone.buff.artColour, hackle: Tone.buff.artColour, tail: Tone.buff.artColour,
        comb: Tone.red.artColour, eyelid: Tone.red.artColour, beak: Tone.horn.artColour,
        legs: Tone.willow.artColour, combSize: 0.6, isChick: false)

    /// For the test tools: draw these colours with one kit, or with none (nil: the path rig).
    mutating func use(kit: KitName?) {
        isGrownHen = kit == .hen
        kitOverride = kit
        if case .build(let shape)? = kit { build = shape } else { build = nil }
    }

    /// A yellow chick, for the rig lab.
    static let sampleChick = ChickenColours(
        feathers: Tone.yellowDown.artColour, hackle: Tone.yellowDown.artColour, tail: Tone.yellowDown.artColour,
        comb: Tone.red.artColour, eyelid: Tone.yellowDown.artColour, beak: Tone.horn.artColour,
        legs: Tone.willow.artColour, combSize: 0, isChick: true)
}

extension ChickenColours {
    /// Picks colours the way `BirdSwatch` does: from the bird's look today, so they follow its genes and age.
    init(bird: Bird, state: GameState) {
        self.init(look: bird.look(onDay: state.day, rules: state.rules))
    }

    /// Colours from a look: for a bird outside the flock too, such as a rival on a show podium.
    init(look: Look) {
        let isChick: Bool = look.stage == .chick
        let feathers: Tone = look.tone(.body) ?? look.tone(.down) ?? Tone.buff
        let comb: Tone = look.tone(.comb) ?? Tone.red
        let overlay: PatternOverlay? = look.overlays.first
        let build: BodyShape? = look.part(.body).flatMap { BodyShape(rawValue: $0.part.shape) }
        self.init(
            feathers: feathers.artColour,
            hackle: (look.tone(.hackle) ?? feathers).artColour,
            tail: (look.tone(.tail) ?? feathers).artColour,
            comb: comb.artColour,
            eyelid: isChick ? feathers.artColour : comb.artColour,
            beak: (look.tone(.beak) ?? Tone.horn).artColour,
            legs: (look.tone(.legs) ?? Tone.yellow).artColour,
            pattern: overlay?.pattern,
            patternColour: (overlay?.tone ?? Tone.white).artColour,
            combSize: look.part(.comb)?.scale ?? 0,
            isChick: isChick,
            build: build,
            isGrownHen: look.stage == .hen)
    }
}

/// Turns rig units (x right of the ground point, y up from the ground, in rig heights) into points in
/// the rig's frame, where y runs down.
struct ChickenSpace {
    let ground: CGPoint
    let unit: CGFloat

    init(height: CGFloat) {
        ground = CGPoint(x: height * ChickenRigMetrics.widthRatio / 2, y: height)
        unit = height
    }

    func point(_ p: CGPoint) -> CGPoint { CGPoint(x: ground.x + p.x * unit, y: ground.y - p.y * unit) }

    func length(_ d: CGFloat) -> CGFloat { d * unit }

    /// `r` is in rig units, with its origin at its bottom left.
    func rect(_ r: CGRect) -> CGRect {
        CGRect(x: ground.x + r.minX * unit, y: ground.y - r.maxY * unit, width: r.width * unit, height: r.height * unit)
    }

    func rect(centre c: CGPoint, size: CGSize) -> CGRect {
        rect(CGRect(x: c.x - size.width / 2, y: c.y - size.height / 2, width: size.width, height: size.height))
    }

    /// A joint as an anchor for `rotationEffect` and `scaleEffect`. It does not depend on the size.
    static func anchor(_ p: CGPoint) -> UnitPoint {
        UnitPoint(x: 0.5 + p.x / ChickenRigMetrics.widthRatio, y: 1 - p.y)
    }
}

/// The placeholder shapes, one per part, at rest. The real art replaces these.
enum ChickenPaths {
    static func ellipse(_ centre: CGPoint, _ size: CGSize, _ s: ChickenSpace) -> Path {
        Path(ellipseIn: s.rect(centre: centre, size: size))
    }

    static func circle(_ centre: CGPoint, _ radius: CGFloat, _ s: ChickenSpace) -> Path {
        ellipse(centre, CGSize(width: 2 * radius, height: 2 * radius), s)
    }

    static func circles(_ centres: [CGPoint], _ radius: CGFloat, _ s: ChickenSpace) -> Path {
        var path = Path()
        for c in centres { path.addPath(circle(c, radius, s)) }
        return path
    }

    static func polygon(_ points: [CGPoint], _ s: ChickenSpace) -> Path {
        var path = Path()
        guard points.count > 2 else { return path }
        path.addLines(points.map { s.point($0) })
        path.closeSubpath()
        return path
    }

    /// The feathered drumstick, between the hip and the hock.
    static func thigh(hip: CGPoint, hock: CGPoint, _ b: ChickenBuild, _ s: ChickenSpace) -> Path {
        let centre = CGPoint(x: (hip.x + hock.x) / 2, y: (hip.y + hock.y) / 2 + b.thighSize.height * 0.1)
        return ellipse(centre, b.thighSize, s)
    }

    /// The bare shank, from the hock down to the foot: a band with round ends.
    static func shank(hock: CGPoint, foot: CGPoint, _ b: ChickenBuild, _ s: ChickenSpace) -> Path {
        let dx: CGFloat = foot.x - hock.x
        let dy: CGFloat = foot.y - hock.y
        let length: CGFloat = max(0.0001, (dx * dx + dy * dy).squareRoot())
        let half: CGFloat = b.legWidth / 2
        let nx: CGFloat = -dy / length * half
        let ny: CGFloat = dx / length * half
        var path: Path = polygon(
            [
                CGPoint(x: hock.x + nx, y: hock.y + ny), CGPoint(x: foot.x + nx, y: foot.y + ny),
                CGPoint(x: foot.x - nx, y: foot.y - ny), CGPoint(x: hock.x - nx, y: hock.y - ny),
            ], s)
        path.addPath(circles([hock, foot], half, s))
        return path
    }

    /// The toes along the ground, from the foot: long in front, a short back toe.
    static func toes(foot: CGPoint, _ b: ChickenBuild, _ s: ChickenSpace) -> Path {
        let w: CGFloat = b.legWidth
        let rect = CGRect(x: foot.x - b.backToe, y: max(0, foot.y - w * 0.8), width: b.backToe + b.toe, height: w * 0.8)
        let corner = CGSize(width: s.length(w * 0.4), height: s.length(w * 0.4))
        return Path(roundedRect: s.rect(rect), cornerSize: corner)
    }

    static func body(_ b: ChickenBuild, _ s: ChickenSpace) -> Path { ellipse(b.bodyCentre, b.bodySize, s) }

    /// Bumps on a bar along the top of the head. Empty for chicks.
    static func comb(_ b: ChickenBuild, _ s: ChickenSpace) -> Path {
        guard let first = b.combBumps.first, let last = b.combBumps.last else { return Path() }
        let r: CGFloat = b.combBumpRadius
        var path = circles(b.combBumps, r, s)
        // From just below the base up to the bump centres.
        let bar = CGRect(
            x: first.x, y: b.combBase.y - r / 2, width: last.x - first.x, height: first.y - b.combBase.y + r)
        let corner = CGSize(width: s.length(r / 2), height: s.length(r / 2))
        path.addRoundedRect(in: s.rect(bar), cornerSize: corner)
        return path
    }

    /// A small light spot on the eye.
    static func shine(_ b: ChickenBuild, _ s: ChickenSpace) -> Path {
        let r: CGFloat = b.eyeRadius
        return circle(CGPoint(x: b.eyeCentre.x + r * 0.35, y: b.eyeCentre.y + r * 0.35), r * 0.35, s)
    }

    /// The eyelid fully shut: a patch over the eye. The rig scales it down from its top edge to open it.
    static func eyelid(_ b: ChickenBuild, _ s: ChickenSpace) -> Path {
        let reach: CGFloat = b.eyelidReach
        let size = CGSize(width: 2 * reach, height: 2 * reach)
        let corner = CGSize(width: s.length(reach * 0.6), height: s.length(reach * 0.6))
        return Path(roundedRect: s.rect(centre: b.eyeCentre, size: size), cornerSize: corner)
    }

    /// The white spot on a barred chick's head.
    static func headSpot(_ b: ChickenBuild, _ s: ChickenSpace) -> Path {
        let r: CGFloat = b.headRadius
        return circle(CGPoint(x: b.headCentre.x - r * 0.2, y: b.headCentre.y + r * 0.55), r * 0.3, s)
    }

    /// Light bars across the body. The rig clips them to the body.
    static func bars(_ b: ChickenBuild, _ s: ChickenSpace) -> Path {
        let box = CGRect(
            x: b.bodyCentre.x - b.bodySize.width / 2, y: b.bodyCentre.y - b.bodySize.height / 2,
            width: b.bodySize.width, height: b.bodySize.height)
        let count = 6
        let gap: CGFloat = box.height / CGFloat(count)
        var path = Path()
        for i in 0..<count {
            let y: CGFloat = box.minY + gap * (CGFloat(i) + 0.4)
            path.addRect(s.rect(CGRect(x: box.minX, y: y, width: box.width, height: gap * 0.3)))
        }
        return path
    }

    /// Rings of dark-edged feathers over the body. The rig strokes them and clips them to the body.
    static func lacing(_ b: ChickenBuild, _ s: ChickenSpace) -> Path {
        let r: CGFloat = b.bodySize.height / 8
        let left: CGFloat = b.bodyCentre.x - b.bodySize.width / 2
        let bottom: CGFloat = b.bodyCentre.y - b.bodySize.height / 2
        var path = Path()
        for x in stride(from: left, through: left + b.bodySize.width, by: r * 1.8) {
            for y in stride(from: bottom, through: bottom + b.bodySize.height, by: r * 1.8) {
                path.addPath(circle(CGPoint(x: x, y: y), r, s))
            }
        }
        return path
    }
}

/// A chicken drawn on its rig in one pose. It does not move by itself: see `AnimatedChicken`.
/// The frame is `height × widthRatio` wide; its bottom centre is the ground point between the feet.
struct ChickenRig: View {
    let colours: ChickenColours
    var pose: ChickenPose = .rest
    /// The rig faces right. False mirrors it about the ground point.
    var facingRight: Bool = true
    var height: CGFloat

    /// The skeleton the path rig rides: the chick's or the grown bird's.
    static func rig(isChick: Bool) -> SkeletonRig { isChick ? .chick : .adult }

    var body: some View {
        // Small helpers with explicit types keep the type checker fast (see `BirdSwatch`).
        let build: ChickenBuild = colours.isChick ? ChickenRigMetrics.chick : ChickenRigMetrics.adult
        let space = ChickenSpace(height: height)
        ZStack {
            leg(.back, build, space)
            torso(build, space)
            leg(.front, build, space)
        }
        .frame(width: height * ChickenRigMetrics.widthRatio, height: height)
        .scaleEffect(x: facingRight ? 1 : -1, y: 1)
        .accessibilityHidden(true)
    }

    private var rig: SkeletonRig { Self.rig(isChick: colours.isChick) }

    private var lineWidth: CGFloat { max(0.75, height * 0.006) }

    /// A filled shape with a thin outline.
    private func part(_ path: Path, _ fill: Color) -> some View {
        path.fill(fill).overlay(path.stroke(colours.outline, lineWidth: lineWidth))
    }

    /// A part on `bone`, moved by the pose. A loose part (`follow`) sways after its bone.
    private func on(_ bone: Bone, follow: Follow? = nil, _ view: some View) -> some View {
        view.riding(bone, rig: rig, pose: pose, height: height, follow: follow)
    }

    // MARK: - Legs

    /// The far leg is a little darker, so the two legs read apart when they cross. The shank and toes come
    /// first, so the drumstick's feathers cover the top of the shank.
    private func leg(_ leg: Leg, _ b: ChickenBuild, _ s: ChickenSpace) -> some View {
        let far: Bool = leg == .back
        let hip: CGPoint = far ? b.backHip : b.frontHip
        let hock: CGPoint = far ? b.backHock : b.frontHock
        let foot: CGPoint = far ? b.backFoot : b.frontFoot
        let shank: Path = ChickenPaths.shank(hock: hock, foot: foot, b, s)
        let toes: Path = ChickenPaths.toes(foot: foot, b, s)
        let thigh: Path = ChickenPaths.thigh(hip: hip, hock: hock, b, s)
        let shade: Color = far ? colours.shade : Color.clear
        return ZStack {
            on(leg.shank, part(shank, colours.legs).overlay(shank.fill(shade)))
            on(leg.toes, part(toes, colours.legs).overlay(toes.fill(shade)))
            on(
                leg.thigh, follow: Follow(amount: ChickenRigMetrics.thighFollow, root: hip),
                part(thigh, colours.feathers).overlay(thigh.fill(shade)))
        }
    }

    // MARK: - Body (tilts at the hip)

    private func torso(_ b: ChickenBuild, _ s: ChickenSpace) -> some View {
        ZStack {
            if !b.tail.isEmpty {
                on(
                    .tail, follow: Follow(amount: ChickenRigMetrics.tailFollow, root: b.tailRoot),
                    part(ChickenPaths.polygon(b.tail, s), colours.tail))
            }
            on(.body, part(ChickenPaths.body(b, s), colours.feathers))
            on(.body, feathering(b, s))
            on(.body, follow: Follow(amount: ChickenRigMetrics.wingFollow, root: wingRoot(b)), wing(b, s))
            // No outline: the neck runs into the body and the head.
            on(.neckLow, ChickenPaths.polygon(b.neck, s).fill(colours.hackle))
            head(b, s)
        }
    }

    @ViewBuilder
    private func feathering(_ b: ChickenBuild, _ s: ChickenSpace) -> some View {
        let clip: Path = ChickenPaths.body(b, s)
        switch colours.pattern {
        case .barring?:
            ChickenPaths.bars(b, s).fill(colours.patternColour.opacity(0.6)).clipShape(clip)
        case .lacing?:
            ChickenPaths.lacing(b, s)
                .stroke(colours.patternColour.opacity(0.55), lineWidth: lineWidth * 1.5)
                .clipShape(clip)
        default:
            Color.clear
        }
    }

    /// The wing hangs from its front edge, at the shoulder.
    private func wingRoot(_ b: ChickenBuild) -> CGPoint {
        CGPoint(x: b.wingCentre.x + b.wingSize.width / 2, y: b.wingCentre.y)
    }

    private func wing(_ b: ChickenBuild, _ s: ChickenSpace) -> some View {
        let path: Path = ChickenPaths.ellipse(b.wingCentre, b.wingSize, s)
        return part(path, colours.feathers).overlay(path.fill(colours.shade))
    }

    // MARK: - Head (dips at the throat, rides on the neck)

    /// The round head stays put; the face (comb, beak, eye, wattle) narrows or mirrors as the head turns.
    private func head(_ b: ChickenBuild, _ s: ChickenSpace) -> some View {
        let turn: Double = pose.faceScale
        // Never exactly 0: a flat scale has no inverse.
        let face: CGFloat = CGFloat(abs(turn) < 0.01 ? (turn < 0 ? -0.01 : 0.01) : turn)
        let centre: UnitPoint = ChickenSpace.anchor(b.headCentre)
        return ZStack {
            on(.head, crown(b, s).scaleEffect(x: face, y: 1, anchor: centre))
            on(.head, part(ChickenPaths.circle(b.headCentre, b.headRadius, s), colours.hackle))
            if colours.pattern == .headSpot {
                on(.head, ChickenPaths.headSpot(b, s).fill(colours.patternColour))
            }
            if !b.isChick {
                // Loose: it swings after the head.
                on(
                    .head, follow: Follow(amount: ChickenRigMetrics.wattleFollow, root: b.wattleTop),
                    wattle(b, s).scaleEffect(x: face, y: 1, anchor: centre))
            }
            on(.head, faceFront(b, s).scaleEffect(x: face, y: 1, anchor: centre))
        }
    }

    /// Behind the head: the comb on a grown bird, down tufts on a chick.
    @ViewBuilder
    private func crown(_ b: ChickenBuild, _ s: ChickenSpace) -> some View {
        if b.isChick {
            part(ChickenPaths.circles(b.tufts, b.tuftRadius, s), colours.feathers)
        } else {
            part(ChickenPaths.comb(b, s), colours.comb)
                .scaleEffect(combScale, anchor: ChickenSpace.anchor(b.combBase))
        }
    }

    private var combScale: CGFloat { CGFloat(max(0.01, colours.combSize)) }

    private func wattle(_ b: ChickenBuild, _ s: ChickenSpace) -> some View {
        part(ChickenPaths.ellipse(b.wattleCentre, b.wattleSize, s), colours.comb)
            .scaleEffect(combScale, anchor: ChickenSpace.anchor(b.wattleTop))
    }

    private func faceFront(_ b: ChickenBuild, _ s: ChickenSpace) -> some View {
        ZStack {
            part(ChickenPaths.polygon(b.beak, s), colours.beak)
            eye(b, s)
        }
    }

    // MARK: - Eyelid (grows down over the eye, rides on the head)

    private func eye(_ b: ChickenBuild, _ s: ChickenSpace) -> some View {
        let shut: CGFloat = CGFloat(min(1, max(0.001, pose.blink)))
        return ZStack {
            ChickenPaths.circle(b.eyeCentre, b.eyeRadius, s).fill(colours.eye)
            ChickenPaths.shine(b, s).fill(colours.shine)
            ChickenPaths.eyelid(b, s).fill(colours.eyelid)
                .scaleEffect(x: 1, y: shut, anchor: ChickenSpace.anchor(b.eyelidTop))
                .opacity(pose.blink > 0 ? 1 : 0)
        }
    }
}
