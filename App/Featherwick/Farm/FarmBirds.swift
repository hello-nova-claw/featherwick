import FeatherwickCore
import SwiftUI

// The flock on the farm: where each bird lives, and how it is touched.
// View only: the engine knows each bird's home; the farm only chooses where to draw it.
// Tap a bird to open its card. Press and rub to pet it.
// By day, each coop bird strolls between the Yard and the Far yard on its own slow rhythm. Those two panels
// draw their birds as rigged chickens inside the 2.5D scene (`Scene/SceneChicken.swift`), so they sort
// against the trees. The Barn's birds (brooder, roost) are soft blobs (`BirdSwatch`) over the panel.
// A hen's chicks go where she goes: on her stroll by day (they trail her in the scene), beside her on the
// roost at night. Only a chick whose mother is not drawn (lost, boarding) sits in the brooder box.

/// Where a bird is drawn. Lost and boarding birds are away, so they are not drawn.
enum BirdSpot: Hashable {
    /// Coop birds by day with the door open. Each strolls between the two (see `FarmFlock.stroll`).
    case yard, farYard
    /// Brooder chicks, in a small box on the barn panel. Hen chicks are drawn with their mother instead;
    /// only one whose mother is not drawn (lost, boarding) sits here, so it is never invisible.
    case brooder
    /// Coop birds at night or with the door shut: in a row on the perch by the coop.
    case roost
}

extension FarmPanel {
    /// The bird spots on this panel, back to front.
    var birdSpots: [BirdSpot] {
        switch self {
        case .barn: [.brooder, .roost]
        case .yard: [.yard]
        case .farYard: [.farYard]
        case .shop: []
        }
    }
}

/// One coop bird's stay in the Yard or the Far yard: where, from when, and until when.
struct Stroll: Hashable {
    let spot: BirdSpot
    let since: Date
    let until: Date
}

/// A hen chick that is drawn with its mother: her id, and its place in her line of chicks (0 is first).
struct ChickFollow: Hashable {
    let mother: UUID
    let place: Int
}

/// Which birds go where, how big they are, and where they start.
enum FarmFlock {
    /// With Reduce Motion on, birds do not stroll. Then, with more coop birds than this, every third
    /// one stands in the far yard.
    static let yardRoom = 6
    /// Room for one bird on the perch. Birds may overlap a little.
    static let seat: CGFloat = 30
    /// A stay in the Yard or the Far yard lasts this long, in seconds (each bird its own length).
    static let stay: ClosedRange<Double> = 20...60
    /// A chick trails this far behind its mother, times its place in her line, in points at full size.
    static let chickGap: CGFloat = 16
    /// Chicks in a line step this far up and down, in turn, so they do not hide each other. Points at full size.
    static let chickSideStep: CGFloat = 5
    /// A chick looks where its mother is going this often, in seconds: its lag behind her.
    static let chickLag: ClosedRange<Double> = 0.4...0.9
    /// A chick closer than this to its spot behind its mother, in points, stays and pecks.
    static let chickSlack: CGFloat = 6

    /// `now` is the clock for the stroll between the yards. Nil (Reduce Motion): the birds stay put.
    static func birds(at spot: BirdSpot, in s: GameState, inside: Bool, now: Date?) -> [Bird] {
        switch spot {
        case .brooder:
            let followers: [UUID: ChickFollow] = following(in: s)
            return s.brooder + s.henChicks.filter { followers[$0.id] == nil }
        case .roost:
            return inside ? withChicks(s.coop, in: s) : []
        case .yard, .farYard:
            if inside { return [] }
            if let now { return withChicks(s.coop.filter { stroll(for: $0.id, at: now).spot == spot }, in: s) }
            let spill: Bool = s.coop.count > yardRoom
            let wantFar: Bool = spot == .farYard
            var birds: [Bird] = []
            for (i, bird) in s.coop.enumerated() where (spill && i % 3 == 2) == wantFar {
                birds.append(bird)
            }
            return withChicks(birds, in: s)
        }
    }

