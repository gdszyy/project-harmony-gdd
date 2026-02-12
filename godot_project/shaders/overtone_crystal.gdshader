shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float rainbow_speed : hint_range(0.1, 5.0) = 1.0;
uniform float rainbow_intensity : hint_range(0.0, 1.0) = 0.8;
uniform float time_offset = 0.0;

void fragment() {
    float hue = fract(UV.x + UV.y + time_offset * rainbow_speed);
    vec3 rainbow = vec3(
        0.5 + 0.5 * cos(hue * 6.28318 + 0.0),
        0.5 + 0.5 * cos(hue * 6.28318 + 2.09439),
        0.5 + 0.5 * cos(hue * 6.28318 + 4.18879)
    );
    COLOR = vec4(mix(base_color.rgb, rainbow, rainbow_intensity), base_color.a);
}
