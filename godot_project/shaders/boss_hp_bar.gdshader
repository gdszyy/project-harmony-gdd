shader_type canvas_item;

// Boss 血条容器纹理 Shader
// 每个章节的 Boss 拥有独特的血条视觉风格
//
// 章节主题：
// 1 - 毕达哥拉斯 (几何/数学): 旋转的几何图案，金色+白色
// 2 - 圭多 (圣咏/记谱): 五线谱纹理，羊皮纸色+圣光
// 3 - 巴赫 (赋格/对位): 交织的对位线条，深蓝+银色
// 4 - 莫扎特 (古典/优雅): 华丽的装饰纹样，金色+象牙白
// 5 - 贝多芬 (狂想/命运): 雷电裂纹，深红+暗金

uniform sampler2D bar_texture : hint_default_white;

// === 控制参数 ===
uniform float hp_ratio : hint_range(0.0, 1.0) = 1.0;
uniform int chapter : hint_range(1, 5) = 1;
uniform float phase_progress : hint_range(0.0, 1.0) = 0.0;
uniform float damage_flash : hint_range(0.0, 1.0) = 0.0;
uniform float phase_transition : hint_range(0.0, 1.0) = 0.0;

// === 颜色 ===
uniform vec4 bar_fill_color : source_color = vec4(0.8, 0.1, 0.1, 1.0);
uniform vec4 bar_bg_color : source_color = vec4(0.1, 0.08, 0.15, 0.9);
uniform vec4 bar_border_color : source_color = vec4(0.6, 0.5, 0.3, 1.0);

// === 噪声 ===
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

float fbm(vec2 p, int octaves) {
    float val = 0.0;
    float amp = 0.5;
    for (int i = 0; i < octaves; i++) {
        val += amp * noise(p);
        p *= 2.0;
        amp *= 0.5;
    }
    return val;
}

// === 章节1: 毕达哥拉斯 — 几何图案 ===
vec3 chapter1_pattern(vec2 uv) {
    // 旋转的同心圆和辐射线
    vec2 center = uv - vec2(hp_ratio * 0.5, 0.5);
    float angle = atan(center.y, center.x);
    float dist = length(center);

    // 辐射线
    float rays = sin(angle * 8.0 + TIME * 0.5) * 0.5 + 0.5;
    rays *= smoothstep(0.5, 0.0, dist);

    // 同心圆
    float circles = sin(dist * 30.0 - TIME * 2.0) * 0.5 + 0.5;
    circles *= smoothstep(0.5, 0.0, dist);

    // 金色+白色
    vec3 col = mix(vec3(1.0, 0.85, 0.2), vec3(1.0), rays * 0.3);
    col *= 0.3 + circles * 0.2 + rays * 0.15;
    return col;
}

// === 章节2: 圭多 — 五线谱纹理 ===
vec3 chapter2_pattern(vec2 uv) {
    // 五条水平线
    float line_width = 0.015;
    float staff_lines = 0.0;
    for (int i = 0; i < 5; i++) {
        float line_y = 0.2 + float(i) * 0.15;
        staff_lines += smoothstep(line_width, 0.0, abs(uv.y - line_y));
    }

    // 流动的音符符号（简化为小圆点）
    float notes = 0.0;
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float note_x = fract(fi * 0.25 + TIME * 0.1);
        float note_y = 0.2 + floor(hash(vec2(fi, 1.0)) * 5.0) * 0.15;
        float note = smoothstep(0.02, 0.0, length(uv - vec2(note_x, note_y)));
        notes += note;
    }

    // 羊皮纸色 + 圣光金
    vec3 col = vec3(0.9, 0.85, 0.7) * 0.15;
    col += vec3(1.0, 0.9, 0.5) * staff_lines * 0.3;
    col += vec3(1.0, 0.95, 0.7) * notes * 0.5;
    return col;
}

// === 章节3: 巴赫 — 对位线条 ===
vec3 chapter3_pattern(vec2 uv) {
    // 两组交织的波浪线（对位法）
    float wave1 = sin(uv.x * 15.0 + TIME * 1.5) * 0.15;
    float wave2 = sin(uv.x * 15.0 - TIME * 1.5 + 3.14) * 0.15;

    float line1 = smoothstep(0.02, 0.0, abs(uv.y - 0.5 - wave1));
    float line2 = smoothstep(0.02, 0.0, abs(uv.y - 0.5 - wave2));

    // 交叉点高亮
    float intersection = line1 * line2;

    // 深蓝+银色
    vec3 col = vec3(0.1, 0.15, 0.3) * 0.2;
    col += vec3(0.3, 0.4, 0.8) * line1 * 0.4;
    col += vec3(0.7, 0.75, 0.9) * line2 * 0.3;
    col += vec3(1.0) * intersection * 0.5;
    return col;
}

