import FeatherwickCore
import SwiftUI

// Coop birds in the 2.5D Yard and Far yard: rigged chickens in the scene's middle group, so they walk
// behind and in front of the trees. View only, like `FarmBirds.swift`: the engine never knows where a
// bird stands. Walks use the system's dice, not the game's, so the game is unchanged.

/// A yard panel's scene with its coop birds in it. It redraws only when a bird's stay ends, as
/// `PanelBirds` does: the birds walk with SwiftUI animations, not a clock. (A redraw every second on
/// every panel made swiping between panels stutter.)
///
/// The clock wraps the whole scene, not only the birds: views in the scene's middle group must be
/// direct children of its stack for their `.zIndex` to sort against the trees.
struct YardScene: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let panel: FarmPanel
    let open: (UUID) -> Void
    /// Where each chicken in this scene is heading, so a hen's chicks can follow her.
    @State private var leads = SceneLeads()

    var body: some View {
        if reduceMotion {
            // Nothing strolls: no clock at all.
            scene(now: nil)
        } else {
            let ends: [Date] = FarmFlock.stayEnds(of: store.state.coop.map(\.id), from: .now)
            TimelineView(.explicit(ends)) { context in
                scene(now: context.date)
            }
        }
    }

    private var spot: BirdSpot { panel == .farYard ? .farYard : .yard }

    /// `now` is the stroll clock. Nil (Reduce Motion): the birds stay put.
    private func scene(now: Date?) -> some View {
        let s: GameState = store.state
        let inside: Bool = palette.isNight || !s.coopDoorOpen
        let birds: [Bird] = FarmFlock.birds(at: spot, in: s, inside: inside, now: now)
        let follows: [UUID: ChickFollow] = FarmFlock.following(in: s)
        return FarmScene(panel: panel, season: s.season) { (depth: SceneDepth, size: CGSize) in
            ForEach(birds) { (bird: Bird) in
                SceneChicken(
                    bird: bird, height: FarmFlock.sceneHeight(of: bird, in: s), panel: panel, depth: depth,
                    size: size, now: now, follow: follows[bird.id], leads: leads, open: open)
            }
        }
    }
}

/// Where each chicken in one yard scene is heading, and which way it faces there. A hen writes hers each
/// time she sets off; her chicks read it and trail her. A plain class, not observed: the chicks look on
/// their own slow loop, so a hen's walk never redraws the scene.
@MainActor
final class SceneLeads {
    var heading: [UUID: SceneLead] = [:]
}

/// Where one chicken is heading in the scene, in unit coordinates, and which way it faces there.
struct SceneLead: Sendable {
    let spot: CGPoint
    let facingRight: Bool
}

/// Where scene chickens stand and how they move, in unit coordinates over the panel ((0, 0) top left).
enum SceneFlock {
    /// The farthest a bird walks at once, in unit distance.
    static let step: CGFloat = 0.18
    /// Walking speed at full size, in points a second: an amble, not a run. Far birds walk slower on screen.
    static let speed: CGFloat = 26
    /// A walk lasts at least this long, and at most the upper bound, in seconds.
    static let walkTime: ClosedRange<Double> = 0.8...5
    /// A walk off the panel lasts this long, at most.
    static let walkOffTime: ClosedRange<Double> = 1.5...6
    /// A bird that came in from the other yard this recently starts off the edge and walks in.
    static let arrivalWindow: Double = 2.5
    /// Without a walk mask: the old ground band, below the place labels and above Books and ≡.
    static let band = CGRect(x: 0.08, y: 0.62, width: 0.84, height: 0.24)

    /// The ground from the hill line down to the buttons. Starts are spread over it, then snapped to the mask.
    private static func ground(_ panel: FarmPanel) -> ClosedRange<CGFloat> {
        let hill: CGFloat = SceneArtLayout.hillLine(panel) ?? band.minY
        return min(hill, SceneArtLayout.walkBottom)...SceneArtLayout.walkBottom
    }

    /// The same start for a bird each time, from its id, snapped to walkable ground.
    static func start(for id: UUID, on panel: FarmPanel, mask: WalkMask?) -> CGPoint {
        let f: CGPoint = FarmFlock.startSpot(for: id)
        guard let mask else {
            return CGPoint(x: band.minX + f.x * band.width, y: band.minY + f.y * band.height)
        }
        let range: ClosedRange<CGFloat> = ground(panel)
        let wish = CGPoint(x: 0.06 + f.x * 0.88, y: range.lowerBound + f.y * (range.upperBound - range.lowerBound))
        return nearestWalkable(to: wish, in: mask) ?? wish
    }

