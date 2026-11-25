shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec4 glow_color : source_color = vec4(0.31, 1.0, 0.69, 1.0);
uniform float player_u : hint_range(-0.6, 1.6) = 0.5;
uniform float proximity_glow : hint_range(0.0, 1.0) = 0.0;
uniform float rain_intensity : hint_range(0.0, 1.0) = 0.78;

void fragment() {
    vec2 uv = UV;
    float t = TIME;

    // Concentric animated raindrop ripples across the shallow puddle surface
    float ripple_acc = 0.0;
    vec2 disp = vec2(0.0);
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float cycle = fract(t * (0.62 + fi * 0.16) + fi * 0.31);
        vec2 center = vec2(fract(fi * 0.27 + 0.14), 0.5);
        vec2 delta = (uv - center) * vec2(5.2, 1.0);
        float d = length(delta);
        float ring = exp(-pow((d - cycle * 1.45) * 18.0, 2.0)) * (1.0 - cycle);
        ripple_acc += ring;
        disp += normalize(delta + vec2(0.0001)) * ring * 0.0045;
    }

    // Real-time flipped scene reflection sampled from hint_screen_texture above the puddle
    vec2 refl_uv = vec2(
        clamp(SCREEN_UV.x + disp.x + sin(uv.x * 26.0 + t * 4.5) * 0.0018, 0.005, 0.995),
        clamp(SCREEN_UV.y - (0.025 + uv.y * 0.065) + disp.y, 0.005, 0.995)
    );
    vec3 scene_refl = texture(screen_texture, refl_uv).rgb;

    float edge_fade = smoothstep(0.0, 0.14, uv.x) * smoothstep(1.0, 0.86, uv.x);
    float vert_fade = smoothstep(0.0, 0.25, uv.y) * smoothstep(1.0, 0.20, uv.y);

    float wave = sin(uv.x * 38.0 + t * 5.2) * 0.5 + 0.5;
    float moon_shimmer = (0.14 + 0.22 * wave + ripple_acc * 0.52 * rain_intensity) * edge_fade;

    // Concentrated bioluminescent creature reflection directly beneath the player
    float p_dist = abs(uv.x - player_u);
    float creature_glow = exp(-p_dist * 5.2) * proximity_glow * (0.68 + 0.32 * wave);

    vec3 base_water = mix(vec3(0.08, 0.18, 0.28), scene_refl * 0.88 + vec3(0.06, 0.14, 0.22), 0.65);
    vec3 col = base_water + vec3(0.45, 0.72, 0.90) * moon_shimmer + glow_color.rgb * (creature_glow * 1.25 + ripple_acc * 0.26 * proximity_glow);
    float alpha = clamp((0.52 + moon_shimmer * 0.34 + creature_glow * 0.52) * edge_fade * vert_fade, 0.0, 0.94);
    COLOR = vec4(col, alpha);
}
