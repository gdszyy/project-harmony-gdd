shader_type canvas_item;

// ============================================================
// 节拍指示器着色器
// 静态外环 + 动态内缩环 + 冲击波反馈
// ============================================================

uniform float beat_progress : hint_range(0.0, 1.0) = 0.0;
uniform float flash_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec3 flash_color : source_color = vec3(1.0, 0.843, 0.0);
uniform float time_sec : hint_range(0.0, 9999.0) = 0.0;
uniform int current_beat : hint_range(0, 15) = 0;
uniform int beats_per_measure : hint_range(1, 16) = 4;

const vec3 COLOR_CRYSTAL_WHITE = vec3(0.918, 0.902, 1.0);
const vec3 COLOR_RESONANCE_CYAN = vec3(0.0, 1.0, 0.831);

void fragment() {
    vec2 uv = UV;
    vec2 center = vec2(0.5);
    vec2 delta = uv - center;
    float dist = length(delta);
    float angle = atan(delta.y, delta.x);

    // 环形参数
    float outer_radius = 0.45;
    float ring_width = 0.02;
    float inner_ring_radius = outer_radius * (1.0 - beat_progress);

    // === 1. 静态外环 ===
    float outer_ring = smoothstep(ring_width, ring_width * 0.3, abs(dist - outer_radius));

    // 外环刻度 (每拍一个刻度)
    float tick_count = float(beats_per_measure * 4); // 16 拍
    float tick_angle = mod(angle + PI, TAU) / TAU * tick_count;
    float tick_fract = fract(tick_angle);
    float tick_mask = smoothstep(0.08, 0.02, abs(tick_fract - 0.5));

    // 重拍刻度更亮更长
    int tick_index = int(floor(tick_angle));
    float is_downbeat = step(0.5, 1.0 - float(tick_index % beats_per_measure));
    float tick_length = mix(0.02, 0.04, is_downbeat);
    float tick_radial = smoothstep(0.0, tick_length, abs(dist - outer_radius));
    tick_radial = 1.0 - tick_radial;
    float ticks = tick_mask * tick_radial;

    vec3 outer_color = COLOR_CRYSTAL_WHITE * (outer_ring * 0.5 + ticks * mix(0.4, 0.8, is_downbeat));

    // === 2. 动态内缩环 ===
    float inner_ring = smoothstep(ring_width * 1.5, ring_width * 0.3, abs(dist - inner_ring_radius));
    // 内缩环辉光
    float inner_glow = smoothstep(0.06, 0.0, abs(dist - inner_ring_radius)) * 0.3;

    vec3 inner_color = COLOR_RESONANCE_CYAN * (inner_ring + inner_glow);

    // === 3. 完美节拍冲击波 ===
    float shockwave = 0.0;
    if (flash_intensity > 0.01) {
        float shock_radius = outer_radius + (1.0 - flash_intensity) * 0.15;
        float shock_width = 0.015 * flash_intensity;
        shockwave = smoothstep(shock_width, 0.0, abs(dist - shock_radius)) * flash_intensity;
    }

    vec3 shock_color = flash_color * shockwave;

    // === 4. 中心脉冲 (节拍到达时) ===
    float center_pulse = 0.0;
    if (beat_progress < 0.1) {
        center_pulse = smoothstep(0.08, 0.0, dist) * (1.0 - beat_progress / 0.1) * 0.3;
    }

    // === 合成 ===
    vec3 final_color = outer_color + inner_color + shock_color;
    final_color += COLOR_RESONANCE_CYAN * center_pulse;

    float final_alpha = max(outer_ring * 0.5 + ticks, inner_ring + inner_glow);
    final_alpha = max(final_alpha, shockwave);
    final_alpha = max(final_alpha, center_pulse);

    COLOR = vec4(final_color, final_alpha);
}
