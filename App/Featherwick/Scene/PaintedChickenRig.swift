import FeatherwickCore
import SwiftUI

// A chicken drawn from a painted parts kit (`PartKit`), on the kit's own joints.
//
// The frame is the path rig's: `height × widthRatio` wide, with the ground point at the bottom centre. Every
// part image covers the kit's whole canvas, placed so the canvas's ground point lands on the frame's. So
// the scene places painted and path birds alike, and the two rigs can swap without a jump.
//
// Colour: each part is its value image with `colorMultiply(token)`. RGB × token is exactly the kit's rule
// (value times token, coverage kept as alpha), and it runs on the GPU with no per-bird image work. The exact
// route, a `Canvas` with a multiply blend, would redraw every part on the CPU each frame of a walk.
//
// Joints: drawing nested groups would need recursion, which SwiftUI only allows through `AnyView`. So each
// part is drawn once, in `drawOrder`, with its own joint and then each parent's joint applied in turn
// (`KitLayer.joints`). That is the same transform nested groups give, and the draw order stays the kit's.
// Rotation and scale effects animate on their own, so a still bird does not redraw, as with the path rig.

/// Draws a coop bird with its painted kit when one exists for its body shape, and with the path rig when
/// not. The scene and the show podium draw through this. The Barn, the bird card and the rig lab pick
/// themselves, because their fallback is not the path rig (a blob, a placeholder, the lab's own switch).
struct ChickenView: View {
    let colours: ChickenColours
    var pose: ChickenPose = .rest
    var facingRight: Bool = true
    var height: CGFloat

    var body: some View {
        if let kit = PartKit.kit(for: colours) {
            PaintedChickenRig(kit: kit, colours: colours, pose: pose, facingRight: facingRight, height: height)
        } else {
            ChickenRig(colours: colours, pose: pose, facingRight: facingRight, height: height)
        }
    }
}

/// A painted chicken in one pose. Same frame and pose as `ChickenRig`; see the notes at the top of the file.
struct PaintedChickenRig: View {
    let kit: PartKit
    let colours: ChickenColours
    var pose: ChickenPose = .rest
    /// The art faces right. False mirrors it about the ground point.
    var facingRight: Bool = true
    var height: CGFloat
    /// Dots on the kit's pivots (filled) and landmarks (rings), at rest: the rig lab's check for new parts.
    var showJoints: Bool = false

    @Environment(\.palette) private var palette

    private typealias M = ChickenRigMetrics

    var body: some View {
        // Explicit types keep the type checker fast (see `BirdSwatch`).
        let space = ChickenSpace(height: height)
        let eyelidAfter: String? = eyelidLayer
        ZStack {
            ForEach(kit.layers) { layer in
                part(layer, space)
                    .scaleEffect(growth(layer), anchor: growthAnchor(layer))
                    .modifier(JointChain(moves: moves(layer.joints, space)))
                if layer.id == eyelidAfter {
                    eyelid(space)
                        .modifier(JointChain(moves: moves(kit.eyelidJoints, space)))
                }
            }
            if showJoints {
                joints(space)
            }
        }
        .frame(width: height * M.widthRatio, height: height)
        .scaleEffect(x: facingRight ? 1 : -1, y: 1)
        .accessibilityHidden(true)
    }

    // MARK: - Parts

    /// One part, coloured by its token. A laced or barred bird gets its overlay too, on the listed parts
    /// only, clipped to the part's own coverage. Only the overlays are masked: masking the part by its own
    /// alpha would square its soft edge. Each overlay is masked on its own, and the multiply blend comes
    /// after the mask: a masked group draws offscreen, so a blend inside it would have nothing to darken.
    @ViewBuilder
    private func part(_ layer: KitLayer, _ space: ChickenSpace) -> some View {
        let tint: Color = colour(for: layer)
        let laced: Bool = layer.lacing && colours.pattern == .lacing && kit.lacing != nil
        let barred: Bool = layer.barring && colours.pattern == .barring && kit.barring != nil
        if laced || barred {
            ZStack {
                canvasImage(layer.image, space).colorMultiply(tint)
                if laced, let map = kit.lacing {
                    // RGB 255 changes nothing; darker darkens the feathers under it.
                    canvasImage(map, space)
                        .mask { canvasImage(layer.image, space) }
                        .blendMode(.multiply)
                }
                if barred, let map = kit.barring {
                    // White with the bar strength as alpha: the pattern colour where the bars are.
                    canvasImage(map, space)
                        .colorMultiply(colours.patternColour)
                        .mask { canvasImage(layer.image, space) }
                }
            }
            .compositingGroup()
        } else {
            canvasImage(layer.image, space).colorMultiply(tint)
        }
    }