    /// Where a bird walks in from the left or right edge: its own height on the panel, moved to the nearest
    /// height where the ground at the edge is walkable. `x` is the edge itself; the caller moves it off.
    static func entry(fromRight: Bool, for id: UUID, on panel: FarmPanel, mask: WalkMask?) -> CGPoint {
        let home: CGPoint = start(for: id, on: panel, mask: mask)
        let x: CGFloat = fromRight ? 0.97 : 0.03
        guard let mask else { return CGPoint(x: x, y: home.y) }
        for i in 0..<60 {
            // 0, +1, -1, +2, -2 … steps of 1% of the panel, from the bird's own height.
            let offset: CGFloat = CGFloat((i + 1) / 2) * (i % 2 == 0 ? -0.01 : 0.01)
            let point = CGPoint(x: x, y: home.y + offset)
            if mask.isWalkable(point) { return point }
        }
        return CGPoint(x: x, y: home.y)
    }

    /// The walkable point nearest `point`, in rings around it. Nil if nothing is walkable nearby.
    static func nearestWalkable(to point: CGPoint, in mask: WalkMask) -> CGPoint? {
        if mask.isWalkable(point) { return point }
        for ring in 1...30 {
            let radius: CGFloat = CGFloat(ring) * 0.015
            for k in 0..<16 {
                let angle: CGFloat = CGFloat(k) / 16 * 2 * .pi
                let p = CGPoint(x: point.x + cos(angle) * radius, y: point.y + sin(angle) * radius)
                if mask.isWalkable(p) { return p }
            }
        }
        return nil
    }

    /// Which way a bird faces at its start, from its id.
    static func startsFacingRight(_ id: UUID) -> Bool { id.uuid.5 % 2 == 0 }

    /// A chick's spot behind its mother: back from the way she faces, one gap per place in her line,
    /// stepping up and down in turn. Gaps shrink with depth, like the birds. On walkable ground if possible.
    static func trail(
        behind lead: SceneLead, place: Int, depth: SceneDepth, size: CGSize, mask: WalkMask?
    ) -> CGPoint {
        // A first layout pass can be zero size: never divide by less than a point.
        let width: CGFloat = max(1, size.width)
        let height: CGFloat = max(1, size.height)
        let scale: CGFloat = depth.scale(atGroundY: lead.spot.y * height)
        let back: CGFloat = lead.facingRight ? -1 : 1
        let side: CGFloat = place % 2 == 0 ? 1 : -1
        let wish = CGPoint(
            x: lead.spot.x + back * FarmFlock.chickGap * CGFloat(place + 1) * scale / width,
            y: lead.spot.y + side * FarmFlock.chickSideStep * scale / height)
        guard let mask else { return wish }
        return nearestWalkable(to: wish, in: mask) ?? lead.spot
    }

    /// Just past the panel's left or right edge, so the whole bird is off it.
    static func offEdge(right: Bool, height: CGFloat, width: CGFloat) -> CGFloat {
        // A first layout pass can be tiny: never measure the edge against less than a narrow phone.
        let past: CGFloat = (max(44, height * ChickenRigMetrics.widthRatio) / 2 + Space.s) / max(300, width)
        return right ? 1 + past : -past
    }
}

/// One coop bird in the yard scene: a rigged chicken that potters about the walkable ground. Every few
/// seconds it walks a little way (legs going, facing where it goes) or stops to peck. Its feet set its size
/// and draw order (`SceneDepth`). When its stay is over it walks off the shared edge, and it walks in on
/// the next panel. With Reduce Motion on, it stands at its start.
///
/// A hen chick follows its mother instead (`follow`): it keeps her stroll, so it changes yards with her, and
/// every moment or so it walks to its spot behind where she is heading (`SceneFlock.trail`).
///
/// Touch is as for every bird (`PettableBird`): tap for the card, press and rub to pet.
struct SceneChicken: View {
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let bird: Bird
    /// Rig height at full (nearest) size.
    let height: CGFloat
    let panel: FarmPanel
    let depth: SceneDepth
    let size: CGSize
    /// Its stay on this panel. Nil with Reduce Motion: the bird stays.
    let stroll: Stroll?
    /// Set for a hen chick drawn with its mother: it trails her.
    let follow: ChickFollow?
    /// Where each chicken in this scene is heading. A hen writes; her chicks read.
    let leads: SceneLeads
    let open: (UUID) -> Void
    /// Where its feet are (or are walking to), in unit coordinates. x below 0 or above 1 is off the panel.
    @State private var spot: CGPoint
    /// The ground Y the draw order uses. `.zIndex` does not animate, so it moves to the walk's end halfway.
    @State private var sortY: CGFloat
    @State private var facingRight: Bool
    @State private var activity: ChickenActivity = .idle
    /// A finger is on the bird: it waits, and does not walk away mid-pet.
    @State private var held = false