    /// The hen chicks whose mother is drawn (in the coop), by chick id. A chick whose mother is away is
    /// not here: it falls back to the brooder box.
    static func following(in s: GameState) -> [UUID: ChickFollow] {
        let coop: Set<UUID> = Set(s.coop.map(\.id))
        var follows: [UUID: ChickFollow] = [:]
        var lineLength: [UUID: Int] = [:]
        for chick in s.henChicks {
            guard let mother = chick.raisedBy, coop.contains(mother) else { continue }
            let place: Int = lineLength[mother, default: 0]
            lineLength[mother] = place + 1
            follows[chick.id] = ChickFollow(mother: mother, place: place)
        }
        return follows
    }

    /// Each bird, then the hen chicks it is raising, so the chicks are drawn next to their mother.
    static func withChicks(_ birds: [Bird], in s: GameState) -> [Bird] {
        birds.flatMap { (bird: Bird) -> [Bird] in
            [bird] + s.henChicks.filter { $0.raisedBy == bird.id }
        }
    }

    /// Where a coop bird is on its stroll at this moment. Each bird keeps its own rhythm, from its id
    /// (not the game's RNG, so the game is unchanged): a stay in the Yard, then a stay in the Far yard,
    /// each 20–60 seconds, round and round. It runs on the clock, so every panel agrees where a bird is.
    static func stroll(for id: UUID, at now: Date) -> Stroll {
        let bytes = id.uuid
        let span: Double = stay.upperBound - stay.lowerBound
        let yard: Double = stay.lowerBound + Double(bytes.2) / 255 * span
        let far: Double = stay.lowerBound + Double(bytes.3) / 255 * span
        let cycle: Double = yard + far
        let offset: Double = Double(bytes.4) / 255 * cycle
        let into: Double = (now.timeIntervalSinceReferenceDate + offset).truncatingRemainder(dividingBy: cycle)
        let start: Date = now.addingTimeInterval(-into)
        if into < yard {
            return Stroll(spot: .yard, since: start, until: start.addingTimeInterval(yard))
        }
        return Stroll(spot: .farYard, since: start.addingTimeInterval(yard), until: start.addingTimeInterval(cycle))
    }

    /// When each bird's stays end, over the next `ahead` seconds, soonest first. The yards redraw only then.
    static func stayEnds(of ids: [UUID], from now: Date, ahead: TimeInterval = 2 * 3600) -> [Date] {
        var ends: Set<Date> = []
        for id in ids {
            var t: Date = now
            while t.timeIntervalSince(now) < ahead {
                let end: Date = stroll(for: id, at: t).until
                // A moment after the stay ends, so the redraw sees the bird in its new yard.
                ends.insert(end.addingTimeInterval(0.05))
                t = end.addingTimeInterval(0.01)
            }
        }
        return ends.sorted()
    }

    /// The ground band of a panel: its lower part, above the bottom row (Books, Today, the place, ≡).
    static func area(of spot: BirdSpot, in size: CGSize) -> CGRect {
        let top: CGFloat = size.height * 0.62
        let bottom: CGFloat = max(top + 60, size.height - 104)
        let band = CGRect(x: Space.xl, y: top, width: max(0, size.width - 2 * Space.xl), height: bottom - top)
        switch spot {
        case .yard, .farYard:
            return band
        case .brooder:
            return CGRect(x: band.minX, y: band.minY, width: band.width * 0.44, height: band.height)
        case .roost:
            return CGRect(x: band.minX + band.width * 0.5, y: band.minY, width: band.width * 0.5, height: band.height)
        }
    }

    /// A grown bird's blob size. Chicks and growers are smaller (`size(of:in:)`).
    static let adultSize: CGFloat = 38
    /// A grown chicken's rig height in the yard scene, at the bottom of the panel. Depth shrinks it up the yard.
    static let sceneAdultHeight: CGFloat = 64

