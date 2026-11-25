shader_type canvas_item;

uniform float proximity : hint_range(0.0, 1.1) = 0.16;
uniform float surge_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 core_color : source_color = vec4(0.014, 0.008, 0.032, 1.0);
uniform vec4 rim_color : source_color = vec4(0.60, 0.36, 0.96, 0.76);

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
        mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
        u.y
    );
}

float fbm3(vec2 p) {
    float v = 0.5 * noise(p);
    p = p * 2.03 + vec2(17.1, 9.2);
    v += 0.25 * noise(p);
    p = p * 2.03 + vec2(17.1, 9.2);
    v += 0.125 * noise(p);
    return v * 1.1428;
}

void fragment() {
    float max_reach = 0.34 + proximity * 0.36;
    if (UV.x > max_reach && proximity < 0.44) {
        discard;
    }

    float t = TIME;
    float body_mask = 0.0;
    float soft_mist = 0.0;
    vec3 col = vec3(0.015, 0.008, 0.040);

    if (UV.x <= max_reach) {
        float warp = fbm3(vec2(UV.y * 3.2 - t * 0.55, UV.x * 2.0 + t * 0.35));
        float n1 = fbm3(vec2(UV.y * 4.4 - t * 0.95 + warp * 0.9, UV.x * 2.2 - t * 0.65));
        float n2 = noise(vec2(UV.y * 8.2 + t * 1.35 - warp * 0.6, UV.x * 3.6 + t * 0.85));
        float bulge = sin(UV.y * 3.14159) * 0.065;
        float edge = 0.045 + proximity * 0.33 + bulge + (n1 - 0.5) * 0.11 + (n2 - 0.5) * 0.038;
        edge += surge_intensity * 0.028 * sin(UV.y * 14.0 + t * 10.0);

        float dist = UV.x - edge;
        body_mask = smoothstep(0.028, -0.026, dist);
        soft_mist = smoothstep(0.18, -0.02, dist) * (0.34 + proximity * 0.34) * (0.72 + 0.28 * n1);

        float crest_rim = smoothstep(0.042, 0.0, abs(dist)) * (0.48 + 0.52 * n2);
        float inner_swirl = smoothstep(0.48, 0.84, n1 * 0.65 + warp * 0.45) * body_mask * 0.24;

        vec3 mist_tint = mix(vec3(0.08, 0.03, 0.18), vec3(0.28, 0.14, 0.54), crest_rim);
        col = mix(mist_tint, core_color.rgb, body_mask);
        col += rim_color.rgb * (crest_rim * (0.42 + proximity * 0.38) + inner_swirl);
        col += vec3(0.22, 0.62, 0.92) * smoothstep(0.055, 0.01, abs(dist - 0.018)) * n2 * 0.16;
    }

    float vignette = 0.0;
    if (proximity > 0.44) {
        float danger = smoothstep(0.44, 0.96, proximity);
        float edge_dist = length((UV - vec2(0.5)) * vec2(1.15, 1.35));
        vignette = smoothstep(0.45, 0.96, edge_dist) * danger * (0.52 + 0.10 * sin(t * 6.5));
        col = mix(col, vec3(0.015, 0.008, 0.040), clamp(vignette * (1.0 - body_mask), 0.0, 0.82));
    }

    float alpha = clamp(max(max(body_mask, soft_mist), vignette), 0.0, 1.0);
    COLOR = vec4(col, alpha);
}
