// Skinning for a painted kit's soft parts (see ChickenSkin.swift, which does the same maths and is tested).
//
// A layer shader: for each pixel on screen it finds the places in the rest drawing whose paint lands there.
// Paint at rest point q lands at the blend of its bones' transforms of q, so the shader solves that
// backwards with Newton steps from each start the CPU sends, and draws what each finds, top first.

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

constant int floatsPerBone = 13;
constant int maxBones = 6;
constant int steps = 14;
constant int floatsPerStart = 7;
constant int maxStarts = 2 * maxBones;
// As `ChickenSkin.reachSlack`.
constant float reachSlack = 2.0;
// As `ChickenSkin.slowStep`.
constant float slowStep = 0.5;
// As `ChickenSkin.landed`.
constant float landed = 0.02;
// As `ChickenSkin.startReach`.
constant float startReach = 0.2;

struct SkinBone {
    float2 joint;
    float2 direction;
    float radius;
    float width;
    int parent;
    float2x2 linear;
    float2 shift;
};

static SkinBone readBone(device const float *skin, int i) {
    device const float *b = skin + i * floatsPerBone;
    SkinBone bone;
    bone.joint = float2(b[0], b[1]);
    bone.direction = float2(b[2], b[3]);
    bone.radius = max(b[4], 1e-4);
    bone.width = b[5];
    bone.parent = int(b[6]);
    // Columns: (a, b) and (c, d), so linear * p is (a x + c y, b x + d y), as `Affine.apply`.
    bone.linear = float2x2(float2(b[7], b[8]), float2(b[9], b[10]));
    bone.shift = float2(b[11], b[12]);
    return bone;
}

/// Where the skin puts rest point `q`, and in `slope` the blend of the bones' matrices there: the slope the
/// solve steps by. Weights as `ChickenSkin.weights(at:)`.
static float2 place(float2 q, thread const SkinBone *bones, int n, thread float2x2 &slope) {
    float f[maxBones];
    for (int i = 0; i < n; i++) {
        if (bones[i].parent < 0) { f[i] = 1.0; continue; }
        float2 d = q - bones[i].joint;
        float along = dot(d, bones[i].direction);
        float across = abs(d.y * bones[i].direction.x - d.x * bones[i].direction.y);
        float r = bones[i].radius;
        f[i] = smoothstep(-r, r, along) * (1.0 - smoothstep(bones[i].width, bones[i].width + r, across));
    }
    float2 sum = float2(0.0);
    float2x2 linear = float2x2(0.0);
    float total = 0.0;
    for (int i = 0; i < n; i++) {
        float share = 1.0;
        int at = i;
        for (int depth = 0; depth < maxBones && bones[at].parent >= 0; depth++) {
            int parent = bones[at].parent;
            share *= f[at];
            for (int k = at + 1; k < n; k++) {
                if (bones[k].parent == parent) { share *= 1.0 - f[k]; }
            }
            at = parent;
        }
        for (int c = 0; c < n; c++) {
            if (bones[c].parent == i) { share *= 1.0 - f[c]; }
        }
        sum += share * (bones[i].linear * q + bones[i].shift);
        linear += share * bones[i].linear;
        total += share;
    }
    if (total <= 1e-6) {
        slope = bones[0].linear;
        return bones[0].linear * q + bones[0].shift;
    }
    slope = linear * (1.0 / total);
    return sum / total;
}

/// Solves for the rest point that the skin puts at `position`, from a first guess `q` (a start's inverse of
/// it), as `ChickenSkin.solve`: each step goes by the blend of the bones' matrices at `q`, and where that
/// stops closing in (a bend, where the weights change fast), by the true slope, found by nudging `q`.
/// `miss` is how far from `position` the answer lands.
static float2 solve(float2 position, float2 q, thread const SkinBone *bones, int n, float nudge, float longest,
                    thread float &miss) {
    miss = 1.0e9;
    float last = 1.0e9;
    for (int k = 0; k < steps; k++) {
        float2x2 j;
        float2 at = place(q, bones, n, j);
        float off = length(position - at);
        // Landed: a fiftieth of a point, so a soft edge holds still from frame to frame.
        if (off < landed) { miss = off; return q; }
        // Too far to reach in the steps left, even at the longest step: no paint here.
        if (off > longest * float(steps - k) * reachSlack) { return q; }
        if (off > last * slowStep) {
            float2x2 unused;
            float2 dx = (place(q + float2(nudge, 0.0), bones, n, unused) - at) / nudge;
            float2 dy = (place(q + float2(0.0, nudge), bones, n, unused) - at) / nudge;
            j = float2x2(dx, dy);
        }
        last = off;
        float dj = determinant(j);
        if (abs(dj) < 1e-6) { break; }
        float2 move = float2x2(float2(j[1][1], -j[0][1]), float2(-j[1][0], j[0][0])) * (position - at) / dj;
        float size = length(move);
        if (size > longest) { move *= longest / size; }
        q += move;
    }
    float2x2 j;
    miss = length(position - place(q, bones, n, j));
    return q;
}

/// `skin`: `count` floats, `floatsPerBone` per bone. `starts`: `startCount` floats, `floatsPerStart` per start,
/// each a start's inverse and its bone, top part's first (`ChickenSkin.starts`). Where the bend folds, more than one rest
/// point lands on a pixel; each is drawn, in that order, top over bottom, as the parts would be. `nudge` finds
/// the true slope and `longest` caps a step, in points; `height` is the bird's. Outside `reach` (min x, min y, max x, max y) no paint can
/// land, so those pixels are clear at once.
[[ stitchable ]] half4 chickenSkin(float2 position, SwiftUI::Layer layer, device const float *skin, int count,
                                   device const float *starts, int startCount, float nudge, float longest,
                                   float4 reach, float height) {
    if (position.x < reach.x || position.y < reach.y || position.x > reach.z || position.y > reach.w) {
        return half4(0.0h);
    }
    int n = min(count / floatsPerBone, maxBones);
    if (n < 1) { return layer.sample(position); }
    SkinBone bones[maxBones];
    for (int i = 0; i < n; i++) { bones[i] = readBone(skin, i); }
    half4 out = half4(0.0h);
    float2 found[maxStarts];
    int foundCount = 0;
    int m = min(startCount / floatsPerStart, maxStarts);
    for (int o = 0; o < m; o++) {
        device const float *t = starts + o * floatsPerStart;
        float2 guess = float2x2(float2(t[0], t[1]), float2(t[2], t[3])) * position + float2(t[4], t[5]);
        // As `ChickenSkin.mayHold`: a guess well clear of its bone's paint would only find another bone's.
        int bone = int(t[6]);
        if (bone >= 0 && bone < n) {
            float2 d = guess - bones[bone].joint;
            float along = dot(d, bones[bone].direction);
            float across = abs(d.y * bones[bone].direction.x - d.x * bones[bone].direction.y);
            float slack = bones[bone].radius + startReach * height;
            if (along <= -slack || across >= bones[bone].width + slack) { continue; }
        }
        float miss;
        float2 q = solve(position, guess, bones, n, nudge, longest, miss);
        if (miss > 1.0) { continue; }
        // Two starts that find the same paint draw it once.
        bool seen = false;
        for (int f = 0; f < foundCount; f++) {
            if (distance(found[f], q) < 0.5) { seen = true; }
        }
        if (seen) { continue; }
        found[foundCount++] = q;
        half4 c = layer.sample(q);
        out += c * (1.0h - out.a);
        if (out.a > 0.995h) { break; }
    }
    return out;
}
