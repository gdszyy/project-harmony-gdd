shader_type canvas_item;

// 调式切换时的屏幕边缘风格化边框
// 每种调式有不同的颜色和纹理风格

uniform vec4 border_color : source_color = vec4(0.6, 0.4, 1.0, 0.5);
uniform float border_width : hint_range(0.0, 0.15) = 0.04;
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.0;
uniform float pulse_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.5;

// Mode-specific pattern type:
// 0 = Ionian (clean, geometric)
// 1 = Dorian (flowing, wave-like)
// 2 = Pentatonic (ink wash / bamboo)
// 3 = Blues (neon glow)
uniform int pattern_type : hint_range(0, 3) = 0;

void fragment() {
    vec4 original = texture(TEXTURE, UV);
    
    // Calculate distance from edges
    float edge_x = min(UV.x, 1.0 - UV.x);
    float edge_y = min(UV.y, 1.0 - UV.y);
    float edge_dist = min(edge_x, edge_y);
    
    // Pulsing animation
    float pulse = sin(TIME * pulse_speed) * pulse_intensity + (1.0 - pulse_intensity);
    
    // Border mask
    float border_mask = smoothstep(border_width, 0.0, edge_dist);
    
    // Pattern modulation based on mode type
    float pattern = 1.0;
    if (pattern_type == 1) {
        // Dorian: flowing wave pattern
        pattern = sin(UV.x * 20.0 + TIME * 2.0) * 0.3 + 0.7;
        pattern *= sin(UV.y * 15.0 - TIME * 1.5) * 0.2 + 0.8;
    } else if (pattern_type == 2) {
        // Pentatonic: ink wash / soft gradient
        float ink = fract(sin(dot(UV * 10.0, vec2(12.9898, 78.233))) * 43758.5453);
        pattern = mix(0.6, 1.0, ink);
    } else if (pattern_type == 3) {
        // Blues: neon flicker
        float flicker = sin(TIME * 8.0 + UV.x * 30.0) * 0.15 + 0.85;
        pattern = flicker;
    }
    // pattern_type == 0 (Ionian): clean, no modulation
    
    // Apply border
    vec3 final_color = mix(original.rgb, border_color.rgb * pulse * pattern, border_mask * border_color.a);
    
    // Vignette effect (subtle darkening at edges)
    float vignette = 1.0 - edge_dist * 2.0;
    vignette = clamp(vignette, 0.0, 1.0);
    final_color = mix(final_color, final_color * 0.7, vignette * vignette_strength * (1.0 - border_mask));
    
    COLOR = vec4(final_color, original.a);
}
