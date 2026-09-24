// Workspace switch glitch: black & white, torn slices, displaced/inverted blocks, a ghost
// copy, scanlines, static and a rolling line. Everything scales with `strength` (0 = clean).
// Compile after editing:
//   /usr/lib/qt6/bin/qsb --qt6 -o glitch.frag.qsb glitch.frag
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;      // seconds since the switch
    float strength;  // 0..1
    float seed;      // random per switch
    float hasFrame;  // 1 = source holds a screen capture, 0 = static only
};

layout(binding = 1) uniform sampler2D source;

float hash(float n) { return fract(sin(n * 12.9898 + seed * 78.233) * 43758.5453); }
float hash2(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233)) + seed * 3.7) * 43758.5453); }

float grab(vec2 uv) {
    if (hasFrame < 0.5) return 0.0;
    vec3 c = texture(source, clamp(uv, 0.0, 1.0)).rgb;
    return dot(c, vec3(0.299, 0.587, 0.114));
}

void main() {
    vec2 uv = qt_TexCoord0;
    float s = strength;
    float tick = floor(time * 24.0);   // the pattern jumps 24 times a second

    // Horizontal slices, some torn sideways
    float rows = 14.0 + floor(30.0 * hash(tick + 0.5));
    float row = floor(uv.y * rows);
    float shift = hash(row + tick * 7.1) > 1.0 - 0.5 * s ? (hash(row * 3.3 + tick) - 0.5) * 0.3 * s : 0.0;
    shift += (hash2(vec2(floor(uv.y * 360.0), tick)) - 0.5) * 0.006 * s;   // fine jitter
    vec2 p = vec2(uv.x + shift, uv.y);

    // Blocks: displaced, some inverted
    vec2 cell = floor(uv * vec2(16.0, 9.0) * (1.0 + floor(hash(tick * 1.3) * 3.0)));
    float b = hash2(cell + tick);
    bool invert = false;
    if (b > 1.0 - 0.09 * s) {
        p += (vec2(hash2(cell * 1.7 + tick), hash2(cell * 2.3 - tick)) - 0.5) * 0.12;
        invert = hash2(cell + tick * 0.7) > 0.7;
    }

    // Picture + a bright ghost copy offset sideways (a "luma split" instead of an RGB split)
    float v = grab(p);
    float ghost = grab(p + vec2(0.018 * s * (hash(tick) - 0.3), 0.0));
    v = max(v, ghost * 0.75 * s);
    v = smoothstep(0.06 * s, 1.0 - 0.12 * s, v);   // crush the contrast
    if (invert) v = 1.0 - v;

    // Whole rows blown out to black or white
    if (hash(row * 5.1 + tick * 3.0) > 1.0 - 0.06 * s)
        v = step(0.5, hash(row + tick));

    // Scanlines, static, a line rolling down
    v *= 1.0 - 0.3 * s * (0.5 + 0.5 * sin(uv.y * 1400.0));
    float noise = hash2(floor(uv * vec2(960.0, 540.0)) + tick * 0.37);
    v = mix(v, noise, (hasFrame > 0.5 ? 0.2 : 0.6) * s);
    float y0 = fract(time * 1.8 + seed);
    v += exp(-pow((uv.y - y0) / 0.004, 2.0)) * 0.7 * s;

    fragColor = vec4(vec3(clamp(v, 0.0, 1.0)), 1.0) * qt_Opacity;
}
