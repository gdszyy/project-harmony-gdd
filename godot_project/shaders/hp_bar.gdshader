shader_type canvas_item;

// ============================================================
// 谐振完整度 (血条) 着色器
// 正弦波形态弧形血条，从和谐到噪音的平滑视觉过渡
// ============================================================

uniform float hp_ratio : hint_range(0.0, 1.0) = 1.0;
uniform float beat_progress : hint_range(0.0, 1.0) = 0.0;
uniform float beat_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;
uniform float time_sec : hint_range(0.0, 9999.0) = 0.0;

// 颜色常量
const vec3 COLOR_RESONANCE_CYAN = vec3(0.0, 1.0, 0.831);   // #00FFD4
const vec3 COLOR_DATA_ORANGE    = vec3(1.0, 0.533, 0.0);    // #FF8800
const vec3 COLOR_ERROR_RED      = vec3(1.0, 0.133, 0.267);  // #FF2244
const vec3 COLOR_GLITCH_MAGENTA = vec3(1.0, 0.0, 0.667);    // #FF00AA
const vec3 COLOR_CORRUPT_PURPLE = vec3(0.533, 0.0, 1.0);    // #8800FF

// 噪声函数
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
        mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
        f.y
    );
}

// 波形生成函数
float sine_wave(float t) {
    return sin(t);
}

float triangle_wave(float t) {
    return abs(mod(t / PI, 2.0) - 1.0) * 2.0 - 1.0;
}

float sawtooth_wave(float t) {
    return mod(t / PI, 2.0) - 1.0;
}

float square_wave(float t) {
    return sign(sin(t));
}

// 根据 HP 比例混合波形
float get_waveform(float t, float hp) {
    float sine = sine_wave(t);
    float tri = triangle_wave(t);
    float saw = sawtooth_wave(t);
    float sq = square_wave(t);

    if (hp > 0.75) {
        // 100%-75%: 纯正弦波
        return sine;
    } else if (hp > 0.50) {
        // 75%-50%: 正弦 -> 三角波混合
        float blend = (0.75 - hp) / 0.25;
        return mix(sine, tri, blend);
    } else if (hp > 0.25) {
        // 50%-25%: 三角 -> 锯齿波混合
        float blend = (0.50 - hp) / 0.25;
        return mix(tri, saw, blend);
    } else {
        // <25%: 锯齿 -> 故障方波
        float blend = (0.25 - hp) / 0.25;
        float glitch_sq = sq + noise(vec2(t * 0.5, time_sec * 10.0)) * 0.4 * blend;
        return mix(saw, glitch_sq, blend);
    }
}

// 获取 HP 对应颜色
vec3 get_hp_color(float hp) {
    if (hp > 0.75) {
        return COLOR_RESONANCE_CYAN;
    } else if (hp > 0.50) {
        float blend = (0.75 - hp) / 0.25;
        return mix(COLOR_RESONANCE_CYAN, COLOR_DATA_ORANGE, blend);
    } else if (hp > 0.25) {
        float blend = (0.50 - hp) / 0.25;
        return mix(COLOR_DATA_ORANGE, COLOR_ERROR_RED, blend);
    } else {
        float blend = (0.25 - hp) / 0.25;
        float flicker = sin(time_sec * 15.0) * 0.5 + 0.5;
        return mix(COLOR_ERROR_RED, COLOR_GLITCH_MAGENTA, blend * flicker);
    }
}

