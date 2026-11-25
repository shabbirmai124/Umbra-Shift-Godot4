shader_type canvas_item;

uniform float scroll_x = 0.0;
uniform float lightning_flash : hint_range(0.0, 1.0) = 0.0;
uniform vec2 moon_uv = vec2(0.76, 0.19);

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

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p = p * 2.02 + vec2(11.3, 6.7);
        a *= 0.5;
    }
    return v;
}

float star_layer(vec2 uv, float scale, float density, float t) {
    vec2 g = uv * scale;
    vec2 id = floor(g);
    vec2 f = fract(g) - 0.5;
    float r = hash(id);
    if (r < density) {
        return 0.0;
    }
    vec2 offset = vec2(hash(id + 13.7), hash(id + 47.3)) - 0.5;
    float d = length(f - offset * 0.65);
    float twinkle = 0.55 + 0.45 * sin(t * (1.8 + r * 3.5) + r * 62.8);
    float core = smoothstep(0.11, 0.0, d) * twinkle;
    return core;
}

void fragment() {
    vec2 uv = UV;
    float t = TIME;

    // Dreamy twilight sky gradient: deep cosmic indigo -> violet-blue -> misty jade-teal horizon
    vec3 sky_top = vec3(0.022, 0.032, 0.095);
    vec3 sky_mid = vec3(0.058, 0.096, 0.215);
    vec3 sky_horizon = vec3(0.105, 0.225, 0.320);
    vec3 sky_low = vec3(0.055, 0.145, 0.225);

    vec3 col = mix(sky_top, sky_mid, smoothstep(0.0, 0.48, uv.y));
    col = mix(col, sky_horizon, smoothstep(0.38, 0.78, uv.y));
    col = mix(col, sky_low, smoothstep(0.76, 1.0, uv.y));

    // Soft lavender-rose dusk haze hugging the distant horizon
    float dusk_band = exp(-pow((uv.y - 0.56) * 5.2, 2.0));
    col += vec3(0.14, 0.09, 0.22) * dusk_band * 0.42;

    // Multi-layer twinkling starfield in the upper twilight vault
    float sky_mask = smoothstep(0.62, 0.08, uv.y);
    vec2 star_uv = vec2(uv.x + scroll_x * 0.000008, uv.y);
    float s1 = star_layer(star_uv, 68.0, 0.91, t);
    float s2 = star_layer(star_uv + vec2(0.37, 0.19), 118.0, 0.94, t * 1.25);
    vec3 star_tint = mix(vec3(0.78, 0.90, 1.0), vec3(0.84, 1.0, 0.92), hash(floor(star_uv * 68.0)));
    col += star_tint * (s1 * 0.85 + s2 * 0.55) * sky_mask;

    // Periodic aesthetic shooting star gliding softly across the upper right sky
    float cycle = mod(t * 0.22, 1.0);
    if (cycle < 0.22) {
        float prog = cycle / 0.22;
        vec2 head = vec2(0.86 - prog * 0.34, 0.08 + prog * 0.15);
        vec2 dir = normalize(vec2(-0.34, 0.15));
        vec2 rel = uv - head;
        float along = dot(rel, -dir);
        float perp = abs(dot(rel, vec2(-dir.y, dir.x)));
        float streak = smoothstep(0.0045, 0.0, perp) * smoothstep(0.095, 0.0, along) * step(0.0, along);
        float fade = sin(prog * 3.14159);
        col += vec3(0.82, 0.98, 1.0) * streak * fade * 0.95;
    }

    // Flowing ethereal Aurora Borealis ribbons (mint-emerald -> cyan -> soft lavender)
    float a_x = uv.x * 2.4 + scroll_x * 0.00002;
    float wave1 = 0.23 + sin(a_x * 2.2 + t * 0.28) * 0.055 + cos(a_x * 3.8 - t * 0.22) * 0.025;
    float wave2 = 0.31 + cos(a_x * 1.8 - t * 0.24 + 1.4) * 0.048 + sin(a_x * 4.2 + t * 0.31) * 0.02;
    float curtain1 = exp(-pow((uv.y - wave1) * 11.0, 2.0)) * (0.45 + 0.55 * fbm(vec2(a_x * 3.6 + t * 0.09, uv.y * 2.0)));
    float curtain2 = exp(-pow((uv.y - wave2) * 13.0, 2.0)) * (0.45 + 0.55 * fbm(vec2(a_x * 4.4 - t * 0.11, uv.y * 2.6 + 3.1)));
    float aurora_rays = 0.65 + 0.35 * sin(uv.x * 46.0 + fbm(vec2(a_x * 3.0, t * 0.15)) * 6.0);
    vec3 aurora_col1 = mix(vec3(0.18, 0.92, 0.72), vec3(0.22, 0.78, 1.0), smoothstep(0.15, 0.85, uv.x));
    vec3 aurora_col2 = mix(vec3(0.42, 0.34, 0.96), vec3(0.18, 0.88, 0.82), smoothstep(0.1, 0.9, uv.x));
    col += aurora_col1 * curtain1 * aurora_rays * 0.24 * smoothstep(0.55, 0.12, uv.y);
    col += aurora_col2 * curtain2 * aurora_rays * 0.18 * smoothstep(0.58, 0.16, uv.y);

    // Subtle distant storm sheet-lightning shimmer
    float light_dist = length((uv - vec2(0.72, 0.22)) * vec2(1.5, 1.0));
    col += vec3(0.56, 0.80, 1.0) * lightning_flash * exp(-light_dist * 2.1) * 0.36;

    // Warm pearlescent crescent moon + layered atmospheric bloom corona
    vec2 aspect = vec2(1.777, 1.0);
    float d_moon = length((uv - moon_uv) * aspect);
    float halo = exp(-d_moon * 4.2) * 0.30 + exp(-d_moon * 12.0) * 0.34 + exp(-d_moon * 28.0) * 0.24;
    col += mix(vec3(0.58, 0.82, 1.0), vec3(0.95, 0.96, 1.0), clamp(halo * 1.4, 0.0, 1.0)) * halo;

    float moon_disk = smoothstep(0.048, 0.043, d_moon);
    float shadow_cut = smoothstep(0.042, 0.037, length((uv - (moon_uv + vec2(0.012, -0.010))) * aspect));
    float crescent = clamp(moon_disk - shadow_cut, 0.0, 1.0);
    float moon_tex = 0.92 + 0.08 * fbm(uv * 48.0);
    col = mix(col, vec3(0.96, 0.97, 0.94) * moon_tex, crescent);

    // Multi-layer silky drifting moonlit clouds
    vec2 cloud_uv1 = vec2(uv.x * 3.2 + scroll_x * 0.000035 + t * 0.012, uv.y * 4.6);
    vec2 cloud_uv2 = vec2(uv.x * 5.4 + scroll_x * 0.000055 + t * 0.022, uv.y * 6.4 + 2.3);
    float c1 = fbm(cloud_uv1);
    float c2 = fbm(cloud_uv2);
    float cloud_band = smoothstep(0.04, 0.26, uv.y) * smoothstep(0.72, 0.30, uv.y);
    float cloud = smoothstep(0.40, 0.78, c1 * 0.62 + c2 * 0.38) * cloud_band;
    float moon_lit = clamp(exp(-d_moon * 3.2) * 1.15 + lightning_flash * 0.55, 0.0, 1.0);
    vec3 cloud_shadow = vec3(0.055, 0.095, 0.185);
    vec3 cloud_rim = vec3(0.34, 0.52, 0.68);
    vec3 cloud_col = mix(cloud_shadow, cloud_rim, moon_lit);
    col = mix(col, cloud_col, cloud * 0.56);

    COLOR = vec4(col, 1.0);
}
