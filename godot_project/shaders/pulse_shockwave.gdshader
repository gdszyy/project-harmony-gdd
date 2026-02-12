shader_type canvas_item;

// Pulse 低通变体 (Sub-Bass) 的全屏冲击波后处理 Shader

uniform float progress : hint_range(0.0, 1.0); // 冲击波扩散进度
uniform float pixel_size : hint_range(1.0, 64.0) = 8.0; // 像素化尺寸
uniform vec2 center = vec2(0.5); // 冲击波中心
uniform vec4 shockwave_color : source_color = vec4(0.2, 0.6, 1.0, 0.8); // 冲击波颜色

void fragment() {
    // 像素化处理
    vec2 pix_uv = floor(UV * (1.0 / pixel_size) * SCREEN_PIXEL_SIZE.y / 10.0) / (SCREEN_PIXEL_SIZE.y / 10.0) * pixel_size;
    vec4 original_color = texture(SCREEN_TEXTURE, pix_uv);

    // 计算与中心的距离
    float dist = distance(UV, center);

    // 冲击波是一个环，有宽度
    float ring_width = 0.05 + (1.0 - progress) * 0.1;
    float ring = smoothstep(progress - ring_width, progress, dist) - smoothstep(progress, progress + ring_width, dist);

    // 冲击波强度随进度减弱
    float strength = ring * (1.0 - progress) * 1.5;

    // 混合颜色
    vec3 final_color = mix(original_color.rgb, shockwave_color.rgb, strength * shockwave_color.a);

    COLOR = vec4(final_color, original_color.a);
}
