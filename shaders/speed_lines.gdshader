shader_type canvas_item;

uniform float speed_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float chromatic_pulse : hint_range(0.0, 1.0) = 0.0;
uniform vec4 accent_color : source_color = vec4(0.31, 1.0, 0.69, 1.0);

float hash11(float p) {
    return fract(sin(p * 127.1) * 43758.5453123);
}

void fragment() {
    vec2 uv = UV;
    float alpha = 0.0;
    vec3 col = vec3(0.0);

    // High-flow horizontal speed streaks along outer screen perimeter
    if (speed_intensity > 0.01) {
        float lane = floor(uv.y * 28.0);
        float lane_rand = hash11(lane + 13.7);
        float scroll = fract(uv.x * 1.4 + TIME * (2.2 + lane_rand * 2.6) + lane_rand);
        float streak = smoothstep(0.0, 0.08, scroll) * smoothstep(0.34, 0.08, scroll);
        float band = smoothstep(0.45, 0.0, abs(fract(uv.y * 28.0) - 0.5) * 6.0);
        float edge_weight = smoothstep(0.22, 0.5, abs(uv.y - 0.5));
        float line_alpha = streak * band * edge_weight * speed_intensity * 0.32;
        col += accent_color.rgb * line_alpha * 1.4;
        alpha = max(alpha, line_alpha);
    }

    // Subtle chromatic rim pulse during 0.12s shapeshift transition
    if (chromatic_pulse > 0.01) {
        float border = smoothstep(0.38, 0.5, max(abs(uv.x - 0.5), abs(uv.y - 0.5)));
        vec3 chroma = vec3(
            border * chromatic_pulse * 0.45,
            border * chromatic_pulse * 0.72,
            border * chromatic_pulse * 0.85
        );
        col += chroma * 0.45;
        alpha = max(alpha, border * chromatic_pulse * 0.28);
    }

    COLOR = vec4(col, alpha);
}
