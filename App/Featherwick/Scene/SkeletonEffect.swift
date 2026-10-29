import SwiftUI

// The one SwiftUI piece of the skeleton: it moves a part by its bone. The maths is in `ChickenSkeleton.swift`.

/// Places a part on its bone for a pose: its own bone's turn, then each bone above it, then the hip's lift
/// (`Skeleton.transform`). One effect per part, whatever its depth.
///
/// Animatable: the whole pose is the animation data, so a pose set inside `withAnimation` (a blink, a glance,
/// sitting down) eases every bone together, and a still bird does not redraw. The part's view must fill the
/// rig's frame (`height × widthRatio` by `height`), as every rig part does: the transform is in that frame.
struct BoneEffect: GeometryEffect {
    /// Nil: the part rides no bone, so only the hip moves it.
    let bone: Bone?
    let rig: SkeletonRig
    var pose: ChickenPose
    let height: CGFloat
    /// A loose part sways after its bone (`FluffFollow`). Nil: it moves with its bone exactly.
    var follow: Follow? = nil

    // Nonisolated: `Animatable` asks for it so, and it reads only Sendable values (Swift 6, SE-0434).
    nonisolated var animatableData: PoseVector {
        get { PoseVector(pose.vector) }
        set { pose = ChickenPose(vector: newValue.values) }
    }

    nonisolated func effectValue(size: CGSize) -> ProjectionTransform {
        let t: Affine = Skeleton.transform(
            of: bone, rig: rig, pose: pose, height: Double(height), follow: follow)
        return ProjectionTransform(
            CGAffineTransform(
                a: CGFloat(t.a), b: CGFloat(t.b), c: CGFloat(t.c), d: CGFloat(t.d), tx: CGFloat(t.tx),
                ty: CGFloat(t.ty)))
    }
}

extension PoseVector: VectorArithmetic {}

extension View {
    /// Moves this part (drawn at rest, filling the rig's frame) with `bone` for `pose`. A part with
    /// `follow` is loose: it sways after its bone.
    func riding(
        _ bone: Bone?, rig: SkeletonRig, pose: ChickenPose, height: CGFloat, follow: Follow? = nil
    ) -> some View {
        modifier(BoneEffect(bone: bone, rig: rig, pose: pose, height: height, follow: follow))
    }
}

/// Bends a run of a kit's soft parts (drawn at rest, filling the rig's frame) by its skin for a pose
/// (`ChickenSkin`, `ChickenSkin.metal`). Animatable like `BoneEffect`, so a pose set inside `withAnimation`
/// bends smoothly, and a still bird does not redraw.
///
/// A layer effect draws only inside its view, so the frame gets a margin first (`SceneConstants.skinMargin`
/// heights on each side): a peck tips the head and tail past the frame. Every rest point the shader samples
/// lies inside that padded view, so it needs no sample offset. An offset grows the layer SwiftUI draws first
/// by that much on every side: the whole frame's worth made a large hen stall each frame (#116).
struct SkinEffect: ViewModifier, Animatable {
    let skin: ChickenSkin
    let rig: SkeletonRig
    /// A bone's sway after it moves (the tail). Bones not listed move exactly.
    let follows: [Bone: Follow]
    /// Which bone's paint is on top where the bend folds: indices into the skin's bones, top first.
    let order: [Int]
    var pose: ChickenPose
    let height: CGFloat

    nonisolated var animatableData: PoseVector {
        get { PoseVector(pose.vector) }
        set { pose = ChickenPose(vector: newValue.values) }
    }

    func body(content: Content) -> some View {
        let margin: CGFloat = height * SceneConstants.skinMargin
        let transforms: [Affine] = skin.bones.map { bone in
            Skeleton.transform(
                of: bone.bone, rig: rig, pose: pose, height: Double(height), follow: follows[bone.bone])
        }
        let floats: [Float] = skin.packed(
            transforms: transforms, height: Double(height), offset: CGPoint(x: margin, y: margin))
        return
            content
            .padding(margin)
            .layerEffect(
                ShaderLibrary.chickenSkin(
                    .floatArray(floats), .floatArray(order.map(Float.init)), .float(height * ChickenSkin.nudge),
                    .float(height * ChickenSkin.longestStep)),
                maxSampleOffset: .zero
            )
            .padding(-margin)
    }
}
