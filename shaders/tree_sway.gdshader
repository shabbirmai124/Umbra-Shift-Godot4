shader_type canvas_item;

uniform float wind_strength : hint_range(0.0, 28.0) = 9.0;
uniform float wind_speed : hint_range(0.1, 6.0) = 1.45;
uniform float sway_height : hint_range(10.0, 800.0) = 320.0;
uniform float phase_offset = 0.0;

void vertex() {
    float height_factor = clamp(-VERTEX.y / sway_height, 0.0, 1.0);
    float gust = sin(TIME * wind_speed + phase_offset + VERTEX.x * 0.008)
               + 0.35 * sin(TIME * wind_speed * 2.3 + VERTEX.x * 0.02);
    VERTEX.x += gust * wind_strength * height_factor * height_factor;
}
