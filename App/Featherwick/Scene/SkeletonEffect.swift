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
/// (`ChickenSkin`, `SkinMesh`, `ChickenSkin.metal`). Animatable like `BoneEffect`, so a pose set inside
/// `withAnimation` bends smoothly, and a still bird does not redraw.
///
/// The CPU moves the mesh's few hundred corners; the shader draws each pixel from the triangle that holds
/// it, with one transform and one sample. A shader that searched backwards for every pixel's paint made a
/// large hen stall (#116).
///
/// A layer effect draws only inside its view, and SwiftUI draws that view to a surface of its own each
/// frame. So the view is cut to just what the shader needs: the run's rest paint (it samples there) and
/// where this pose puts it (it draws there). Every sample lies inside, so it needs no sample offset.
struct SkinEffect: ViewModifier, Animatable {
    let skin: ChickenSkin
    let mesh: SkinMesh
    let rig: SkeletonRig
    /// A bone's sway after it moves (the tail). Bones not listed move exactly.
    let follows: [Bone: Follow]
    var pose: ChickenPose
    let height: CGFloat

    nonisolated var animatableData: PoseVector {
        get { PoseVector(pose.vector) }
        set { pose = ChickenPose(vector: newValue.values) }
    }

    func body(content: Content) -> some View {
        let h: Double = Double(height)
        let transforms: [Affine] = skin.bones.map { bone in
            Skeleton.transform(of: bone.bone, rig: rig, pose: pose, height: h, follow: follows[bone.bone])
        }
        let moved: [CGPoint] = mesh.moved(transforms: transforms, height: h)
        let rest: CGRect = mesh.restBounds(height: h)
        // A point of slack keeps the edge pixels' soft paint.
        let layer: CGRect = rest.union(mesh.reach(moved: moved)).insetBy(dx: -1, dy: -1).integral
        let offset = CGPoint(x: -layer.minX, y: -layer.minY)
        let packed: SkinMesh.Packed = mesh.packed(moved: moved, height: h, layer: layer, offset: offset)
        let corner: CGPoint = mesh.rest(0, height: h)
        return
            content
            .offset(x: offset.x, y: offset.y)
            .frame(width: layer.width, height: layer.height, alignment: .topLeading)
            .layerEffect(
                ShaderLibrary.chickenSkin(
                    .floatArray(packed.triangles), .floatArray(packed.tiles), .floatArray(packed.items),
                    .float4(
                        Float(corner.x + offset.x), Float(corner.y + offset.y), Float(mesh.cell * h),
                        Float(mesh.columns)),
                    .float4(
                        Float(packed.tileOrigin.x), Float(packed.tileOrigin.y), Float(packed.tile),
                        Float(packed.across)),
                    .float(Float(packed.down))),
                maxSampleOffset: .zero
            )
            .offset(x: layer.minX, y: layer.minY)
            .frame(width: height * ChickenRigMetrics.widthRatio, height: height, alignment: .topLeading)
    }
}
