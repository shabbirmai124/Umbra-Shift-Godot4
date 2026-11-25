shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float speed_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float chromatic_pulse : hint_range(0.0, 1.0) = 0.0;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.18;
uniform float shockwave_radius : hint_range(0.0, 1.5) = 0.0;
uniform float shockwave_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec2 shockwave_center = vec2(0.36, 0.62);
uniform vec4 accent_color : source_color = vec4(0.31, 1.0, 0.69, 1.0);

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 centered = UV - vec2(0.5);
    float dist_center = length(centered);
    float angle = atan(centered.y, centered.x);

    // Expanding screen-space shockwave ripple distortion on heavy impacts & morphs
    vec2 aspect = vec2(1.777, 1.0);
    vec2 sw_vec = (uv - shockwave_center) * aspect;
    float sw_dist = length(sw_vec);
    float sw_band = exp(-pow((sw_dist - shockwave_radius) * 26.0, 2.0)) * shockwave_strength;
    vec2 sw_offset = normalize(sw_vec + vec2(0.0001)) * sw_band * 0.016;
    vec2 sample_uv = clamp(uv - sw_offset, vec2(0.002), vec2(0.998));

    // Micro chromatic aberration pulse during shapeshifts and Pangolin smashes
    float ca_amt = (chromatic_pulse * 0.0055 + sw_band * 0.004) * smoothstep(0.10, 0.68, dist_center);
    vec2 ca_dir = normalize(centered + vec2(0.0001)) * ca_amt;
    float r = texture(screen_texture, clamp(sample_uv + ca_dir, vec2(0.001), vec2(0.999))).r;
    float g = texture(screen_texture, sample_uv).g;
    float b = texture(screen_texture, clamp(sample_uv - ca_dir, vec2(0.001), vec2(0.999))).b;
    vec3 col = vec3(r, g, b);

    // Subtle luminous shockwave rim highlight
    col += accent_color.rgb * sw_band * 0.24;

    // High-velocity radial peripheral speed-lines fading in smoothly at Flow x5+
    float ray_id = floor(angle * 30.0);
    float streak_h = hash(vec2(ray_id, floor(TIME * 14.0)));
    float streak_mask = smoothstep(0.68, 0.96, streak_h) * smoothstep(0.32, 0.66, dist_center);
    col += mix(vec3(0.84, 0.94, 1.0), accent_color.rgb, 0.55) * streak_mask * speed_intensity * 0.28;

    // Dynamic radial vignette darkening as Shadow Ink Tide closes in
    float vig = smoothstep(0.38, 0.86, length(centered * vec2(1.12, 1.28)));
    col *= 1.0 - vig * clamp(vignette_strength, 0.0, 0.72);

    // Subtle animated film grain (0.025 opacity) eliminating dark gradient banding
    float grain = (hash(uv * vec2(1920.0, 1080.0) + fract(TIME * 43.0) * 100.0) - 0.5) * 0.025;
    col += vec3(grain);

    COLOR = vec4(col, 1.0);
}
