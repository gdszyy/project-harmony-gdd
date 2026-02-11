shader_type canvas_item;
render_mode blend_add;

// === 全局参数 ===
global uniform float global_time;
global uniform float beat_phase;
global uniform vec3 chapter_color;

// === 弹体外观 ===
// 注意：在 MultiMeshInstance2D 中，颜色通常由 INSTANCE_COLOR 传递
uniform float glow_intensity : hint_range(0.0, 10.0) = 3.0;
uniform float core_size : hint_range(0.0, 1.0) = 0.2;

// === 动画 ===
uniform float pulse_speed : hint_range(0.0, 20.0) = 6.0;

// === 音色系别参数 ===
// 0=无, 1=弦乐(拉弦), 2=管乐(吹奏), 3=打击, 4=键盘
uniform int timbre_family = 0;

// === 音色视觉修饰 ===
uniform float timbre_wave_freq : hint_range(0.0, 10.0) = 0.0;   // 弦乐：波纹频率
uniform float timbre_pulse_rate : hint_range(0.0, 5.0) = 0.0;   // 管乐：脉冲速率
uniform float timbre_sharp_factor : hint_range(0.0, 1.0) = 0.0;  // 打击：锐利度
uniform float timbre_key_segments : hint_range(0.0, 8.0) = 0.0;  // 键盘：分段数

void fragment() {
    // 从中心到边缘的渐变
    vec2 centered_uv = UV - vec2(0.5);
    float dist = length(centered_uv) * 2.0;
    float angle = atan(centered_uv.y, centered_uv.x);

    // 核心亮点
    float core = smoothstep(core_size + 0.1, core_size, dist);

    // 外层辉光
    float glow = exp(-dist * 4.0);

    // 脉冲动画
    float pulse = sin(global_time * pulse_speed) * 0.15 + 0.85;

    // === 音色视觉修饰 ===
    float timbre_mod = 1.0;

    if (timbre_family == 1) {
        // 弦乐系：弹体边缘添加正弦波纹（振动弦的视觉隐喻）
        float wave = sin(angle * 6.0 + global_time * timbre_wave_freq * 6.28) * 0.05;
        float wave_dist = dist + wave;
        glow = exp(-wave_dist * 4.0);
        // 边缘波纹发光
        timbre_mod = 1.0 + abs(wave) * 5.0;
    }
    else if (timbre_family == 2) {
        // 管乐系：弹体亮度随时间脉冲（气流的视觉隐喻）
        float breath_pulse = sin(global_time * timbre_pulse_rate * 6.28) * 0.3 + 0.7;
        timbre_mod = breath_pulse;
        // 添加径向扩散效果
        glow *= 1.0 + sin(dist * 10.0 - global_time * 3.0) * 0.1;
    }
    else if (timbre_family == 3) {
        // 打击系：弹体边缘更锐利（冲击波的视觉隐喻）
        float sharp_core = smoothstep(core_size + 0.02, core_size, dist);
        core = mix(core, sharp_core, timbre_sharp_factor);
        // 硬边缘光环
        float ring = smoothstep(0.05, 0.0, abs(dist - 0.6)) * timbre_sharp_factor;
        glow += ring * 2.0;
    }
    else if (timbre_family == 4) {
        // 键盘系：弹体呈现分段棱角（琴键的视觉隐喻）
        if (timbre_key_segments > 0.0) {
            float seg_angle = floor(angle / 6.28 * timbre_key_segments) / timbre_key_segments * 6.28;
            float seg_dist = length(vec2(cos(seg_angle), sin(seg_angle)) * dist * 0.5);
            float faceted = mix(dist, seg_dist, 0.3);
            glow = exp(-faceted * 4.0);
            // 分段边缘高光
            float edge = smoothstep(0.02, 0.0, abs(fract(angle / 6.28 * timbre_key_segments) - 0.5) - 0.45);
            glow += edge * 0.3;
        }
    }

    // === 节拍同步 ===
    float beat_glow = exp(-beat_phase * 4.0) * 0.3;
    timbre_mod += beat_glow;

    // 使用实例颜色
    vec3 color = COLOR.rgb;

    // 添加微弱的章节色调
    color = mix(color, chapter_color, 0.05);

    vec3 final_color = color * core * 2.0 + color * glow * glow_intensity * pulse * timbre_mod;

    COLOR = vec4(final_color, clamp(core + glow * 0.8, 0.0, 1.0));
}
