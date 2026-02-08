shader_type canvas_item;

// "固化静默" 障碍物 Shader — 水晶化/石化效果
// 应用于被"固化静默"影响的障碍物 Sprite2D
//
// 视觉效果：
// 1. 表面覆盖半透明水晶纹理（棱角分明的几何图案）
// 2. 内部有缓慢流动的暗紫色能量脉络
// 3. 边缘有微弱的冰蓝色辉光
// 4. 整体色调偏冷灰紫，表现"声音被冻结"的感觉

uniform sampler2D base_texture : hint_default_white;

// === 控制参数 ===
uniform float crystal_intensity : hint_range(0.0, 1.0) = 0.8;
uniform float energy_speed : hint_range(0.0, 3.0) = 0.5;
uniform float edge_glow_width : hint_range(0.0, 0.2) = 0.05;
uniform float crack_density : hint_range(1.0, 20.0) = 8.0;
uniform float pulse_speed : hint_range(0.0, 4.0) = 1.5;
uniform float freeze_progress : hint_range(0.0, 1.0) = 1.0;

// === 颜色 ===
uniform vec4 crystal_color : source_color = vec4(0.55, 0.5, 0.75, 0.9);
uniform vec4 energy_color : source_color = vec4(0.3, 0.1, 0.6, 0.7);
uniform vec4 edge_glow_color : source_color = vec4(0.4, 0.7, 1.0, 0.8);
uniform vec4 crack_color : source_color = vec4(0.2, 0.05, 0.4, 0.6);

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

// Voronoi 距离场 — 生成水晶裂纹图案
float voronoi_cracks(vec2 uv, float scale) {
    vec2 id = floor(uv * scale);
    vec2 fd = fract(uv * scale);

    float min_dist = 1.0;
    float second_dist = 1.0;

    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 offset = vec2(float(x), float(y));
            vec2 cell_center = hash22(id + offset);
            float dist = length(fd - offset - cell_center);

            if (dist < min_dist) {
                second_dist = min_dist;
                min_dist = dist;
            } else if (dist < second_dist) {
                second_dist = dist;
            }
        }
    }

    // 裂纹 = 两个最近点之间的边界
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

// 分形噪声
float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise2d(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

void fragment() {
    vec2 uv = UV;
    vec4 base = texture(base_texture, uv);

    // 冻结进度 (0=正常, 1=完全石化)
    float fp = freeze_progress;

    // === 1. 水晶裂纹图案 ===
    float cracks = voronoi_cracks(uv, crack_density);
    float crack_line = smoothstep(0.0, 0.08, cracks);
    float crack_edge = 1.0 - smoothstep(0.0, 0.15, cracks);

    // 裂纹内部的暗色
    vec3 crack_col = crack_color.rgb * crack_edge * fp;

    // === 2. 能量脉络 (在裂纹中流动) ===
    float energy_flow = fbm(uv * 6.0 + vec2(TIME * energy_speed, TIME * energy_speed * 0.7));
    float energy_in_cracks = energy_flow * crack_edge * fp;
    vec3 energy_col = energy_color.rgb * energy_in_cracks * 1.5;

    // 脉冲呼吸
    float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
    energy_col *= mix(0.5, 1.2, pulse);

    // === 3. 水晶表面覆盖 ===
    // 棱角分明的高光
    float facet_noise = noise2d(uv * crack_density * 2.0);
    float facet_highlight = step(0.7, facet_noise) * 0.3;

    // 水晶半透明覆盖
    vec3 crystal_surface = crystal_color.rgb * crystal_intensity * fp;
    crystal_surface += facet_highlight * fp;

    // === 4. 边缘辉光 ===
    // 检测精灵边缘 (基于 alpha)
    float alpha_center = base.a;
    float edge_detect = 0.0;
    float sample_dist = edge_glow_width;
    float a_l = texture(base_texture, uv + vec2(-sample_dist, 0.0)).a;
    float a_r = texture(base_texture, uv + vec2(sample_dist, 0.0)).a;
    float a_u = texture(base_texture, uv + vec2(0.0, -sample_dist)).a;
    float a_d = texture(base_texture, uv + vec2(0.0, sample_dist)).a;
    edge_detect = abs(alpha_center - a_l) + abs(alpha_center - a_r) +
                  abs(alpha_center - a_u) + abs(alpha_center - a_d);
    edge_detect = clamp(edge_detect, 0.0, 1.0);

    vec3 edge_glow = edge_glow_color.rgb * edge_detect * fp * (0.5 + pulse * 0.5);

    // === 5. 去饱和 (石化效果) ===
    float gray = dot(base.rgb, vec3(0.299, 0.587, 0.114));
    vec3 desaturated = mix(base.rgb, vec3(gray), fp * 0.7);

    // === 合成 ===
    vec3 final_rgb = desaturated;
    // 叠加水晶表面
    final_rgb = mix(final_rgb, crystal_surface, fp * 0.4);
    // 叠加裂纹
    final_rgb = mix(final_rgb, crack_col, crack_edge * fp * 0.5);
    // 叠加能量脉络
    final_rgb += energy_col * 0.6;
    // 叠加边缘辉光
    final_rgb += edge_glow * 0.8;
    // 叠加棱面高光
    final_rgb += facet_highlight * edge_glow_color.rgb * fp * 0.3;

    // 裂纹线条内的微弱发光
    float crack_glow = (1.0 - crack_line) * fp * 0.15;
    final_rgb += energy_color.rgb * crack_glow * (0.5 + pulse * 0.5);

    COLOR = vec4(final_rgb, base.a);
}
