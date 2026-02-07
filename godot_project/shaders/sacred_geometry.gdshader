shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// === 基础外观 ===
uniform vec3 albedo : source_color = vec3(0.02, 0.02, 0.05);
uniform vec3 emission_color : source_color = vec3(0.0, 1.0, 0.8);
uniform float emission_energy : hint_range(0.0, 16.0) = 5.0;
uniform float fresnel_power : hint_range(0.1, 10.0) = 2.0;

// === 故障效果 (受疲劳度或受击控制) ===
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float time_speed = 10.0;

// === 脉冲效果 (随节拍) ===
uniform float pulse_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_speed : hint_range(0.0, 20.0) = 8.0;

// === 音符颜色映射 ===
// 通过脚本动态设置，实现不同音符不同颜色
uniform float note_hue : hint_range(0.0, 1.0) = 0.5;

vec3 hsv_to_rgb(float h, float s, float v) {
    vec3 c = vec3(h, s, v);
    vec3 rgb = clamp(abs(mod(c.x * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
    return c.z * mix(vec3(1.0), rgb, c.y);
}

void fragment() {
    ALBEDO = albedo;

    // 计算菲涅尔效应 (边缘发光)
    float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);

    // 故障抖动
    float noise = sin(UV.y * 50.0 + TIME * time_speed) * glitch_intensity;
    float glitch_block = step(0.8, fract(sin(floor(UV.y * 20.0) + TIME * 5.0) * 43758.5453));
    noise += glitch_block * glitch_intensity * 0.3;
    fresnel += noise;

    // 脉冲效果 (随节拍闪烁)
    float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
    float pulse_factor = 1.0 + pulse * pulse_intensity * 0.5;

    // 根据 note_hue 生成颜色
    vec3 dynamic_color = mix(emission_color, hsv_to_rgb(note_hue, 0.9, 1.0), step(0.01, note_hue));

    // 应用发光
    EMISSION = dynamic_color * fresnel * emission_energy * pulse_factor;

    // 全息投影质感
    ROUGHNESS = 0.1;
    METALLIC = 0.8;
}