    init(
        bird: Bird, height: CGFloat, panel: FarmPanel, depth: SceneDepth, size: CGSize, now: Date?,
        follow: ChickFollow?, leads: SceneLeads, open: @escaping (UUID) -> Void
    ) {
        self.bird = bird
        self.height = height
        self.panel = panel
        self.depth = depth
        self.size = size
        self.follow = follow
        self.leads = leads
        self.open = open
        // A hen chick keeps its mother's stroll and starts from her start, so they move as one.
        let leader: UUID = follow?.mother ?? bird.id
        let stroll: Stroll? = now.map { FarmFlock.stroll(for: leader, at: $0) }
        self.stroll = stroll
        let mask: WalkMask? = SceneArt.walkMask(for: panel)
        var start: CGPoint = SceneFlock.start(for: leader, on: panel, mask: mask)
        var facing: Bool = SceneFlock.startsFacingRight(leader)
        // Just in from the other yard: start off the edge it came in by, at a walkable height, then walk in.
        // The Far yard is right of the Yard, so a bird comes into the Yard from the right.
        if let stroll, Date.now.timeIntervalSince(stroll.since) < SceneFlock.arrivalWindow {
            let fromRight: Bool = stroll.spot == .yard
            start = SceneFlock.entry(fromRight: fromRight, for: leader, on: panel, mask: mask)
            start.x = SceneFlock.offEdge(right: fromRight, height: height, width: size.width)
            facing = !fromRight
        } else if let follow {
            let lead = SceneLead(spot: start, facingRight: facing)
            start = SceneFlock.trail(behind: lead, place: follow.place, depth: depth, size: size, mask: mask)
        }
        _spot = State(initialValue: start)
        _sortY = State(initialValue: start.y)
        _facingRight = State(initialValue: facing)
    }

    var body: some View {
        let groundY: CGFloat = spot.y * size.height
        let scale: CGFloat = depth.scale(atGroundY: groundY)
        let box: CGSize = touchBox
        let drawn = CGSize(width: height * ChickenRigMetrics.widthRatio * scale, height: height * scale)
        PettableBird(bird: bird, touch: drawn, held: $held, open: open) {
            chicken(scale: scale, drawn: drawn)
        }
        // A fixed box, feet at its bottom: its centre is a fixed height above the feet, so the
        // position animates in step with the scale.
        .frame(width: box.width, height: box.height, alignment: .bottom)
        .position(x: spot.x * size.width, y: groundY - box.height / 2)
        .task(id: Cue(reduceMotion: reduceMotion, size: size, follow: follow)) { await wander() }
        .zIndex(depth.zIndex(forGroundY: sortY * size.height))
    }

    /// The wander loop restarts when any of these changes (a first layout pass can be zero size).
    private struct Cue: Equatable {
        let reduceMotion: Bool
        let size: CGSize
        /// A weaned chick keeps its view but stops following: the loop restarts with its own stroll.
        let follow: ChickFollow?
    }

    /// Big enough for the bird at full size and for a 44 pt touch.
    private var touchBox: CGSize {
        CGSize(width: max(44, height * ChickenRigMetrics.widthRatio), height: max(44, height))
    }

    /// The rig at full size, scaled down about its feet, in a frame the size it is drawn.
    private func chicken(scale: CGFloat, drawn: CGSize) -> some View {
        let colours = ChickenColours(bird: bird, state: store.state)
        let acting: ChickenActivity = reduceMotion ? .idle : activity
        return AnimatedChicken(colours: colours, height: height, facingRight: facingRight, activity: acting)
            .scaleEffect(scale, anchor: .bottom)
            .frame(width: drawn.width, height: drawn.height, alignment: .bottom)
    }

    private var mask: WalkMask? { SceneArt.walkMask(for: panel) }

    /// The Far yard is right of the Yard. A bird leaves the Yard on the right and the Far yard on the left.
    private var exitX: CGFloat {
        SceneFlock.offEdge(right: stroll?.spot == .yard, height: height, width: size.width)
    }

