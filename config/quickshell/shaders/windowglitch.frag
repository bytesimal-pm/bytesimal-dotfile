// Window open/close glitch, drawn over the live window (transparent where it's uncovered).
// Open: black & white static covering the window tears away in slices and blocks.
// Close: static covers the window, then collapses like a CRT turning off (line, dot, gone).
// Drag: a few thin torn slices and a ghost outline trailing the moving window.
// Compile after editing:
//   /usr/lib/qt6/bin/qsb --qt6 -o windowglitch.frag.qsb windowglitch.frag
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;      // seconds since the start
    float progress;  // 0..1
    float mode;      // 0 = open, 1 = close, 2 = drag
    float seed;      // random per effect
    vec2 size;       // rect size in pixels
    float radius;    // corner rounding in pixels (matches Hyprland's)
    float strength;  // drag: 0..1
    vec2 dir;        // drag: motion direction (unit, pixels)
    float margin;    // drag: pixels around the window inside the rect
};

float hash(float n) { return fract(sin(n * 12.9898 + seed * 78.233) * 43758.5453); }
float hash2(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233)) + seed * 3.7) * 43758.5453); }

// Static with scanlines and a rolling line, in 0..1
float staticAt(vec2 uv, float tick) {
    float v = hash2(floor(uv * size / 2.0) + tick * 0.37);
    v = 0.08 + v * 0.35;
    v *= 1.0 - 0.35 * (0.5 + 0.5 * sin(uv.y * size.y * 1.6));
    float y0 = fract(time * 2.2 + seed);
    v += exp(-pow((uv.y - y0) * size.y / 3.0, 2.0)) * 0.8;
    return v;
}

void main() {
    vec2 uv = qt_TexCoord0;
    float tick = floor(time * 24.0);
    float v;
    float a;

    if (mode > 1.5) {
        // Drag: the window is the rect minus `margin` on each side
        vec2 px = uv * size;
        vec2 lo = vec2(margin);
        vec2 hi = size - margin;
        float row = floor(px.y / 4.0);
        v = staticAt(uv, tick);
        a = 0.0;
        // A few thin slices, torn back against the motion, sticking out past the edge
        if (hash(row + tick * 3.1) > 1.0 - 0.05 * strength) {
            float shift = -dir.x * (10.0 + hash(row * 1.7 + tick) * 30.0) * strength;
            float x = px.x - shift;
            if (x >= lo.x && x <= hi.x && px.y >= lo.y && px.y <= hi.y) {
                a = 0.75;
                if (hash(row * 5.1 + tick) > 0.7) v = 1.0 - v * 0.3;
            }
        }
        // Faint outline lagging behind
        vec2 g = px + dir * 14.0 * strength;
        vec2 d = min(g - lo, hi - g);
        bool inRect = all(greaterThanEqual(d, vec2(0.0)));
        if (inRect && min(d.x, d.y) < 1.0 && hash(tick + 0.3) > 0.25) {
            v = 1.0;
            a = max(a, 0.5 * strength);
        }
        a *= min(1.0, strength * 2.0);
    } else if (mode < 0.5) {
        // Open: cover 1 -> 0, in jumps
        float cover = 1.0 - smoothstep(0.1, 0.95, progress);
        float rows = 10.0 + floor(24.0 * hash(tick + 0.5));
        float row = floor(uv.y * rows);
        float shift = (hash(row + tick * 7.1) - 0.5) * 0.12 * cover;
        vec2 p = vec2(uv.x + shift, uv.y);
        vec2 cell = floor(p * vec2(12.0, 12.0 * size.y / max(size.x, 1.0)));
        bool rowOn = hash(row * 1.3 + tick * 0.5) < cover;
        bool cellOn = hash2(cell + tick) < cover * 0.9;
        a = (rowOn || cellOn) ? 1.0 : 0.0;
        v = staticAt(p, tick);
        if (a > 0.0 && hash(row * 5.1 + tick * 3.0) > 1.0 - 0.12 * cover)
            v = 1.0 - v * 0.3;   // blown-out white slice
        // Flickering white edge early on
        vec2 px = uv * size;
        float edge = min(min(px.x, size.x - px.x), min(px.y, size.y - px.y));
        if (edge < 1.5 && progress < 0.5 && hash(tick) > 0.3) {
            v = 1.0;
            a = 1.0;
        }
    } else {
        // Close: full static, then squeeze to a line, then to a dot
        float sy = 1.0 - smoothstep(0.35, 0.7, progress) * 0.995;
        float sx = 1.0 - smoothstep(0.7, 0.92, progress) * 0.99;
        vec2 c = (uv - 0.5) / vec2(sx, sy) + 0.5;
        bool inside = all(greaterThanEqual(c, vec2(0.0))) && all(lessThanEqual(c, vec2(1.0)));
        float row = floor(c.y * 16.0);
        c.x += (hash(row + tick * 7.1) - 0.5) * 0.08 * (1.0 - sy);
        v = staticAt(c, tick);
        // Brighter as it shrinks, like the last bit of a CRT beam
        v = mix(v, 1.0, smoothstep(0.4, 0.75, progress));
        a = inside ? 1.0 - smoothstep(0.9, 1.0, progress) : 0.0;
    }

    // Rounded corners like the window (open/close only, the drag rect has a margin)
    vec2 q = abs(uv * size - size * 0.5) - (size * 0.5 - radius);
    if (mode < 1.5)
        a *= 1.0 - smoothstep(-0.5, 0.5, length(max(q, 0.0)) - radius);

    fragColor = vec4(vec3(clamp(v, 0.0, 1.0)), 1.0) * a * qt_Opacity;
}