    /// A kit image over the whole canvas, its ground point on the frame's bottom centre.
    private func canvasImage(_ image: CGImage, _ space: ChickenSpace) -> some View {
        let size: CGSize = kit.canvasSize
        let centre: CGPoint = space.point(kit.canvasCentre)
        return Image(decorative: image, scale: 1)
            .resizable()
            .interpolation(.medium)
            .frame(width: space.length(size.width), height: space.length(size.height))
            .position(centre)
            .frame(width: space.length(M.widthRatio), height: space.length(1))
    }

    /// The bird's own token for the part. `tokenScale` lifts it (the hackle shines a little lighter).
    private func colour(for layer: KitLayer) -> Color {
        let base: Color
        switch layer.token {
        case .feathers: base = colours.feathers
        case .hackle: base = colours.hackle
        case .tail: base = colours.tail
        case .comb: base = colours.comb
        case .beak: base = colours.beak
        case .eye: base = colours.eye
        case .legs: base = colours.legs
        }
        guard layer.tokenScale != 1 else { return base }
        // The tokens are fixed colours (`Tone.artColour`), so default environment values resolve them.
        // Reading the view's whole environment would redraw every painted bird on any change.
        var lifted: Color.Resolved = base.resolve(in: EnvironmentValues())
        let k: Float = Float(layer.tokenScale)
        lifted.red = min(1, lifted.red * k)
        lifted.green = min(1, lifted.green * k)
        lifted.blue = min(1, lifted.blue * k)
        return Color(lifted)
    }

    /// A comb grows in with age, and a hen's is smaller than a rooster's. The kit paints an adult hen's comb
    /// (`PartKit.paintedCombSize`), so the comb part scales by `combSize` over that, about its own painted
    /// base (the bottom centre of its alpha). A grown hen shows the comb as painted. The `combBase` landmark is used
    /// only when the kit has no comb art bounds. Other parts keep their size.
    private func growth(_ layer: KitLayer) -> CGFloat {
        layer.token == .comb ? CGFloat(max(0.01, colours.combSize / PartKit.paintedCombSize)) : 1
    }

    private func growthAnchor(_ layer: KitLayer) -> UnitPoint {
        guard layer.token == .comb else { return .center }
        if let bounds = kit.combBounds { return ChickenSpace.anchor(CGPoint(x: bounds.midX, y: bounds.minY)) }
        return kit.landmark("combBase").map(ChickenSpace.anchor) ?? .center
    }

    // MARK: - Eyelid

    /// The eyelid goes over the eye: right after the eye part, or after the last part that dips with the head.
    private var eyelidLayer: String? {
        if kit.layers.contains(where: { $0.id == "eye" }) { return "eye" }
        return kit.layers.last(where: { layer in layer.joints.contains { $0.kind == .headDip } })?.id
    }

    /// A comb-coloured patch over the painted eye's own bounds. It grows down from its top edge to blink,
    /// as on the path rig. The art is the truth: the `eyelidTop` landmark is used only when a kit has no eye
    /// part (the heavy kit's landmark sits right of its painted eye). Neither: no eyelid.
    private var eyelidBox: CGRect? {
        if let bounds = kit.eyeBounds { return bounds }
        guard let top = kit.landmark("eyelidTop") else { return nil }
        let eye: CGPoint = kit.landmark("eye") ?? top
        let reach: CGFloat = max(0.01, (top.y - eye.y) * 2)
        return CGRect(x: top.x - reach / 2, y: top.y - reach, width: reach, height: reach)
    }

    @ViewBuilder
    private func eyelid(_ space: ChickenSpace) -> some View {
        if let box = eyelidBox {
            let top = CGPoint(x: box.midX, y: box.maxY)
            let corner: CGFloat = space.length(min(box.width, box.height) * 0.4)
            let shut: CGFloat = CGFloat(min(1, max(0.001, pose.blink)))
            Path(roundedRect: space.rect(box), cornerSize: CGSize(width: corner, height: corner))
                .fill(colours.eyelid)
                .scaleEffect(x: 1, y: shut, anchor: ChickenSpace.anchor(top))
                .opacity(pose.blink > 0 ? 1 : 0)
                .frame(width: space.length(M.widthRatio), height: space.length(1))
        }
    }

    // MARK: - Joints

    /// How each joint in a part's chain moves for the pose: own joint first, then its parents'.
    private func moves(_ joints: [KitJoint], _ space: ChickenSpace) -> [JointMove] {
        joints.map { move(for: $0, space) }
    }

    /// This build's angle for a path-rig angle: the kit's own motion, scaled from the path rig's, so the
    /// existing peck and walk timing gives this build's angles. Missing in the kit: the path rig's angle.
    private func scaled(_ angle: Angle, kit value: Double?, rig: Double) -> Angle {
        guard let value, rig != 0 else { return angle }
        return .degrees(angle.degrees * value / rig)
    }

