shader_type canvas_item;
// "固化静默" 障碍物 Shader — 黑色玄武岩柱体
// 应用于 Sprite2D 节点，呈现高耸的黑色玄武岩状柱体
//
// 视觉效果：
// 1. 黑色玄武岩质感的柱体表面（六角形裂纹纹理）
// 2. 表面带有均衡器（EQ）频谱起伏的动态视觉效果
// 3. 受击时短暂"亮起"并发出低沉共振光芒
// 4. 边缘有微弱的深蓝/紫色辉光脉冲
// 5. 可与 crystallized_silence.gdshader 叠加使用

uniform sampler2D base_texture : hint_default_white;

// === 控制参数 ===
uniform float eq_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float eq_speed : hint_range(0.0, 5.0) = 2.0;
uniform float eq_band_count : hint_range(4.0, 32.0) = 16.0;
uniform float hit_glow : hint_range(0.0, 1.0) = 0.0;
uniform float beat_energy : hint_range(0.0, 1.0) = 0.0;
uniform float edge_glow_width : hint_range(0.0, 0.15) = 0.04;

// === 颜色 ===
uniform vec4 basalt_color : source_color = vec4(0.08, 0.08, 0.1, 1.0);
uniform vec4 crack_glow_color : source_color = vec4(0.15, 0.1, 0.35, 0.8);
uniform vec4 eq_bar_color : source_color = vec4(0.2, 0.15, 0.5, 0.7);
uniform vec4 hit_glow_color : source_color = vec4(0.4, 0.3, 0.8, 1.0);
uniform vec4 edge_color : source_color = vec4(0.1, 0.05, 0.3, 0.6);

// === 噪声函数 ===
float hash21(vec2 p) {
    p = fract(p * vec2(234.34, 435.345));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
    float n = hash21(p);
    return vec2(n, hash21(p + 0.1));
}

// 六角形 Voronoi — 生成玄武岩柱状节理纹理
float hex_voronoi(vec2 uv, float scale) {
    vec2 id = floor(uv * scale);
    vec2 fd = fract(uv * scale);
    float min_dist = 1.0;
    float second_dist = 1.0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 offset = vec2(float(x), float(y));
            vec2 cell_center = hash22(id + offset);
            // 偏向六角形分布
            cell_center = 0.5 + 0.5 * sin(cell_center * 6.2831 + 1.0);
            float dist = length(fd - offset - cell_center);
            if (dist < min_dist) {
                second_dist = min_dist;
                min_dist = dist;
            } else if (dist < second_dist) {
                second_dist = dist;
            }
        }
    }
    return second_dist - min_dist;
}

// 简单2D噪声
float noise2d(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// EQ频谱模拟 — 基于UV.x位置生成不同频段的"柱状"高度
float eq_spectrum(float x_pos, float time) {
    float band = floor(x_pos * eq_band_count) / eq_band_count;
    // 每个频段有不同的频率和相位
    float freq = 1.0 + band * 3.0;
    float phase = band * 17.3;
    float height = sin(time * eq_speed * freq + phase) * 0.5 + 0.5;
    // 添加一些随机性
    height *= 0.5 + 0.5 * noise2d(vec2(band * 10.0, time * 0.5));
    // 低频段振幅更大
    height *= mix(1.0, 0.4, band);
    return height * eq_intensity;
}

void fragment() {
    vec2 uv = UV;
    vec4 base = texture(base_texture, uv);

    // === 1. 玄武岩柱状节理纹理 ===
    float hex_cracks = hex_voronoi(uv, 6.0);
    float crack_line = smoothstep(0.0, 0.06, hex_cracks);
    float crack_edge = 1.0 - smoothstep(0.0, 0.12, hex_cracks);

    // 基础玄武岩颜色（深黑色）
    vec3 surface = basalt_color.rgb;

    // 柱状节理裂纹中的微弱发光
    float crack_pulse = sin(TIME * 1.5) * 0.5 + 0.5;
    vec3 crack_col = crack_glow_color.rgb * crack_edge * 0.4 * (0.3 + crack_pulse * 0.7);

    // 表面微妙的纹理变化
    float surface_noise = noise2d(uv * 12.0) * 0.15;
    surface += surface_noise * 0.05;

    // === 2. EQ 频谱动态效果 ===
    // 频谱从底部向上延伸
    float eq_height = eq_spectrum(uv.x, TIME);
    // 节拍能量增强频谱
    eq_height *= (1.0 + beat_energy * 2.0);
    // 频谱条：当UV.y > (1.0 - eq_height)时显示
    float eq_threshold = 1.0 - uv.y;  // 从底部开始
    float eq_mask = smoothstep(eq_height - 0.02, eq_height, eq_threshold);
    eq_mask = (1.0 - eq_mask) * step(0.01, eq_height);
    // 频谱条的颜色（从底部的暗紫到顶部的亮蓝）
    vec3 eq_col = mix(eq_bar_color.rgb, eq_bar_color.rgb * 2.0, eq_threshold);
    eq_col *= eq_mask * 0.6;

    // === 3. 受击亮起效果 ===
    vec3 hit_col = hit_glow_color.rgb * hit_glow;
    // 受击时裂纹更亮
    float hit_crack_boost = crack_edge * hit_glow * 3.0;
    hit_col += hit_glow_color.rgb * hit_crack_boost;

    // === 4. 边缘辉光 ===
    float alpha_center = base.a;
    float sample_dist = edge_glow_width;
    float a_l = texture(base_texture, uv + vec2(-sample_dist, 0.0)).a;
    float a_r = texture(base_texture, uv + vec2(sample_dist, 0.0)).a;
    float a_u = texture(base_texture, uv + vec2(0.0, -sample_dist)).a;
    float a_d = texture(base_texture, uv + vec2(0.0, sample_dist)).a;
    float edge_detect = abs(alpha_center - a_l) + abs(alpha_center - a_r) +
                        abs(alpha_center - a_u) + abs(alpha_center - a_d);
    edge_detect = clamp(edge_detect, 0.0, 1.0);
    float edge_pulse = sin(TIME * 2.0) * 0.5 + 0.5;
    vec3 edge_glow = edge_color.rgb * edge_detect * (0.4 + edge_pulse * 0.3);
    // 节拍能量增强边缘
    edge_glow *= (1.0 + beat_energy * 1.5);

    // === 5. 节拍响应 ===
    // 整体亮度随节拍微弱脉冲
    float beat_brightness = beat_energy * 0.15;

    // === 合成 ===
    vec3 final_rgb = surface;
    // 应用柱状节理裂纹
    final_rgb = mix(final_rgb, final_rgb * 0.6, (1.0 - crack_line) * 0.5);
    // 叠加裂纹发光
    final_rgb += crack_col;
    // 叠加 EQ 频谱
    final_rgb += eq_col;
    // 叠加受击发光
    final_rgb += hit_col;
    // 叠加边缘辉光
    final_rgb += edge_glow;
    // 叠加节拍亮度
    final_rgb += beat_brightness;

    COLOR = vec4(final_rgb, base.a);
}
