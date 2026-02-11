shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, cull_disabled;

// === 全局参数 ===
global uniform float global_time;
global uniform float beat_phase;
global uniform vec3 chapter_color;

void fragment() {
    // 从中心到边缘的渐变
    float dist = length(UV - vec2(0.5)) * 2.0;
    
    // 核心亮点
    float core = smoothstep(0.3, 0.1, dist);
    
    // 外层辉光
    float glow = exp(-dist * 4.0);
    
    // 使用实例颜色 (INSTANCE_COLOR)
    vec3 color = COLOR.rgb;
    
    // 结合章节色调
    color = mix(color, chapter_color, 0.1);
    
    // 最终颜色计算
    vec3 final_color = color * core * 2.0 + color * glow * 3.0 * (1.0 + beat_phase);
    
    ALBEDO = final_color;
    EMISSION = final_color * 2.0;
    ALPHA = clamp(core + glow, 0.0, 1.0) * COLOR.a;
}