// === 章节4: 莫扎特 — 华丽装饰 ===
vec3 chapter4_pattern(vec2 uv) {
    // 优雅的卷曲装饰纹样
    float scroll = sin(uv.x * 10.0 + sin(uv.y * 8.0) * 2.0 + TIME * 0.3);
    scroll = smoothstep(0.8, 1.0, scroll);

    // 对称花纹
    vec2 sym_uv = vec2(uv.x, abs(uv.y - 0.5));
    float ornament = sin(sym_uv.x * 20.0) * sin(sym_uv.y * 20.0);
    ornament = smoothstep(0.6, 0.8, ornament);

    // 金色+象牙白
    vec3 col = vec3(0.95, 0.9, 0.8) * 0.1;
    col += vec3(1.0, 0.85, 0.3) * scroll * 0.35;
    col += vec3(1.0, 0.95, 0.85) * ornament * 0.2;
    return col;
}

// === 章节5: 贝多芬 — 雷电裂纹 ===
vec3 chapter5_pattern(vec2 uv) {
    // 闪电/裂纹效果
    float lightning = 0.0;
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float offset = hash(vec2(fi, floor(TIME * 3.0))) * 0.6 + 0.2;
        float bolt_x = uv.y * 10.0 + fi * 3.0;
        float bolt = noise(vec2(bolt_x, TIME * 5.0 + fi));
        float line_dist = abs(uv.x - offset - bolt * 0.1);
        lightning += smoothstep(0.02, 0.0, line_dist) * step(0.7, hash(vec2(fi, floor(TIME * 2.0))));
    }

    // 背景裂纹纹理
    float cracks = fbm(uv * 8.0, 3);
    cracks = smoothstep(0.45, 0.55, cracks);

    // 深红+暗金
    vec3 col = vec3(0.3, 0.05, 0.05) * 0.2;
    col += vec3(0.8, 0.2, 0.1) * cracks * 0.2;
    col += vec3(1.0, 0.9, 0.5) * lightning * 0.8;

    // 脉冲
    float pulse = sin(TIME * 3.0) * 0.5 + 0.5;
    col += vec3(0.5, 0.1, 0.0) * pulse * 0.1;
    return col;
}

void fragment() {
    vec2 uv = UV;
    vec4 base = texture(bar_texture, uv);

    // === 血条填充区域 ===
    float fill = step(uv.x, hp_ratio);

    // === 章节特定纹理 ===
    vec3 pattern = vec3(0.0);
    if (chapter == 1) {
        pattern = chapter1_pattern(uv);
    } else if (chapter == 2) {
        pattern = chapter2_pattern(uv);
    } else if (chapter == 3) {
        pattern = chapter3_pattern(uv);
    } else if (chapter == 4) {
        pattern = chapter4_pattern(uv);
    } else {
        pattern = chapter5_pattern(uv);
    }

    // === 血条边框 ===
    float border_width = 0.03;
    float border = 0.0;
    border += step(uv.x, border_width);
    border += step(1.0 - border_width, uv.x);
    border += step(uv.y, border_width);
    border += step(1.0 - border_width, uv.y);
    border = clamp(border, 0.0, 1.0);

    // 圆角边框
    vec2 corner_dist = min(uv, 1.0 - uv);
    float corner_radius = 0.04;
    float corner = step(corner_dist.x, corner_radius) * step(corner_dist.y, corner_radius);
    float corner_circle = step(corner_radius, length(corner_dist - vec2(corner_radius)));
    border = max(border, corner * corner_circle);

    // === 填充颜色 ===
    vec3 fill_color = bar_fill_color.rgb;

    // 低血量时颜色变化 (红色加深 + 脉冲)
    if (hp_ratio < 0.3) {
        float danger_pulse = sin(TIME * 6.0) * 0.5 + 0.5;
        fill_color = mix(fill_color, vec3(1.0, 0.0, 0.0), (0.3 - hp_ratio) * 2.0);
        fill_color *= 0.7 + danger_pulse * 0.3;
    }

    // 叠加章节纹理到填充区域
    fill_color += pattern * 0.5;

    // === 受击闪白 ===
    fill_color = mix(fill_color, vec3(1.0), damage_flash * 0.6);

    // === 阶段转换效果 ===
    if (phase_transition > 0.0) {
        float transition_wave = sin(uv.x * 30.0 - TIME * 10.0) * 0.5 + 0.5;
        fill_color += vec3(1.0, 0.9, 0.5) * transition_wave * phase_transition * 0.5;
    }

    // === 血条末端发光 ===
    float edge_glow = smoothstep(0.02, 0.0, abs(uv.x - hp_ratio)) * fill;
    vec3 glow_color = vec3(1.0, 0.8, 0.3);
    if (hp_ratio < 0.3) {
        glow_color = vec3(1.0, 0.2, 0.1);
    }

    // === 合成 ===
    vec3 final_color = bar_bg_color.rgb;

    // 填充区域
    final_color = mix(final_color, fill_color, fill);

    // 血条末端发光
    final_color += glow_color * edge_glow * 0.5;

    // 边框
    final_color = mix(final_color, bar_border_color.rgb + pattern * 0.3, border);

    // 背景区域的微弱纹理
    final_color += pattern * (1.0 - fill) * 0.1;

    float final_alpha = max(base.a, border * 0.9);
    final_alpha = max(final_alpha, fill * bar_fill_color.a);
    final_alpha = max(final_alpha, (1.0 - fill) * bar_bg_color.a);

    COLOR = vec4(final_color, final_alpha);
}