void fragment() {
    vec2 uv = UV;

    // 弧形变换：将 UV 映射到弧形空间
    float arc_x = uv.x;
    float arc_center_y = 0.5;

    // 弧形弯曲 — 中心高、两端低
    float arc_bend = sin(arc_x * PI) * 0.15;
    float adjusted_y = uv.y - arc_bend;

    // 波形参数
    float frequency = mix(3.0, 12.0, 1.0 - hp_ratio);
    float amplitude = mix(0.12, 0.04, 1.0 - hp_ratio);

    // 节拍呼吸效果 — 重拍时振幅增大 10-15%
    float breath = beat_intensity * 0.15;
    amplitude *= (1.0 + breath);

    // 低血量抖动
    float jitter = 0.0;
    if (hp_ratio < 0.25) {
        jitter = noise(vec2(arc_x * 50.0, time_sec * 20.0)) * 0.03 * (0.25 - hp_ratio) / 0.25;
    }

    // 波形 Y 值
    float wave_t = arc_x * frequency * TAU + time_sec * 3.0;
    float wave_y = get_waveform(wave_t, hp_ratio) * amplitude + jitter;

    // 波形线中心 Y
    float wave_center = arc_center_y + wave_y;

    // 计算像素到波形线的距离
    float dist_to_wave = abs(adjusted_y - wave_center);

    // 波形线宽度
    float line_width = mix(0.008, 0.015, 1.0 - hp_ratio);
    float line = smoothstep(line_width, line_width * 0.3, dist_to_wave);

    // 填充区域（波形线以下到底部）
    float fill_mask = step(wave_center, adjusted_y) * step(uv.x, hp_ratio);
    float fill_alpha = fill_mask * 0.15;

    // 颜色
    vec3 hp_color = get_hp_color(hp_ratio);

    // 辉光效果
    float glow_radius = mix(0.06, 0.02, 1.0 - hp_ratio);
    float glow = smoothstep(glow_radius, 0.0, dist_to_wave) * 0.4;
    glow *= step(uv.x, hp_ratio + 0.01);

    // 节拍脉动辉光
    glow *= (1.0 + beat_intensity * 0.5);

    // 受击故障效果
    vec3 flash_color = vec3(0.0);
    float flash_alpha = 0.0;
    if (hit_flash > 0.01) {
        // 色彩通道分离 (Chromatic Aberration)
        float ca_offset = hit_flash * 0.02;
        float ca_r = smoothstep(line_width, 0.0, abs(adjusted_y - wave_center + ca_offset));
        float ca_b = smoothstep(line_width, 0.0, abs(adjusted_y - wave_center - ca_offset));
        flash_color = vec3(ca_r, 0.0, ca_b) * COLOR_CORRUPT_PURPLE * hit_flash;
        flash_alpha = (ca_r + ca_b) * hit_flash * 0.5;

        // UV 扰动
        float glitch_offset = hash(vec2(floor(uv.y * 20.0), floor(time_sec * 30.0))) * hit_flash * 0.05;
        line *= (1.0 + glitch_offset * 5.0);
    }

    // 故障方波效果 (低血量)
    float glitch_effect = 0.0;
    if (hp_ratio < 0.25) {
        float glitch_strength = (0.25 - hp_ratio) / 0.25;
        float block_y = floor(uv.y * 15.0);
        float block_x = floor(uv.x * 30.0);
        float block_hash = hash(vec2(block_x, block_y + floor(time_sec * 8.0)));
        if (block_hash > 0.92) {
            glitch_effect = glitch_strength * 0.3;
        }
        // 心跳红色脉冲
        float heartbeat = pow(max(0.0, sin(time_sec * 6.28)), 4.0);
        glitch_effect += heartbeat * glitch_strength * 0.1;
    }

    // 数字衰变粒子 (50%-25%)
    float particle_effect = 0.0;
    if (hp_ratio < 0.50 && hp_ratio > 0.0) {
        float particle_strength = (0.50 - hp_ratio) / 0.50;
        float px = hash(vec2(floor(uv.x * 40.0), floor(time_sec * 4.0)));
        float py = hash(vec2(floor(uv.y * 40.0), floor(time_sec * 3.0 + 1.0)));
        if (px > 0.97 && abs(adjusted_y - wave_center) < 0.1) {
            particle_effect = particle_strength * 0.4 * py;
        }
    }

    // 最终合成
    vec3 final_color = hp_color * (line + glow) + flash_color;
    final_color += hp_color * fill_alpha;
    final_color += hp_color * particle_effect;
    final_color += COLOR_ERROR_RED * glitch_effect;

    float final_alpha = max(line, glow);
    final_alpha = max(final_alpha, fill_alpha);
    final_alpha = max(final_alpha, flash_alpha);
    final_alpha = max(final_alpha, glitch_effect);
    final_alpha = max(final_alpha, particle_effect);

    // HP 为 0 时完全透明
    final_alpha *= step(0.001, hp_ratio);

    COLOR = vec4(final_color, final_alpha);
}