    /// Chicks are small; growers in between.
    static func size(of bird: Bird, in s: GameState) -> CGFloat {
        switch bird.stage(onDay: s.day, rules: s.rules) {
        case .chick: 20
        case .grower: 28
        case .adult: adultSize
        }
    }

    /// The bird's rig height in the yard scene, at full (nearest) size. Same ratios as the blobs.
    static func sceneHeight(of bird: Bird, in s: GameState) -> CGFloat {
        size(of: bird, in: s) / adultSize * sceneAdultHeight
    }

    /// The same start for a bird each time, from its id: a fraction of its area.
    static func startSpot(for id: UUID) -> CGPoint {
        let bytes = id.uuid
        return CGPoint(x: CGFloat(bytes.0) / 255, y: CGFloat(bytes.1) / 255)
    }

    /// Bird centres on the perch, left to right, then a lower perch when one is full.
    static func perchSlots(count: Int, in area: CGRect) -> [CGPoint] {
        guard count > 0 else { return [] }
        let perRow: Int = max(1, Int(area.width / seat))
        let rows: Int = (count + perRow - 1) / perRow
        let rowGap: CGFloat = min(54, area.height / CGFloat(rows))
        return (0..<count).map { (i: Int) -> CGPoint in
            let row: Int = i / perRow
            let inRow: Int = min(perRow, count - row * perRow)
            let left: CGFloat = area.midX - CGFloat(inRow) * seat / 2
            let x: CGFloat = left + seat * (CGFloat(i % perRow) + 0.5)
            let y: CGFloat = area.minY + rowGap * (CGFloat(row) + 0.5)
            return CGPoint(x: x, y: y)
        }
    }
}

/// The birds on one farm panel without a scene (the Barn). It lies over the panel; only the birds take touches.
/// The Yard and the Far yard draw their birds inside the scene instead (`YardScene`), so nothing here
/// strolls between panels and no clock is needed.
struct PanelBirds: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    let panel: FarmPanel
    let open: (UUID) -> Void

    var body: some View {
        let s: GameState = store.state
        let inside: Bool = palette.isNight || !s.coopDoorOpen
        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(panel.birdSpots, id: \.self) { spot in
                    BirdSpotView(
                        spot: spot, birds: FarmFlock.birds(at: spot, in: s, inside: inside, now: nil),
                        area: FarmFlock.area(of: spot, in: geo.size), open: open)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
    }
}

/// The birds in one spot: in the brooder, or on the perch.
private struct BirdSpotView: View {
    let spot: BirdSpot
    let birds: [Bird]
    let area: CGRect
    let open: (UUID) -> Void

    var body: some View {
        switch spot {
        case .yard, .farYard:
            // Drawn inside the yard scene (`YardScene`), never on a flat panel.
            EmptyView()
        case .brooder:
            if !birds.isEmpty { BrooderBox(birds: birds, area: area, open: open) }
        case .roost:
            if !birds.isEmpty { RoostRows(birds: birds, area: area, open: open) }
        }
    }
}

/// A dashed box for the brooder, with the chicks pottering about inside.
private struct BrooderBox: View {
    let birds: [Bird]
    let area: CGRect
    let open: (UUID) -> Void

    var body: some View {
        // Chicks keep inside the box. A tiny box (first layout pass) shrinks to its centre, never to null.
        let inner: CGRect = area.insetBy(dx: min(Space.xl, area.width / 2), dy: min(Space.xl, area.height / 2))
        ZStack(alignment: .topLeading) {
            ArtPlaceholder(label: "brooder")
                .frame(width: area.width, height: area.height)
                .position(x: area.midX, y: area.midY)
                .allowsHitTesting(false)
            ForEach(birds) { bird in
                WanderingBird(bird: bird, area: inner, open: open)
            }
        }
    }
}

/// The coop birds asleep, or waiting for the door: in rows on dashed perches.
private struct RoostRows: View {
    @Environment(\.palette) private var palette
    let birds: [Bird]
    let area: CGRect
    let open: (UUID) -> Void

