shader_type canvas_item;

// 对位爬虫 (Counterpoint Crawler) 身体着色器
// Issue #66: 程序化生成铜管齿轮和键盘键图案
// 在 UV 空间使用 sin/cos 和 floor 函数生成巴洛克机械纹理

uniform vec4 brass_color : source_color = vec4(0.7, 0.5, 0.2, 1.0);
uniform vec4 dark_color : source_color = vec4(0.3, 0.2, 0.1, 1.0);
uniform vec4 accent_color : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform float gear_scale : hint_range(1.0, 20.0) = 6.0;
uniform float rotation_speed : hint_range(0.0, 3.0) = 0.5;
uniform float key_count : hint_range(4.0, 16.0) = 8.0;
uniform float beat_energy : hint_range(0.0, 1.0) = 0.0;
uniform float damage_ratio : hint_range(0.0, 1.0) = 0.0;

// 齿轮形状 SDF
float gear_sdf(vec2 uv, float teeth, float inner_r, float outer_r) {
    float a = atan(uv.y, uv.x);
    float r = length(uv);
    float tooth = sin(a * teeth) * 0.5 + 0.5;
    float gear_r = mix(inner_r, outer_r, smoothstep(0.3, 0.7, tooth));
    return smoothstep(gear_r + 0.02, gear_r, r) * smoothstep(inner_r * 0.3, inner_r * 0.35, r);
}

void fragment() {
    vec2 uv = UV * 2.0 - 1.0; // 归一化到 [-1, 1]
    float t = TIME * rotation_speed;

    vec3 final_color = dark_color.rgb;

    // 齿轮图案 — 中心大齿轮
    float c1 = cos(t);
    float s1 = sin(t);
    vec2 rot_uv = vec2(uv.x * c1 - uv.y * s1, uv.x * s1 + uv.y * c1);
    float g1 = gear_sdf(rot_uv * gear_scale, 12.0, 0.3, 0.45);
    final_color = mix(final_color, brass_color.rgb * 0.8, g1 * 0.7);

    // 小齿轮 — 偏移位置，反向旋转
    float c2 = cos(-t * 1.5);
    float s2 = sin(-t * 1.5);
    vec2 uv2 = (uv - vec2(0.4, 0.0)) * gear_scale;
    uv2 = vec2(uv2.x * c2 - uv2.y * s2, uv2.x * s2 + uv2.y * c2);
    float g2 = gear_sdf(uv2, 8.0, 0.2, 0.3);
    final_color = mix(final_color, brass_color.rgb * 0.6, g2 * 0.5);

    // 键盘键图案 — 底部区域
    float key_region = smoothstep(0.3, 0.5, UV.y); // 下半部分
    if (key_region > 0.0) {
        float key_x = floor(UV.x * key_count);
        float is_black_key = step(0.5, fract(key_x * 0.583)); // 近似黑键分布
        float key_edge = smoothstep(0.02, 0.0, abs(fract(UV.x * key_count) - 0.5) - 0.45);

        vec3 key_color = mix(
            vec3(0.9, 0.85, 0.8),  // 白键
            vec3(0.15, 0.1, 0.08), // 黑键
            is_black_key
        );
        final_color = mix(final_color, key_color, key_region * 0.4 * (1.0 - key_edge * 0.5));
    }

    // 齿轮中心轴
    float center_dot = smoothstep(0.08, 0.05, length(rot_uv * gear_scale));
    final_color = mix(final_color, accent_color.rgb, center_dot * 0.8);

    // 节拍脉冲 — 齿轮边缘发光
    float beat_glow = beat_energy * 0.5;
    final_color += accent_color.rgb * beat_glow * max(g1, g2);

    // 受伤效果 — 颜色偏移和闪烁
    if (damage_ratio > 0.0) {
        float damage_flash = sin(TIME * 10.0 * damage_ratio) * 0.5 + 0.5;
        final_color = mix(final_color, vec3(1.0, 0.3, 0.1), damage_ratio * 0.3 * damage_flash);
    }

    COLOR = vec4(final_color, brass_color.a);
}
