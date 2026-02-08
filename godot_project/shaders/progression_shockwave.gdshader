shader_type canvas_item;

// 和弦进行成功时的冲击波视觉效果
// 从屏幕中心向外扩散的圆形冲击波，颜色对应和弦功能
// Tonic (稳定蓝色), Dominant (紧张黄色), Pre-Dominant (过渡紫色)

uniform vec4 wave_color : source_color = vec4(0.3, 0.5, 1.0, 0.8);
uniform float wave_radius : hint_range(0.0, 2.0) = 0.0;
uniform float wave_width : hint_range(0.01, 0.2) = 0.05;
uniform float wave_intensity : hint_range(0.0, 2.0) = 1.0;
uniform vec2 center = vec2(0.5, 0.5);

void fragment() {
    vec4 original = texture(TEXTURE, UV);
    
    // Calculate distance from center
    vec2 aspect_corrected_uv = UV;
    aspect_corrected_uv.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
    vec2 aspect_corrected_center = center;
    aspect_corrected_center.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
    
    float dist = distance(aspect_corrected_uv, aspect_corrected_center);
    
    // Create the ring
    float ring = smoothstep(wave_radius - wave_width, wave_radius, dist) 
               - smoothstep(wave_radius, wave_radius + wave_width, dist);
    
    // Fade out as the ring expands
    float fade = max(0.0, 1.0 - wave_radius * 0.8);
    
    // Apply the wave color
    vec3 final_color = mix(original.rgb, wave_color.rgb, ring * wave_intensity * fade);
    
    // Also brighten the area inside the ring slightly
    float inner_glow = smoothstep(wave_radius, 0.0, dist) * 0.1 * fade;
    final_color += wave_color.rgb * inner_glow;
    
    COLOR = vec4(final_color, original.a);
}