    var body: some View {
        let slots: [CGPoint] = FarmFlock.perchSlots(count: birds.count, in: area)
        let perches: [CGFloat] = Array(Set(slots.map(\.y))).sorted()
        ZStack(alignment: .topLeading) {
            ForEach(perches, id: \.self) { y in
                HLine()
                    .stroke(palette.inkMuted, style: Stitch.underline)
                    .frame(width: area.width, height: 2)
                    .position(x: area.midX, y: y + 20)
                    .accessibilityHidden(true)
            }
            ForEach(Array(birds.enumerated()), id: \.element.id) { i, bird in
                RoostingBird(bird: bird, at: slots[i], open: open)
            }
        }
    }
}

/// One bird on the perch. It stays put, but can still be tapped and petted.
private struct RoostingBird: View {
    @Environment(GameStore.self) private var store
    let bird: Bird
    let at: CGPoint
    let open: (UUID) -> Void

    var body: some View {
        let size: CGFloat = FarmFlock.size(of: bird, in: store.state)
        // Feet on the perch: the blob's bottom sits on the line under the slot.
        BirdBlob(bird: bird, size: size, held: .constant(false), open: open)
            .position(x: at.x, y: at.y + 20 - max(44, size) / 2)
    }
}

/// A chick that potters about the brooder box: every few seconds it walks a little way, or stops to peck.
/// With Reduce Motion on, it stands still.
private struct WanderingBird: View {
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let bird: Bird
    let area: CGRect
    let open: (UUID) -> Void
    /// Where the bird is (or is walking to), as fractions of its area.
    @State private var spot: CGPoint
    @State private var pecking = false
    /// A finger is on the bird: it waits, and does not walk away mid-pet.
    @State private var held = false

    init(bird: Bird, area: CGRect, open: @escaping (UUID) -> Void) {
        self.bird = bird
        self.area = area
        self.open = open
        _spot = State(initialValue: FarmFlock.startSpot(for: bird.id))
    }

    var body: some View {
        let size: CGFloat = FarmFlock.size(of: bird, in: store.state)
        BirdBlob(bird: bird, size: size, held: $held, open: open)
            .rotationEffect(.degrees(pecking ? 10 : 0), anchor: .bottom)
            .offset(y: pecking ? size * 0.08 : 0)
            .position(x: area.minX + spot.x * area.width, y: area.minY + spot.y * area.height)
            .task(id: reduceMotion) { await wander() }
    }

    /// One slow loop per bird. SwiftUI animates each walk, so the loop only wakes every 2–4 seconds.
    private func wander() async {
        guard !reduceMotion else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Double.random(in: 2...4)))
            if Task.isCancelled { return }
            if held { continue }
            if Double.random(in: 0..<1) < 0.3 {
                await peck()
            } else {
                walk()
            }
        }
    }

    private func walk() {
        let target = CGPoint(
            x: min(1, max(0, spot.x + CGFloat.random(in: -0.3...0.3))),
            y: min(1, max(0, spot.y + CGFloat.random(in: -0.3...0.3))))
        let dx: CGFloat = (target.x - spot.x) * area.width
        let dy: CGFloat = (target.y - spot.y) * area.height
        // About 24 pt a second: an amble, not a run.
        let seconds: Double = min(3, max(0.8, Double((dx * dx + dy * dy).squareRoot()) / 24))
        withAnimation(.easeInOut(duration: seconds)) { spot = target }
    }

    private func peck() async {
        for _ in 0..<2 {
            withAnimation(.easeOut(duration: 0.12)) { pecking = true }
            try? await Task.sleep(for: .milliseconds(160))
            withAnimation(.easeIn(duration: 0.14)) { pecking = false }
            try? await Task.sleep(for: .milliseconds(220))
        }
    }
}

/// One bird you can touch on the Barn: painted, at rest, when its body shape has a kit, else a blob.
/// See `PettableBird` for the touch.
struct BirdBlob: View {
    @Environment(GameStore.self) private var store
    let bird: Bird
    let size: CGFloat
    @Binding var held: Bool
    let open: (UUID) -> Void

