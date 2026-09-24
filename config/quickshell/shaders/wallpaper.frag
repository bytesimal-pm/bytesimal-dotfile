// Wallpaper effects in one pass: vacuum swirl, mouse parallax, glasses glint, dim.
// Compile after editing:
//   /usr/lib/qt6/bin/qsb --qt6 -o wallpaper.frag.qsb wallpaper.frag
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 mouse;      // cursor, -1..1 from the screen center
    vec2 center;     // spiral center (uv)
    vec4 lensA;      // glasses lenses: center xy, radius zw (uv)
    vec4 lensB;
    float aspect;    // width / height
    float zoom;      // > 1, leaves a margin for the parallax shift
    float bgShift;   // parallax of the spiral (uv)
    float fgShift;   // extra parallax of Shizuku (uv)
    float vacuum;    // 0 = off, 1 = everything pulled into the center (overshoots below 0 on release)
    float glint;     // sweep progress 0..1, off outside
    float dim;       // 0..1
};

layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D depth;   // white = Shizuku

// A diagonal band of light sweeping across one lens at position g (-1.5..1.5).
// x = the light, y = how much to shade the lens (the art is mostly white skin behind the
// glass, so the streak only shows against a slightly darker lens)
vec2 sweep(vec2 s, vec4 lens, float g) {
    vec2 e = (s - lens.xy) / lens.zw;
    float inside = 1.0 - smoothstep(0.75, 1.0, length(e));
    float t = dot(e, vec2(0.78, 0.62));
    float band = exp(-pow((t - g) / 0.16, 2.0)) + 0.6 * exp(-pow((t - g + 0.38) / 0.06, 2.0));
    return vec2(band, exp(-g * g)) * inside;
}

void main() {
    // Vacuum: shrink the picture into the spiral center
    vec2 p = (qt_TexCoord0 - center) * vec2(aspect, 1.0);
    float r = length(p);
    float v = vacuum;
    float rs = r * (1.0 + 3.0 * v * abs(v)) + max(v, 0.0) * 0.12;
    vec2 q = center + (r > 0.0 ? p / r * rs : vec2(0.0)) / vec2(aspect, 1.0);
    float hole = v > 0.0 ? smoothstep(0.0, 0.16 * v, r) * (1.0 - 0.6 * v * v) : 1.0;
    float edge = step(0.0, q.x) * step(q.x, 1.0) * step(0.0, q.y) * step(q.y, 1.0);

    // Parallax: the spiral moves a little, Shizuku (depth mask) more
    vec2 base = 0.5 + (q - 0.5) / zoom;
    vec2 m = mouse * vec2(1.0, 0.6);
    float d = texture(depth, base + m * bgShift).r;
    d = texture(depth, base + m * (bgShift + d * fgShift)).r;
    vec2 s = clamp(base + m * (bgShift + d * fgShift), 0.0, 1.0);

    vec3 col = texture(source, s).rgb;

    // Glint: light crosses the left lens, then the right one, then a small sparkle
    if (glint > 0.0 && glint < 1.0) {
        float g = glint * 4.0 - 1.6;
        vec2 la = sweep(s, lensA, g);
        vec2 lb = sweep(s, lensB, g - 0.7);
        col *= 1.0 - 0.3 * (la.y + lb.y);
        float light = la.x + lb.x;
        vec2 sp = (s - (lensB.xy + lensB.zw * vec2(0.6, -0.55))) * vec2(aspect, 1.0);
        float k = sin(3.14159 * clamp((glint - 0.6) / 0.4, 0.0, 1.0));
        float star = exp(-abs(sp.x) * 1400.0) * exp(-abs(sp.y) * 140.0)
                   + exp(-abs(sp.y) * 1400.0) * exp(-abs(sp.x) * 140.0)
                   + exp(-length(sp) * 400.0);
        col += vec3(0.8 * light + 0.9 * k * star);
    }

    col *= hole * edge * (1.0 - dim);
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
