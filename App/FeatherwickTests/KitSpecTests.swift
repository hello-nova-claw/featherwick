import Foundation
import Testing

@testable import Featherwick

/// `kit.json` and the skeleton it gives, with no images. Each part names its bone.
@Suite struct KitSpecTests {
    private func spec(_ parts: String, order: [String], motion: String = "{}") throws -> KitSpec {
        let json: String = """
            {"build": "heavy", "canvas": [2048, 2048], "groundPoint": [1130, 1889], "unit": 1673,
             "parts": \(parts), "drawOrder": [\(order.map { "\"\($0)\"" }.joined(separator: ", "))],
             "motion": \(motion)}
            """
        return try JSONDecoder().decode(KitSpec.self, from: Data(json.utf8))
    }

    /// Each part names its bone. A pivot sets that bone's joint, so a kit can have every bone.
    @Test func partsNameTheirBones() throws {
        let kit: KitSpec = try spec(
            """
            {"thigh": {"bone": "thighFront", "pivot": [0.03, 0.30]},
             "shank": {"bone": "shankFront", "pivot": [-0.02, 0.20]},
             "toes": {"bone": "toesFront", "pivot": [0.0, 0.03]},
             "body": {"bone": "body", "pivot": [-0.05, 0.40]},
             "neck": {"bone": "neckLow", "pivot": [0.15, 0.60]},
             "hackle": {"bone": "neckHigh", "pivot": [0.22, 0.72]},
             "head": {"bone": "head", "pivot": [0.29, 0.79]},
             "comb": {"bone": "head", "token": "comb"}}
            """, order: ["thigh", "shank", "toes", "body", "neck", "hackle", "head", "comb"])
        let problems: [String] = kit.problems(files: Set(kit.drawOrder.map { "\($0).png" }))
        #expect(problems == [])
        let rig: SkeletonRig = kit.skeleton
        #expect(rig.has(.neckHigh) && rig.has(.shankFront) && rig.has(.toesFront))
        #expect(rig.bends(.front))
        #expect(!rig.has(.thighBack))
        #expect(rig.feet[.front] == CGPoint(x: 0.0, y: 0.03))
        #expect(kit.bone(of: "comb") == .head)
        #expect(rig.chain(of: .head) == [.head, .neckHigh, .neckLow, .body])
        // The bare leg takes the leg token; the feathered thigh does not.
        #expect(KitToken.implied(for: "shank", in: kit) == .legs)
        #expect(KitToken.implied(for: "toes", in: kit) == .legs)
        #expect(KitToken.implied(for: "thigh", in: kit) == .feathers)
        #expect(KitToken.implied(for: "hackle", in: kit) == .feathers)
        #expect(KitToken.implied(for: "head", in: kit) == .hackle)
    }

    /// A one-piece leg is a stiff thigh with no shank: it swings at the hip, its foot is straight below,
    /// and it is bare, so it takes the leg token. The kit's motion keys set its angles and step.
    @Test func aOnePieceLegIsAStiffBareThigh() throws {
        let kit: KitSpec = try spec(
            """
            {"leg": {"bone": "thighFront", "pivot": [0.032, 0.113]},
             "body": {"bone": "body", "pivot": [-0.052, 0.113]},
             "head": {"bone": "head", "pivot": [0.29, 0.79]},
             "eye": {"bone": "head", "token": "eye"}}
            """, order: ["leg", "body", "head", "eye"], motion: #"{"legSwing": 22, "peckHeadDip": 40}"#)
        #expect(kit.problems(files: Set(kit.drawOrder.map { "\($0).png" })) == [])
        let rig: SkeletonRig = kit.skeleton
        #expect(rig.has(.thighFront) && !rig.bends(.front))
        #expect(rig.feet[.front] == CGPoint(x: 0.032, y: 0))
        #expect(rig.motion.peckHeadDip == 40)
        #expect(abs(rig.motion.stepLength - 2 * 0.113 * tan(22 * Double.pi / 180)) < 1e-12)
        #expect(KitToken.implied(for: "leg", in: kit) == .legs)
        #expect(KitToken.implied(for: "body", in: kit) == .feathers)
    }

    /// An old kit (joints by `rotates`, parts by `ridesOn`) names no bones. It has no body joint, so it
    /// does not load, and the path rig draws the bird.
    @Test func anOldKitHasNoSkeleton() throws {
        let kit: KitSpec = try spec(
            """
            {"body": {"pivot": [-0.052, 0.113], "rotates": "bodyTilt"},
             "head": {"pivot": [0.29, 0.79], "rotates": "headDip", "ridesOn": "body"}}
            """, order: ["body", "head"])
        let problems: [String] = kit.problems(files: Set(kit.drawOrder.map { "\($0).png" }))
        #expect(problems.contains("no part sets the joint of body"))
        #expect(problems.contains("body has a pivot but no bone"))
        #expect(kit.skeleton.joints.isEmpty)
    }

    /// A bone name the skeleton does not have, or two pivots for one bone, is a broken kit.
    @Test func badBonesAreReported() throws {
        let kit: KitSpec = try spec(
            """
            {"wing": {"bone": "wing", "pivot": [0.0, 0.5]},
             "body": {"bone": "body", "pivot": [-0.05, 0.40]},
             "belly": {"bone": "body", "pivot": [0.0, 0.30]}}
            """, order: ["wing", "body", "belly"])
        let problems: [String] = kit.problems(files: Set(kit.drawOrder.map { "\($0).png" }))
        #expect(problems.contains("wing rides unknown bone wing"))
        #expect(problems.contains("body and belly both set the joint of body"))
    }

    /// A loose part reads its amount and root; a wild amount, or a loose part on no bone, is a problem.
    @Test func loosePartsFollow() throws {
        let kit: KitSpec = try spec(
            """
            {"body": {"bone": "body", "pivot": [-0.05, 0.40]},
             "tail": {"bone": "body", "follow": {"amount": 0.8, "root": [-0.14, 0.70]}},
             "fluff": {"bone": "body", "follow": {"amount": 1}},
             "whip": {"bone": "body", "follow": {"amount": 5}},
             "cloud": {"follow": {"amount": 1}}}
            """, order: ["body", "tail", "fluff", "whip", "cloud"])
        #expect(kit.follow(of: "tail") == Follow(amount: 0.8, root: CGPoint(x: -0.14, y: 0.70)))
        #expect(kit.follow(of: "fluff") == Follow(amount: 1, root: nil))
        #expect(kit.follow(of: "body") == nil)
        let problems: [String] = kit.problems(files: Set(kit.drawOrder.map { "\($0).png" }))
        #expect(problems.contains("follow of whip is not 0 to 2"))
        #expect(problems.contains("cloud follows but rides no bone"))
        #expect(problems.count == 2)
    }

    /// Every bone has a kit name, and the name reads back.
    @Test func boneNamesRoundTrip() {
        for bone in Bone.allCases { #expect(Bone(kitName: bone.kitName) == bone) }
        #expect(Bone.shankFront.kitName == "shankFront")
    }
}