    var body: some View {
        let colours = ChickenColours(bird: bird, state: store.state)
        let kit: PartKit? = PartKit.kit(for: colours)
        // A painted bird is as wide as its rig's frame, so the touch area is too.
        let width: CGFloat = kit == nil ? size : size * ChickenRigMetrics.widthRatio
        PettableBird(bird: bird, touch: CGSize(width: width, height: size), held: $held, open: open) {
            if let kit {
                PaintedChickenRig(kit: kit, colours: colours, height: size)
            } else {
                BirdSwatch(bird: bird, state: store.state, size: size)
            }
        }
    }
}

/// One bird you can touch, in any art (a blob on the barn, a rigged chicken in the yard scene).
/// A short touch opens its card; press and rub to pet it (once a gesture). A pet sends `.pet`: the bird
/// wiggles and a few dabs float up. Already petted today, it just leans in.
struct PettableBird<Art: View>: View {
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let bird: Bird
    /// The drawn bird's size on screen. The touch area is at least 44 pt each way, feet at the bottom.
    let touch: CGSize
    @Binding var held: Bool
    let open: (UUID) -> Void
    let art: Art
    @State private var rub = RubTracker()
    /// True while a finger is down. Resets itself if the system takes the touch (no `onEnded` then).
    @GestureState private var touching = false
    /// -1...1: how far the bird leans with the rub.
    @State private var squish: CGFloat = 0
    @State private var leaning = false
    /// Goes up by one each time a pet lands, to float the dabs.
    @State private var pets = 0

    init(
        bird: Bird, touch: CGSize, held: Binding<Bool>, open: @escaping (UUID) -> Void,
        @ViewBuilder art: () -> Art
    ) {
        self.bird = bird
        self.touch = touch
        self._held = held
        self.open = open
        self.art = art()
    }

    var body: some View {
        art
            .scaleEffect(x: 1 + abs(squish) * 0.08, y: 1 - abs(squish) * 0.1, anchor: .bottom)
            .rotationEffect(.degrees(Double(squish) * 7), anchor: .bottom)
            .scaleEffect(leaning ? 1.1 : 1, anchor: .bottom)
            .overlay(alignment: .top) { RisingDabs(trigger: pets) }
            // At least 44 pt to touch, even for a chick. Feet at the bottom, on the ground or the perch.
            .frame(width: max(44, touch.width), height: max(44, touch.height), alignment: .bottom)
            .contentShape(Rectangle())
            .gesture(rubGesture)
            .onChange(of: touching) { _, now in
                held = now
                if !now { withAnimation(.spring(duration: 0.4, bounce: 0.5)) { squish = 0 } }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(bird.name)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Opens the bird card")
            .accessibilityAction(.default) { openCard() }
            .accessibilityAction(named: "Pet") { pet() }
    }

    /// Global space: the bird squishes under the finger, so its own space moves.
    private var rubGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .updating($touching) { _, state, _ in state = true }
            .onChanged { value in rubbed(value) }
            .onEnded { _ in letGo() }
    }

    private func rubbed(_ value: DragGesture.Value) {
        // A new press starts a new rub, even if the last one was cut off.
        if rub.start != value.startLocation { rub = RubTracker(start: value.startLocation) }
        let turned: Bool = rub.add(value.location)
        if rub.distance > RubTracker.tapSlop, !reduceMotion {
            let lean: CGFloat = (value.location.x - value.startLocation.x) / 24
            withAnimation(.interactiveSpring(duration: 0.18)) { squish = min(1, max(-1, lean)) }
        }
        if turned { Haptics.tick() }
        if rub.isRub, !rub.petted {
            rub.petted = true
            pet()
        }
    }

    private func letGo() {
        if rub.isTap { openCard() }
        rub = RubTracker()
    }

    private func openCard() {
        Haptics.tap()
        Sound.play(.cluck)
        open(bird.id)
    }

