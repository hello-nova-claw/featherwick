// The season ramp: one gradient-map shader for the whole farm scene (see SeasonRamp.swift).
//
// Each pixel carries a value and a material, not a colour:
//   R = value (0 dark ... 1 light). G and B = two material bits (0 or 1, soft only at edges).
// The material picks one of four ramps in a set; the value picks a colour along that ramp.
// Edge pixels blend the ramps by their bit weights, so a soft edge stays soft.

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// Floats per ramp: 4 colour stops, 3 floats (r, g, b) each.
constant int rampFloats = 12;
/// Ramps per set (one per material) and sets in the array (land, trees).
constant int setRamps = 4;
constant int allFloats = rampFloats * setRamps * 2;

/// The colour at `value` along ramp `ramp`: 4 evenly spaced stops, dark to light.
static float3 rampColour(device const float *ramps, int ramp, float value) {
    float x = clamp(value, 0.0, 1.0) * 3.0;
    int i = min(int(floor(x)), 2);
    float t = x - float(i);
    int at = ramp * rampFloats + i * 3;
    float3 a = float3(ramps[at], ramps[at + 1], ramps[at + 2]);
    float3 b = float3(ramps[at + 3], ramps[at + 4], ramps[at + 5]);
    return mix(a, b, t);
}

/// Turns a colour round the grey axis by `angle` radians: a small hue shift that keeps brightness.
static float3 hueTurn(float3 c, float angle) {
    float3 k = float3(0.57735);
    float cosA = cos(angle);
    return c * cosA + cross(k, c) * sin(angle) + k * dot(k, c) * (1.0 - cosA);
}

/// `ramps`: every ramp for this season (`allFloats` floats). `set`: 0 land, 1 trees.
/// `hueShift`: radians, for tree leaves only, so trees of one kind vary. `night`: 0 day, 1 night.
[[ stitchable ]] half4 seasonRamp(float2 position, half4 color, device const float *ramps, int count,
                                  float set, float hueShift, float night) {
    if (color.a <= 0.0h || count < allFloats) {
        return color;
    }
    // SwiftUI hands the shader premultiplied colour: undo that to read the channels.
    float alpha = float(color.a);
    float3 c = float3(color.rgb) / alpha;
    float value = c.r;
    float g = clamp(c.g, 0.0, 1.0);
    float b = clamp(c.b, 0.0, 1.0);
    int first = set > 0.5 ? setRamps : 0;

    // Material bits (G, B): 00 first ramp, 10 second, 11 third, 01 fourth.
    float3 m0 = rampColour(ramps, first + 0, value);
    float3 m1 = rampColour(ramps, first + 1, value);
    float3 m2 = rampColour(ramps, first + 2, value);
    float3 m3 = rampColour(ramps, first + 3, value);
    if (set > 0.5) {
        // In the tree set, 00 and 01 are leaves.
        m0 = hueTurn(m0, hueShift);
        m3 = hueTurn(m3, hueShift);
    }
    float3 out = m0 * (1.0 - g) * (1.0 - b) + m1 * g * (1.0 - b) + m2 * g * b + m3 * (1.0 - g) * b;

    // Night, as on the flat panels: less colour, then a blue-grey multiply.
    float luma = dot(out, float3(0.2126, 0.7152, 0.0722));
    out = mix(out, float3(luma), 0.45 * night);
    out *= mix(float3(1.0), float3(0.106, 0.133, 0.2), 0.62 * night);

    out = clamp(out, 0.0, 1.0);
    return half4(half3(out * alpha), color.a);
}