    private func move(for joint: KitJoint, _ space: ChickenSpace) -> JointMove {
        let motion: KitSpec.Motion? = kit.spec.motion
        let anchor: UnitPoint = ChickenSpace.anchor(joint.pivot)
        // Sitting: the body drops by `sitDrop` of the hip's height and the legs fold under it, as on the path rig.
        let drop: Double = min(1, max(0, pose.sit)) * M.sitDrop
        var move = JointMove(anchor: anchor)
        switch joint.kind {
        case .bodyTilt?:
            move.rotation = scaled(pose.bodyTilt, kit: motion?.peckBodyTilt, rig: M.peckBodyTilt)
            move.drop = space.length(CGFloat(drop) * joint.pivot.y)
        case .headDip?:
            // The neck rides on the body, so the path rig's neck swing dips the head at the throat instead.
            move.rotation = scaled(pose.neckSwing, kit: motion?.peckHeadDip, rig: M.peckNeckSwing)
            // Looking narrows the face about the head's pivot. No new art: the same parts, scaled.
            let turn: Double = pose.faceScale
            move.face = CGFloat(abs(turn) < 0.01 ? (turn < 0 ? -0.01 : 0.01) : turn)
        case .neckSwing?:
            move.rotation = scaled(pose.neckSwing, kit: motion?.peckNeckSwing, rig: M.peckNeckSwing)
        case .legBack?, .legFront?:
            let swing: Angle = joint.kind == .legBack ? pose.legBack : pose.legFront
            move.rotation = scaled(swing, kit: motion?.legSwing, rig: M.legSwing)
            // Never exactly 0: a flat scale has no inverse.
            move.fold = CGFloat(max(0.01, 1 - drop))
            move.foldAnchor = ChickenSpace.anchor(CGPoint(x: joint.pivot.x, y: 0))
        case nil:
            break
        }
        return move
    }

    /// The kit's pivots (filled dots) and landmarks (rings) at rest, and the ground point.
    private func joints(_ space: ChickenSpace) -> some View {
        let pivots: [CGPoint] = kit.spec.parts.values.compactMap { part in
            part.pivot.map { CGPoint(x: $0[0], y: $0[1]) }
        }
        let landmarks: [CGPoint] = (kit.spec.landmarks ?? [:]).values.compactMap { p in
            p.count == 2 ? CGPoint(x: p[0], y: p[1]) : nil
        }
        let dot: CGFloat = max(4, height * 0.025)
        return ZStack {
            ForEach(Array(pivots.enumerated()), id: \.offset) { _, p in
                Circle().fill(palette.ink).frame(width: dot, height: dot).position(space.point(p))
            }
            ForEach(Array(landmarks.enumerated()), id: \.offset) { _, p in
                Circle().stroke(palette.coin, lineWidth: 2).frame(width: dot * 1.4, height: dot * 1.4)
                    .position(space.point(p))
            }
            Circle().fill(palette.inkMuted).frame(width: dot, height: dot).position(space.point(.zero))
        }
        .frame(width: space.length(M.widthRatio), height: space.length(1))
        .allowsHitTesting(false)
    }
}

/// One joint's move: the face narrows (head only), the part turns about the pivot, the leg folds down to the
/// ground (sitting), and the body drops (sitting). In that order, the path rig's.
struct JointMove: Equatable {
    var rotation: Angle = .zero
    var anchor: UnitPoint = .center
    var face: CGFloat = 1
    var fold: CGFloat = 1
    var foldAnchor: UnitPoint = .bottom
    /// Points down.
    var drop: CGFloat = 0

    static let still = JointMove()
}

/// Applies a part's joint moves, own joint first: what nested groups would do. Always `PartKit.maxDepth`
/// slots, so every part has the same view type; empty slots stay still.
private struct JointChain: ViewModifier {
    let moves: [JointMove]

    func body(content: Content) -> some View {
        content
            .modifier(JointEffect(move: slot(0)))
            .modifier(JointEffect(move: slot(1)))
            .modifier(JointEffect(move: slot(2)))
            .modifier(JointEffect(move: slot(3)))
    }

    private func slot(_ i: Int) -> JointMove { i < moves.count ? moves[i] : .still }
}

private struct JointEffect: ViewModifier {
    let move: JointMove

    func body(content: Content) -> some View {
        content
            .scaleEffect(x: move.face, y: 1, anchor: move.anchor)
            .rotationEffect(move.rotation, anchor: move.anchor)
            .scaleEffect(x: 1, y: move.fold, anchor: move.foldAnchor)
            .offset(y: move.drop)
    }
}
