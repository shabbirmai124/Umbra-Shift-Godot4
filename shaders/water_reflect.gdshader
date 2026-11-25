shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.31, 1.0, 0.69, 1.0);
uniform float player_u : hint_range(-1.0, 2.0) = 0.5;
uniform float proximity_glow : hint_range(0.0, 1.0) = 0.6;
uniform float rain_intensity : hint_range(0.0, 1.0) = 0.7;

void fragment() {
    float ripple = sin(UV.x * 42.0 + TIME * 7.5) * 0.5 + 0.5;
    float ripple2 = sin(UV.x * 78.0 - TIME * 11.0 + UV.y * 12.0) * 0.5 + 0.5;
    float edge_fade = sin(UV.x * 3.14159) * sin(UV.y * 3.14159);

    float dist_to_player = abs(UV.x - player_u);
    float refl = exp(-dist_to_player * 6.5) * proximity_glow * (0.7 + 0.3 * ripple);

    vec3 moon_water = vec3(0.36, 0.58, 0.78) * (0.3 + 0.25 * ripple2 * rain_intensity);
    vec3 final_col = moon_water + glow_color.rgb * refl * 1.35;
    float alpha = edge_fade * clamp(0.35 + refl * 0.65, 0.0, 0.92);
    COLOR = vec4(final_col, alpha);
}