    // MARK: - Wandering

    /// One slow loop per bird. SwiftUI animates each walk, so the loop only wakes every 2–4 seconds,
    /// at the middle and end of a walk, or when it is time to set off for the next panel.
    private func wander() async {
        guard !reduceMotion else {
            spot = standingSpot()
            sortY = spot.y
            activity = .idle
            return
        }
        guard size.width > 0, size.height > 0 else { return }
        if let follow {
            await trail(follow)
            return
        }
        announce(spot)
        if spot.x < 0 || spot.x > 1 { await walkIn() }
        while !Task.isCancelled {
            let pause: Double = Double.random(in: 2...4)
            let setOff: Double = secondsUntilSettingOff() ?? pause
            // Always a short nap at least, so a held bird does not spin the loop.
            guard await nap(max(0.25, min(pause, setOff))) else { return }
            if held { continue }
            if let left = secondsUntilSettingOff(), left <= 0 {
                walkOff()
                return
            }
            if Double.random(in: 0..<1) < 0.3 {
                await peck()
            } else {
                await walkSomewhere()
            }
        }
    }

    /// Where it stands with Reduce Motion on: its start, or a chick's spot behind its mother's start.
    private func standingSpot() -> CGPoint {
        guard let follow else { return SceneFlock.start(for: bird.id, on: panel, mask: mask) }
        let home: CGPoint = SceneFlock.start(for: follow.mother, on: panel, mask: mask)
        let lead = SceneLead(spot: home, facingRight: SceneFlock.startsFacingRight(follow.mother))
        return SceneFlock.trail(behind: lead, place: follow.place, depth: depth, size: size, mask: mask)
    }

    /// Tells the scene where this bird is heading, so its chicks (if any) can follow.
    private func announce(_ target: CGPoint) {
        guard follow == nil else { return }
        let right: Bool = abs(target.x - spot.x) * size.width > 2 ? target.x > spot.x : facingRight
        leads.heading[bird.id] = SceneLead(spot: target, facingRight: right)
    }

    // MARK: - Following mother

    /// A hen chick's loop: every moment or so it looks where its mother is heading and walks to its spot
    /// behind her, so it trails her with a short lag. Close enough, it pecks now and then. It leaves for the
    /// other yard on her stroll, as she does.
    private func trail(_ follow: ChickFollow) async {
        var dice = SystemRandomNumberGenerator()
        while !Task.isCancelled {
            guard await nap(Double.random(in: FarmFlock.chickLag, using: &dice)) else { return }
            if held { continue }
            if let left = secondsUntilSettingOff(), left <= 0 {
                walkOff()
                return
            }
            let target: CGPoint = trailTarget(follow)
            let dx: CGFloat = (target.x - spot.x) * size.width
            let dy: CGFloat = (target.y - spot.y) * size.height
            if (dx * dx + dy * dy).squareRoot() > FarmFlock.chickSlack {
                let seconds: Double = walkSeconds(to: target)
                // Never still walking when it is time to set off for the other yard.
                if let left = secondsUntilSettingOff(), left < seconds { continue }
                await walk(to: target, seconds: seconds)
            } else if Double.random(in: 0..<1, using: &dice) < 0.3 {
                await peck()
            }
        }
    }

    /// Its spot behind where its mother is heading. Until she has set off on this panel, behind her start
    /// (or where she comes in). Kept on the panel, so a chick never wanders off after a stale exit.
    private func trailTarget(_ follow: ChickFollow) -> CGPoint {
        let lead: SceneLead =
            leads.heading[follow.mother]
            ?? SceneLead(
                spot: SceneFlock.start(for: follow.mother, on: panel, mask: mask),
                facingRight: SceneFlock.startsFacingRight(follow.mother))
        let target: CGPoint = SceneFlock.trail(
            behind: lead, place: follow.place, depth: depth, size: size, mask: mask)
        return CGPoint(x: min(0.97, max(0.03, target.x)), y: target.y)
    }

    /// A short walk to a walkable point near the bird. No ground found nearby: it pecks instead.
    private func walkSomewhere() async {
        var dice = SystemRandomNumberGenerator()
        guard let target = nextTarget(using: &dice) else {
            await peck()
            return
        }
        let seconds: Double = walkSeconds(to: target)
        // Never still walking when it is time to set off for the other yard.
        if let left = secondsUntilSettingOff(), left < seconds { return }
        announce(target)
        await walk(to: target, seconds: seconds)
    }

