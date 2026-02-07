shader_type canvas_item;
render_mode blend_add;

// === 弹体外观 ===
// 注意：在 MultiMeshInstance2D 中，颜色通常由 INSTANCE_COLOR 传递
uniform float glow_intensity : hint_range(0.0, 10.0) = 3.0;
uniform float core_size : hint_range(0.0, 1.0) = 0.2;

// === 动画 ===
uniform float pulse_speed : hint_range(0.0, 20.0) = 6.0;

void fragment() {
    // 从中心到边缘的渐变
    float dist = length(UV - vec2(0.5)) * 2.0;

    // 核心亮点
    float core = smoothstep(core_size + 0.1, core_size, dist);

    // 外层辉光
    float glow = exp(-dist * 4.0);

    // 脉冲动画
    float pulse = sin(TIME * pulse_speed) * 0.15 + 0.85;

    // 使用实例颜色
    vec3 color = COLOR.rgb;
    
    vec3 final_color = color * core * 2.0 + color * glow * glow_intensity * pulse;

    COLOR = vec4(final_color, clamp(core + glow * 0.8, 0.0, 1.0));
}
