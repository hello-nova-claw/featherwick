// Skinning for a painted kit's soft parts: the mesh the CPU moved (SkinMesh.swift), drawn in one pass.
//
// Each triangle of the mesh comes with the matrix that takes a pixel where the pose put it back to the
// rest drawing, measured from the triangle's first corner. A pixel looks up its tile, tests the few triangles listed there, top first, and draws the
// rest paint of each one that holds it. No search: one transform and one sample a triangle.
// `SkinMesh.sources(of:packed:grid:height:)` does the same in Swift, and the tests check it there.

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// As `SkinMesh.floatsPerTriangle`.
constant int floatsPerTriangle = 9;
// As `SkinMesh.maxFolds`: at most this many layers of paint on one pixel, where the bend folds over itself.
constant int maxFolds = 4;
// As `SkinMesh.edge`: how far past its edges, in cells, a triangle still holds a pixel, so a pixel on the
// edge two triangles share is never held by neither.
constant float edge = 0.001;
// Paint fainter than this is clear: it neither shows nor counts as a fold.
constant half clear = 0.004h;

/// `triangles`: `floatsPerTriangle` floats each, top first (`SkinMesh.Packed`). `tiles` and `items`: the
/// triangles that may cover each tile. `grid`: the rest grid's first corner (x, y, in the layer), its cell's
/// side in points, and its columns. `tileGrid`: the first tile's corner (x, y), a tile's side, and tiles a
/// row; `down`: tiles a column.
[[ stitchable ]] half4 chickenSkin(float2 position, SwiftUI::Layer layer, device const float *triangles,
                                   int triangleCount, device const float *tiles, int tileCount,
                                   device const float *items, int itemCount, float4 grid, float4 tileGrid,
                                   float down) {
    int across = int(tileGrid.w);
    int tx = int(floor((position.x - tileGrid.x) / tileGrid.z));
    int ty = int(floor((position.y - tileGrid.y) / tileGrid.z));
    if (tx < 0 || ty < 0 || tx >= across || ty >= int(down)) { return half4(0.0h); }
    int tile = ty * across + tx;
    if (tile + 1 >= tileCount) { return half4(0.0h); }
    int first = int(tiles[tile]);
    int last = min(int(tiles[tile + 1]), itemCount);
    int count = triangleCount / floatsPerTriangle;
    half4 out = half4(0.0h);
    float2 found[maxFolds];
    int foundCount = 0;
    for (int k = first; k < last; k++) {
        int i = int(items[k]);
        if (i < 0 || i >= count) { continue; }
        device const float *t = triangles + i * floatsPerTriangle;
        // From the triangle's first moved corner back to its first rest corner, in cells: u across, v up,
        // each 0 to 1 inside the cell. Offsets from a corner stay small, so a squashed triangle still lands.
        float2 d = float2x2(float2(t[0], t[1]), float2(t[2], t[3])) * (position - float2(t[4], t[5])) / grid.z;
        float u = d.x;
        float v = -d.y;
        if (!(u >= -edge && u <= 1.0 + edge && v >= -edge && v <= 1.0 + edge)) { continue; }
        if (t[8] < 0.5 ? (v > u + edge) : (v < u - edge)) { continue; }
        float2 q = float2(grid.x + (t[6] + u) * grid.z, grid.y - (t[7] + v) * grid.z);
        // Two triangles that share an edge find the same paint there: draw it once.
        bool seen = false;
        for (int f = 0; f < foundCount; f++) {
            if (distance(found[f], q) < 0.5) { seen = true; }
        }
        if (seen) { continue; }
        half4 c = layer.sample(q);
        // A deep fold lays the clear margin round the paint over itself many times: only paint counts.
        if (c.a < clear) { continue; }
        found[foundCount++] = q;
        out += c * (1.0h - out.a);
        if (out.a > 0.995h || foundCount == maxFolds) { break; }
    }
    return out;
}
