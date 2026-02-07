shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_back, unshaded;

// === 弹体外观 ===
uniform vec3 core_color : source_color = vec3(0.0, 1.0, 0.8);
uniform vec3 glow_color : source_color = vec3(0.0, 0.6, 1.0);
uniform float glow_intensity : hint_range(0.0, 10.0) = 3.0;
uniform float core_size : hint_range(0.0, 1.0) = 0.3;

// === 动画 ===
uniform float pulse_speed : hint_range(0.0, 20.0) = 6.0;
uniform float trail_intensity : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    // 从中心到边缘的渐变
    float dist = length(UV - vec2(0.5)) * 2.0;

    // 核心亮点
    float core = smoothstep(core_size + 0.1, core_size, dist);

    // 外层辉光
    float glow = exp(-dist * 3.0);

    // 脉冲动画
    float pulse = sin(TIME * pulse_speed) * 0.15 + 0.85;

    // 菲涅尔边缘
    float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);

    vec3 final_emission = core_color * core * 2.0 + glow_color * glow * glow_intensity * pulse + glow_color * fresnel * 1.5;

    ALBEDO = vec3(0.0);
    EMISSION = final_emission;
    ALPHA = clamp(core + glow * 0.8 + fresnel * 0.5, 0.0, 1.0);
}
