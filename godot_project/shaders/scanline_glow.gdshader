shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.6, 0.4, 1.0, 0.5);
uniform float scan_speed : hint_range(0.1, 2.0) = 0.5;
uniform float scan_width : hint_range(0.0, 0.5) = 0.1;
uniform float angle : hint_range(-180.0, 180.0) = 45.0;

void fragment() {
    vec4 original_color = texture(TEXTURE, UV);
    
    // Convert angle to radians
    float rad_angle = radians(angle);
    
    // Create a rotated coordinate system
    vec2 rotated_uv = vec2(
        UV.x * cos(rad_angle) - UV.y * sin(rad_angle),
        UV.x * sin(rad_angle) + UV.y * cos(rad_angle)
    );
    
    // The scanline moves along the new 'x' axis of the rotated system
    float scan_pos = fract(TIME * scan_speed);
    
    // Calculate the intensity of the glow based on distance to the scanline
    float distance_to_scan = abs(rotated_uv.x - scan_pos);
    float glow = smoothstep(scan_width, 0.0, distance_to_scan);
    
    // Add the glow to the original color
    COLOR = original_color + glow * glow_color;
    COLOR.a = original_color.a; // Preserve original alpha
}
