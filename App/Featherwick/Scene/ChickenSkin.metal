// Skinning for a painted kit's soft parts (see ChickenSkin.swift, which does the same maths and is tested).
//
// A distortion shader: for each pixel on screen it returns the place in the rest drawing to take the
// colour from. Paint at rest point q lands at the blend of its bones' transforms of q, so the shader
// solves that backwards with Newton steps from each bone, and keeps the start that lands nearest.

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

constant int floatsPerBone = 13;
constant int maxBones = 6;
constant int steps = 14;

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

/// Where the skin puts rest point `q`. Weights as `ChickenSkin.weights(at:)`.
static float2 place(float2 q, thread const SkinBone *bones, int n) {
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
        total += share;
    }
    return total > 1e-6 ? sum / total : bones[0].linear * q + bones[0].shift;
}

/// Solves for the rest point that the skin puts at `position`, from bone `start`'s own inverse. `miss` is
/// how far from `position` the answer lands.
/// With `halfway`, it starts halfway between the bone's transform and its parent's: where a bend folds three
/// deep (the throat in a peck), the middle layer lies between the two.
static float2 solve(float2 position, int start, bool halfway, thread const SkinBone *bones, int n, float nudge,
                    float longest, thread float &miss) {
    miss = 1.0e9;
    float2x2 m = bones[start].linear;
    float2 shift = bones[start].shift;
    if (halfway) {
        int parent = bones[start].parent;
        if (parent < 0) { return float2(-1.0e5); }
        m = (m + bones[parent].linear) * 0.5;
        shift = (shift + bones[parent].shift) * 0.5;
    }
    float det = determinant(m);
    if (abs(det) < 1e-6) { return float2(-1.0e5); }
    float2 q = float2x2(float2(m[1][1], -m[0][1]), float2(-m[1][0], m[0][0])) * (position - shift) / det;
    for (int k = 0; k < steps; k++) {
        float2 at = place(q, bones, n);
        // Landed: a tenth of a point is well under a pixel.
        if (length(position - at) < 0.1) { break; }
        float2 dx = (place(q + float2(nudge, 0.0), bones, n) - at) / nudge;
        float2 dy = (place(q + float2(0.0, nudge), bones, n) - at) / nudge;
        float2x2 j = float2x2(dx, dy);
        float dj = determinant(j);
        if (abs(dj) < 1e-6) { break; }
        float2 move = float2x2(float2(j[1][1], -j[0][1]), float2(-j[1][0], j[0][0])) * (position - at) / dj;
        float size = length(move);
        if (size > longest) { move *= longest / size; }
        q += move;
    }
    miss = length(position - place(q, bones, n));
    return q;
}

/// `skin`: `count` floats, `floatsPerBone` per bone. `order`: bone indices, the bone of the run's top part
/// first. Where the bend folds, more than one rest point lands on a pixel; each is drawn, in that order, top
/// over bottom, as the parts would be. `nudge` finds the slope and `longest` caps a step, in points.
[[ stitchable ]] half4 chickenSkin(float2 position, SwiftUI::Layer layer, device const float *skin, int count,
                                   device const float *order, int orderCount, float nudge, float longest) {
    int n = min(count / floatsPerBone, maxBones);
    if (n < 1) { return layer.sample(position); }
    SkinBone bones[maxBones];
    for (int i = 0; i < n; i++) { bones[i] = readBone(skin, i); }
    half4 out = half4(0.0h);
    float2 found[2 * maxBones];
    int foundCount = 0;
    for (int o = 0; o < 2 * min(orderCount, maxBones); o++) {
        int start = int(order[o / 2]);
        if (start < 0 || start >= n) { continue; }
        float miss;
        float2 q = solve(position, start, (o % 2) == 1, bones, n, nudge, longest, miss);
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
