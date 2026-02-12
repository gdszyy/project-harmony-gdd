shader_type canvas_item;
// 行走贝斯 — 霓虹灯管 Shader (Issue #69)
// 用于低音提琴轮廓的霓虹灯管视觉效果
// 实现：流动色彩、霓虹辉光、摇摆脉冲、布鲁斯音阶色彩映射

// === 控制参数 ===
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float hp_ratio : hint_range(0.0, 1.0) = 1.0;
uniform float beat_energy : hint_range(0.0, 1.0) = 0.0;
uniform float is_offbeat : hint_range(0.0, 1.0) = 0.0;
uniform vec4 base_tint : source_color = vec4(0.3, 0.15, 0.1, 1.0);

// === 霓虹视觉参数 ===
uniform float color_flow_speed : hint_range(0.0, 10.0) = 2.0;
uniform float neon_glow_intensity : hint_range(0.0, 3.0) = 1.5;
uniform float neon_flicker_speed : hint_range(0.0, 20.0) = 5.0;
uniform float smoke_density : hint_range(0.0, 1.0) = 0.3;

// 布鲁斯音阶色彩（6色循环）
// 电蓝、霓虹粉、琥珀、霓虹绿、霓虹红、霓虹紫
const vec3 BLUES_COLORS[6] = vec3[6](
    vec3(0.0, 0.8, 1.0),
    vec3(0.9, 0.2, 0.8),
    vec3(1.0, 0.6, 0.0),
    vec3(0.2, 1.0, 0.4),
    vec3(1.0, 0.1, 0.3),
    vec3(0.6, 0.3, 1.0)
);

// 伪随机噪声
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
    vec2 uv = UV;
    float time = TIME;
    vec4 color = COLOR;

    // === 流动色彩 ===
    // 沿 UV 的 y 轴（提琴纵向）进行色彩流动
    float flow_pos = fract(uv.y + time * color_flow_speed * 0.1);
    float color_index_f = flow_pos * 6.0;
    int idx0 = int(floor(color_index_f)) % 6;
    int idx1 = (idx0 + 1) % 6;
    float blend = fract(color_index_f);

    vec3 flowing_color = mix(BLUES_COLORS[idx0], BLUES_COLORS[idx1], blend);

    // === 霓虹辉光 ===
    // 边缘发光效果
    float edge_dist = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
    float edge_glow = smoothstep(0.15, 0.0, edge_dist) * neon_glow_intensity;
    flowing_color += flowing_color * edge_glow;

    // 中心区域较暗（灯管内部）
    float center_dark = smoothstep(0.0, 0.3, edge_dist) * 0.3;
    flowing_color *= (0.7 + center_dark);

    // === 霓虹闪烁 ===
    // 模拟真实霓虹灯的微妙闪烁
    float flicker = 0.9 + sin(time * neon_flicker_speed) * 0.05
                  + sin(time * neon_flicker_speed * 2.3) * 0.03
                  + hash(vec2(floor(time * 30.0), 0.0)) * 0.02;
    flowing_color *= flicker;

    // === 节拍脉冲 ===
    // 强拍：整体亮度提升
    flowing_color += flowing_color * beat_energy * 0.5;

    // 反拍：色彩偏移（摇摆感）
    if (is_offbeat > 0.5) {
        // 反拍时色彩向暖色偏移
        flowing_color = mix(flowing_color, vec3(1.0, 0.6, 0.3), 0.15);
        // 额外辉光
        flowing_color += vec3(0.1, 0.05, 0.0);
    }

    // === 烟雾效果（爵士俱乐部氛围）===
    float smoke = noise(uv * 8.0 + vec2(time * 0.3, time * 0.2));
    smoke = smoothstep(0.4, 0.7, smoke) * smoke_density;
    // 烟雾使霓虹光晕染
    flowing_color += flowing_color * smoke * 0.3;
    // 烟雾本身的灰白色
    flowing_color = mix(flowing_color, vec3(0.5, 0.5, 0.55), smoke * 0.15);

    // === 故障效果 ===
    if (glitch_intensity > 0.2) {
        // 霓虹灯管故障：段落熄灭
        float segment = floor(uv.y * 10.0);
        float segment_off = step(0.85 - glitch_intensity * 0.3,
            hash(vec2(segment, floor(time * 8.0))));
        flowing_color *= (1.0 - segment_off * 0.7);

        // 色差
        float ca = glitch_intensity * 0.02;
        flowing_color.r += sin(uv.y * 50.0 + time * 5.0) * ca;
        flowing_color.b -= sin(uv.y * 50.0 + time * 5.0) * ca;
    }

    // === HP 相关效果 ===
    if (hp_ratio < 0.4) {
        float damage_factor = (0.4 - hp_ratio) / 0.4;
        // 低 HP 时霓虹灯管开始闪烁不稳定
        float unstable = step(0.6 - damage_factor * 0.3, hash(vec2(time * 20.0, uv.y * 5.0)));
        flowing_color *= (1.0 - unstable * 0.5);
        // 颜色偏暗
        flowing_color *= (1.0 - damage_factor * 0.3);
    }

    // 混合到基础颜色
    color.rgb = mix(color.rgb * base_tint.rgb, flowing_color, 0.85);
    COLOR = color;
}