    private func nextTarget(using dice: inout SystemRandomNumberGenerator) -> CGPoint? {
        if let mask {
            return mask.randomTarget(near: spot, maxStep: SceneFlock.step, using: &dice)
        }
        let band: CGRect = SceneFlock.band
        let x: CGFloat = spot.x + CGFloat.random(in: -SceneFlock.step...SceneFlock.step, using: &dice)
        let y: CGFloat = spot.y + CGFloat.random(in: -SceneFlock.step...SceneFlock.step, using: &dice)
        return CGPoint(x: min(band.maxX, max(band.minX, x)), y: min(band.maxY, max(band.minY, y)))
    }

    /// Walks there in a straight line at an even pace, legs going, then stands.
    private func walk(to target: CGPoint, seconds: Double) async {
        turn(toward: target.x)
        activity = .walking
        withAnimation(.linear(duration: seconds)) { spot = target }
        // Cancelled (the bird left, or the panel resized): it still ends standing.
        _ = await nap(seconds / 2)
        sortY = target.y
        _ = await nap(seconds / 2)
        activity = .idle
    }

    /// How long a walk from here takes. Far up the yard the bird is smaller, so it covers fewer points.
    private func walkSeconds(to target: CGPoint) -> Double {
        let dx: CGFloat = (target.x - spot.x) * size.width
        let dy: CGFloat = (target.y - spot.y) * size.height
        let midY: CGFloat = (target.y + spot.y) / 2 * size.height
        let pace: CGFloat = SceneFlock.speed * depth.scale(atGroundY: midY)
        let seconds = Double((dx * dx + dy * dy).squareRoot() / pace)
        return min(SceneFlock.walkTime.upperBound, max(SceneFlock.walkTime.lowerBound, seconds))
    }

    /// Faces the way it is about to walk. The flip animates, so it reads as a turn.
    private func turn(toward x: CGFloat) {
        guard abs(x - spot.x) * size.width > 2 else { return }
        let right: Bool = x > spot.x
        if right != facingRight {
            withAnimation(.easeInOut(duration: 0.18)) { facingRight = right }
        }
    }

    private func peck() async {
        activity = .pecking
        _ = await nap(ChickenRigMetrics.peckDuration + 0.1)
        activity = .idle
    }

    // MARK: - Strolling between the yards

    /// How long the walk to the edge takes from here, at the bird's pace.
    private func walkOffSeconds() -> Double {
        let dx: CGFloat = abs(exitX - spot.x) * size.width
        let pace: CGFloat = SceneFlock.speed * depth.scale(atGroundY: spot.y * size.height)
        let seconds = Double(dx / pace)
        return min(SceneFlock.walkOffTime.upperBound, max(SceneFlock.walkOffTime.lowerBound, seconds))
    }

    /// Seconds until the bird sets off, so it reaches the edge as its stay ends. Nil: it stays.
    private func secondsUntilSettingOff() -> Double? {
        guard let stroll else { return nil }
        return stroll.until.timeIntervalSinceNow - walkOffSeconds() - 0.3
    }

    /// Off the edge at its own height. It keeps walking until the redraw at the stay's end takes it off
    /// this panel.
    private func walkOff() {
        let seconds: Double = max(0.8, min(walkOffSeconds(), stroll?.until.timeIntervalSinceNow ?? 0))
        let exit = CGPoint(x: exitX, y: spot.y)
        announce(exit)
        turn(toward: exit.x)
        activity = .walking
        withAnimation(.linear(duration: seconds)) { spot = exit }
    }

    /// From off the edge to walkable ground a little way into the panel.
    private func walkIn() async {
        // Let the first frame draw it off the edge, so the walk in shows.
        guard await nap(0.05) else { return }
        var dice = SystemRandomNumberGenerator()
        let fromRight: Bool = spot.x > 1
        let reach: ClosedRange<CGFloat> = fromRight ? 0.65...0.9 : 0.1...0.35
        var target = CGPoint(x: CGFloat.random(in: reach, using: &dice), y: spot.y)
        if let mask, !mask.isWalkable(target) {
            target = SceneFlock.nearestWalkable(to: target, in: mask) ?? target
        }
        announce(target)
        await walk(to: target, seconds: max(1.5, walkSeconds(to: target)))
    }

    /// Sleeps. False when the task was cancelled (the bird left the panel, or the panel resized).
    private func nap(_ seconds: Double) async -> Bool {
        do {
            try await Task.sleep(for: .seconds(seconds))
            return true
        } catch {
            return false
        }
    }
}
