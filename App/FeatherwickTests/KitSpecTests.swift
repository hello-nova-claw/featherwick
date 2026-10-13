import Foundation
import Testing

@testable import Featherwick

/// `kit.json` and the skeleton it gives, with no images: format 1 (`rotates`) and format 2 (`bone`).
@Suite struct KitSpecTests {
    private func spec(_ parts: String, order: [String], motion: String = "{}") throws -> KitSpec {
        let json: String = """
            {"build": "heavy", "canvas": [2048, 2048], "groundPoint": [1130, 1889], "unit": 1673,
             "parts": \(parts), "drawOrder": [\(order.map { "\"\($0)\"" }.joined(separator: ", "))],
             "motion": \(motion)}
            """
        return try JSONDecoder().decode(KitSpec.self, from: Data(json.utf8))
    }

    /// Format 2: each part names its bone. A pivot sets that bone's joint, so a kit can have every bone.
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
        #expect(kit.carrierBone(of: "comb") == .head)
        #expect(rig.chain(of: .head) == [.head, .neckHigh, .neckLow, .body])
        // The bare leg takes the leg token; the feathered thigh does not.
        #expect(KitToken.implied(for: "shank", in: kit) == .legs)
        #expect(KitToken.implied(for: "toes", in: kit) == .legs)
        #expect(KitToken.implied(for: "thigh", in: kit) == .feathers)
        #expect(KitToken.implied(for: "hackle", in: kit) == .feathers)
        #expect(KitToken.implied(for: "head", in: kit) == .hackle)
    }

    /// Format 1 still loads: `rotates` names a joint kind, and a one-piece leg is a stiff thigh with the
    /// leg token.
    @Test func formatOneStillWorks() throws {
        let kit: KitSpec = try spec(
            """
            {"leg_front": {"pivot": [0.032, 0.113], "rotates": "legFront"},
             "body": {"pivot": [-0.052, 0.113], "rotates": "bodyTilt"},
             "head": {"pivot": [0.29, 0.79], "rotates": "headDip", "ridesOn": "body"},
             "eye": {"ridesOn": "head", "token": "eye"}}
            """, order: ["leg_front", "body", "head", "eye"], motion: #"{"legSwing": 22, "peckHeadDip": 40}"#)
        #expect(kit.problems(files: Set(kit.drawOrder.map { "\($0).png" })) == [])
        let rig: SkeletonRig = kit.skeleton
        #expect(rig.has(.thighFront) && !rig.bends(.front))
        #expect(rig.feet[.front] == CGPoint(x: 0.032, y: 0))
        #expect(kit.carrierBone(of: "eye") == .head)
        #expect(rig.motion.peckHeadDip == 40)
        #expect(abs(rig.motion.stepLength - 2 * 0.113 * tan(22 * Double.pi / 180)) < 1e-12)
        #expect(KitToken.implied(for: "leg_front", in: kit) == .legs)
        #expect(KitToken.implied(for: "body", in: kit) == .feathers)
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

    /// Every bone has a kit name, and the name reads back.
    @Test func boneNamesRoundTrip() {
        for bone in Bone.allCases { #expect(Bone(kitName: bone.kitName) == bone) }
        #expect(Bone.shankFront.kitName == "shankFront")
    }
}
