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

void fragment() {
    vec2 uv = UV;
    // Deep indigo-to-slate stormy twilight sky gradient
    vec3 sky_top = vec3(0.016, 0.027, 0.071);
    vec3 sky_mid = vec3(0.043, 0.078, 0.157);
    vec3 sky_low = vec3(0.086, 0.155, 0.245);
    vec3 col = mix(sky_top, sky_mid, smoothstep(0.0, 0.55, uv.y));
    col = mix(col, sky_low, smoothstep(0.5, 1.0, uv.y));

    // Distant sheet lightning glow
    float light_dist = length((uv - vec2(0.72, 0.22)) * vec2(1.6, 1.0));
    col += vec3(0.55, 0.78, 1.0) * lightning_flash * exp(-light_dist * 2.2) * 0.45;

    // Glowing crescent moon + volumetric halo
    vec2 aspect = vec2(1.777, 1.0);
    float d_moon = length((uv - moon_uv) * aspect);
    float halo = exp(-d_moon * 5.5) * 0.34 + exp(-d_moon * 16.0) * 0.3;
    col += vec3(0.75, 0.89, 1.0) * halo;

    float moon_disk = smoothstep(0.046, 0.042, d_moon);
    float shadow_cut = smoothstep(0.041, 0.037, length((uv - (moon_uv + vec2(0.011, -0.010))) * aspect));
    float crescent = clamp(moon_disk - shadow_cut, 0.0, 1.0);
    col = mix(col, vec3(0.92, 0.96, 1.0), crescent);

    // Drifting volumetric storm clouds
    vec2 cloud_uv = vec2(uv.x * 3.8 + scroll_x * 0.00004 + TIME * 0.015, uv.y * 5.2);
    float c1 = fbm(cloud_uv);
    float c2 = fbm(cloud_uv * 1.9 + vec2(TIME * 0.025, 2.1));
    float cloud_band = smoothstep(0.02, 0.24, uv.y) * smoothstep(0.66, 0.28, uv.y);
    float cloud = smoothstep(0.42, 0.78, c1 * 0.65 + c2 * 0.35) * cloud_band;
    vec3 cloud_col = mix(vec3(0.06, 0.11, 0.19), vec3(0.24, 0.36, 0.50), clamp(halo * 2.2 + lightning_flash * 0.65, 0.0, 1.0));
    col = mix(col, cloud_col, cloud * 0.62);

    COLOR = vec4(col, 1.0);
}