    /// The engine allows one pet a bird a day. A second pet is not an error: the bird leans in.
    private func pet() {
        let events: [GameEvent] = store.run(.pet(bird.id))
        if events.contains(.handled(bird.id, .pet)) {
            Haptics.petted()
            Sound.play(.cluck)
            pets += 1
        } else if events.contains(.rejected(.alreadyPettedToday)) {
            Haptics.leanIn()
            leanIn()
        }
    }

    private func leanIn() {
        withAnimation(.spring(duration: 0.3)) { leaning = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.spring(duration: 0.5)) { leaning = false }
        }
    }
}

/// Three small buff dabs that float up and fade when a pet lands. Reduce Motion: they fade in place.
private struct RisingDabs: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let trigger: Int

    private struct Rise {
        var y: CGFloat = 0
        var opacity: Double = 0
    }

    var body: some View {
        let height: CGFloat = reduceMotion ? 0 : 36
        HStack(alignment: .bottom, spacing: Space.xs) {
            Dab(colour: Pigment.buffNotice, size: 7)
            Dab(colour: Pigment.buffNotice, size: 10).offset(y: -6)
            Dab(colour: Pigment.buffNotice, size: 7)
        }
        .keyframeAnimator(initialValue: Rise(), trigger: trigger) { content, rise in
            content.offset(y: rise.y).opacity(rise.opacity)
        } keyframes: { _ in
            KeyframeTrack(\.y) {
                LinearKeyframe(0, duration: 0.01)
                CubicKeyframe(-height, duration: 1.1)
            }
            KeyframeTrack(\.opacity) {
                LinearKeyframe(1, duration: 0.15)
                LinearKeyframe(1, duration: 0.45)
                LinearKeyframe(0, duration: 0.5)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Follows one press on a bird: how far the finger went, and how often it turned back.
/// Back-and-forth on either axis counts, so a rub up and down pets too.
struct RubTracker {
    /// Less movement than this, and the press was a tap.
    static let tapSlop: CGFloat = 10
    /// A stroke must go this far before a turn back counts (finger jitter does not).
    static let stroke: CGFloat = 6
    /// This much rubbing, with at least one turn, is a pet.
    static let rubDistance: CGFloat = 120
    /// Or this many turns.
    static let rubTurns = 3

    /// Where this press began. A different start is a new press.
    var start: CGPoint?
    private var last: CGPoint?
    private var across = Axis()
    private var down = Axis()
    private(set) var distance: CGFloat = 0
    private(set) var turns = 0
    /// This press already sent its pet.
    var petted = false

    init(start: CGPoint? = nil) { self.start = start }

    var isTap: Bool { distance < Self.tapSlop && !petted }
    var isRub: Bool { turns >= Self.rubTurns || (distance > Self.rubDistance && turns >= 1) }

    /// Adds a touch point. True when the stroke just turned back: one tick of the rub.
    mutating func add(_ point: CGPoint) -> Bool {
        guard let previous = last else {
            last = point
            return false
        }
        last = point
        let dx: CGFloat = point.x - previous.x
        let dy: CGFloat = point.y - previous.y
        distance += (dx * dx + dy * dy).squareRoot()
        let turnedAcross: Bool = across.add(dx)
        let turnedDown: Bool = down.add(dy)
        let turned: Bool = turnedAcross || turnedDown
        if turned { turns += 1 }
        return turned
    }

    /// One axis of the rub: the stroke so far and the direction of the last full stroke.
    private struct Axis {
        var sweep: CGFloat = 0
        var direction: CGFloat = 0

        /// Once a stroke is long enough, notes its direction. True when that direction is a turn back.
        mutating func add(_ delta: CGFloat) -> Bool {
            sweep += delta
            guard abs(sweep) >= RubTracker.stroke else { return false }
            let sign: CGFloat = sweep > 0 ? 1 : -1
            sweep = 0
            let turnedBack: Bool = direction != 0 && sign != direction
            direction = sign
            return turnedBack
        }
    }
}
