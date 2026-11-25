shader_type canvas_item;

uniform float proximity : hint_range(0.0, 1.1) = 0.16;
uniform float surge_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 core_color : source_color = vec4(0.012, 0.006, 0.025, 1.0);
uniform vec4 rim_color : source_color = vec4(0.62, 0.36, 0.94, 0.72);

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
        mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
        u.y
    );
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p = p * 2.03 + vec2(17.1, 9.2);
        a *= 0.5;
    }
    return v;
}

void fragment() {
    float t = TIME;
    float n1 = fbm(vec2(UV.y * 5.5 - t * 1.4, UV.x * 2.5 - t * 0.9));
    float n2 = fbm(vec2(UV.y * 11.0 + t * 2.2, UV.x * 4.0 + t * 1.3));
    float bulge = sin(UV.y * 3.14159) * 0.08;
    float edge = 0.06 + proximity * 0.34 + bulge + (n1 - 0.5) * 0.12 + (n2 - 0.5) * 0.045;
    edge += surge_intensity * 0.03 * sin(UV.y * 18.0 + t * 12.0);

    float dist = UV.x - edge;
    float body_mask = smoothstep(0.015, -0.02, dist);
    float mist_mask = smoothstep(0.16, -0.02, dist) * (0.35 + proximity * 0.35);

    // Glossy oily moonlight sheen along the churning liquid crest
    float crest_rim = smoothstep(0.025, 0.0, abs(dist)) * (0.55 + 0.45 * n2);
    float oil_sheen = smoothstep(0.58, 0.85, n1 * 0.7 + n2 * 0.5) * body_mask * 0.22;

    vec3 col = mix(vec3(0.06, 0.02, 0.14), core_color.rgb, body_mask);
    col += rim_color.rgb * (crest_rim * (0.55 + proximity * 0.45) + oil_sheen);

    float alpha = clamp(max(body_mask, mist_mask), 0.0, 1.0);
    COLOR = vec4(col, alpha);
}
