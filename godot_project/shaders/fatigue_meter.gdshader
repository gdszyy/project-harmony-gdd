shader_type canvas_item;

// ============================================================
// 听感疲劳指示器着色器
// 垂直光条，从纤细青色到红色锯齿波故障
// ============================================================

uniform float afi_ratio : hint_range(0.0, 1.0) = 0.0;
uniform float beat_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float time_sec : hint_range(0.0, 9999.0) = 0.0;

// 颜色常量
const vec3 COLOR_CYAN     = vec3(0.0, 1.0, 0.831);   // #00FFD4
const vec3 COLOR_YELLOW   = vec3(1.0, 0.875, 0.4);    // #FFE066
const vec3 COLOR_ORANGE   = vec3(1.0, 0.533, 0.0);    // #FF8800
const vec3 COLOR_RED      = vec3(1.0, 0.133, 0.267);  // #FF2244

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

vec3 get_afi_color(float afi) {
    if (afi < 0.4) {
        return COLOR_CYAN;
    } else if (afi < 0.6) {
        float t = (afi - 0.4) / 0.2;
        return mix(COLOR_CYAN, COLOR_YELLOW, t);
    } else if (afi < 0.8) {
        float t = (afi - 0.6) / 0.2;
        return mix(COLOR_YELLOW, COLOR_ORANGE, t);
    } else {
        float t = (afi - 0.8) / 0.2;
        return mix(COLOR_ORANGE, COLOR_RED, t);
    }
}

void fragment() {
    vec2 uv = UV;

    // 垂直填充：从底部向上 (UV.y=1 是底部, UV.y=0 是顶部)
    float fill_y = 1.0 - uv.y;
    float fill_mask = step(fill_y, afi_ratio);

    // 光条宽度随 AFI 增加而加宽
    float base_width = mix(0.3, 0.8, afi_ratio);
    float center_dist = abs(uv.x - 0.5);

    // 波形边缘
    float edge_wave = 0.0;
    if (afi_ratio > 0.4) {
        float wave_strength = (afi_ratio - 0.4) / 0.6;
        float freq = mix(4.0, 15.0, wave_strength);
        if (afi_ratio < 0.8) {
            // 三角波形态
            edge_wave = abs(mod(uv.y * freq + time_sec * 2.0, 2.0) - 1.0) * 0.15 * wave_strength;
        } else {
            // 锯齿波形态
            edge_wave = mod(uv.y * freq + time_sec * 3.0, 1.0) * 0.2 * wave_strength;
            // 不规则抖动
            edge_wave += noise(vec2(uv.y * 20.0, time_sec * 8.0)) * 0.1 * wave_strength;
        }
    }

    float adjusted_width = base_width * 0.5 + edge_wave;
    float bar_mask = smoothstep(adjusted_width + 0.02, adjusted_width - 0.02, center_dist);
    bar_mask *= fill_mask;

    // 颜色
    vec3 bar_color = get_afi_color(afi_ratio);

    // 呼吸光效
    float breath = sin(time_sec * 2.0) * 0.1 + 0.9;
    bar_color *= breath;

    // 节拍同步脉动 (AFI > 0.6)
    if (afi_ratio > 0.6) {
        float beat_pulse = beat_intensity * (afi_ratio - 0.6) / 0.4;
        bar_color *= (1.0 + beat_pulse * 0.4);

        // 故障效果
        float glitch_strength = beat_pulse * 0.5;
        float block = floor(uv.y * 20.0);
        float block_hash = hash(vec2(block, floor(time_sec * 15.0)));
        if (block_hash > 0.85) {
            // UV 偏移
            bar_color.r += glitch_strength * 0.3;
            bar_color.b -= glitch_strength * 0.2;
        }
    }

    // 辉光
    float glow_dist = max(0.0, center_dist - adjusted_width);
    float glow = smoothstep(0.15, 0.0, glow_dist) * 0.3 * fill_mask;
    glow *= (1.0 + beat_intensity * 0.3);

    // 高 AFI 时的粒子喷发效果
    float particles = 0.0;
    if (afi_ratio > 0.6) {
        float particle_strength = (afi_ratio - 0.6) / 0.4;
        float px = hash(vec2(floor(uv.x * 10.0), floor(time_sec * 6.0)));
        float py = hash(vec2(floor(uv.y * 30.0), floor(time_sec * 5.0)));
        if (px > 0.8 && py > 0.85 && fill_mask > 0.5) {
            particles = particle_strength * 0.5;
        }
    }

    // 色彩通道分离 (高 AFI + 节拍)
    float ca_effect = 0.0;
    if (afi_ratio > 0.8) {
        float ca_strength = (afi_ratio - 0.8) / 0.2 * beat_intensity;
        float ca_offset = ca_strength * 0.03;
        // 简化的色差效果
        ca_effect = ca_strength * 0.2 * step(0.5, hash(vec2(floor(uv.y * 15.0), floor(time_sec * 20.0))));
    }

    // 合成
    vec3 final_color = bar_color * bar_mask;
    final_color += bar_color * glow;
    final_color += bar_color * particles;
    final_color.r += ca_effect;

    float final_alpha = max(bar_mask, glow);
    final_alpha = max(final_alpha, particles);

    COLOR = vec4(final_color, final_alpha);
}
