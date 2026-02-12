shader_type canvas_item;

// ============================================================
// Boss 血条主题化着色器
// 7 种 Boss 各有独特的容器纹理和能量流动效果
// 1-毕达哥拉斯(克拉尼图形)  2-圭多(哥特拱门)  3-巴赫(管风琴齿轮)
// 4-莫扎特(洛可可金框)  5-贝多芬(破碎岩石闪电)  6-爵士(霓虹灯管)
// 7-噪音(故障像素)
// ============================================================

uniform sampler2D bar_texture : hint_default_white;

uniform float hp_ratio : hint_range(0.0, 1.0) = 1.0;
uniform int chapter : hint_range(1, 7) = 1;
uniform float damage_flash : hint_range(0.0, 1.0) = 0.0;
uniform float phase_transition : hint_range(0.0, 1.0) = 0.0;
uniform float beat_intensity : hint_range(0.0, 1.0) = 0.0;

uniform vec4 bar_fill_color : source_color = vec4(0.0, 1.0, 0.831, 1.0);
uniform vec4 bar_bg_color : source_color = vec4(0.078, 0.063, 0.149, 0.9);
uniform vec4 bar_border_color : source_color = vec4(0.616, 0.435, 1.0, 1.0);

// === 噪声工具 ===
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

// === 章节1: 毕达哥拉斯 — 克拉尼图形 ===
vec3 ch1_chladni(vec2 uv) {
    vec2 center = uv - vec2(0.5);
    float dist = length(center);
    float angle = atan(center.y, center.x);

    // 克拉尼图形：对称振动模式
    float m = 3.0 + sin(TIME * 0.3) * 1.0;
    float n = 2.0 + cos(TIME * 0.4) * 1.0;
    float chladni = abs(sin(m * PI * uv.x) * sin(n * PI * uv.y)
                      + sin(n * PI * uv.x) * sin(m * PI * uv.y));
    chladni = smoothstep(0.05, 0.0, chladni);

    // 辐射线
    float rays = sin(angle * 8.0 + TIME * 0.5) * 0.5 + 0.5;
    rays *= smoothstep(0.5, 0.0, dist);

    vec3 col = mix(vec3(0.0, 1.0, 0.831), vec3(0.918, 0.902, 1.0), chladni * 0.6);
    col *= 0.3 + rays * 0.15 + chladni * 0.3;
    return col;
}

// === 章节2: 圭多 — 哥特拱门 ===
vec3 ch2_gothic(vec2 uv) {
    // 尖顶拱门形状
    float arch_x = abs(uv.x - 0.5) * 2.0;
    float arch_y = uv.y;
    float arch = smoothstep(0.0, 0.02, arch_x * arch_x + (1.0 - arch_y) * 0.5 - 0.3);

    // 五线谱
    float staff = 0.0;
    for (int i = 0; i < 5; i++) {
        float line_y = 0.2 + float(i) * 0.15;
        staff += smoothstep(0.012, 0.0, abs(uv.y - line_y));
    }

    // 流动音符
    float notes = 0.0;
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float note_x = fract(fi * 0.25 + TIME * 0.08);
        float note_y = 0.2 + floor(hash(vec2(fi, 1.0)) * 5.0) * 0.15;
        notes += smoothstep(0.02, 0.0, length(uv - vec2(note_x, note_y)));
    }

    // 羊皮纸色 + 圣光金
    vec3 col = vec3(0.4, 0.15, 0.1) * 0.2;
    col += vec3(1.0, 0.85, 0.2) * staff * 0.25;
    col += vec3(1.0, 0.95, 0.7) * notes * 0.4;
    col += vec3(0.9, 0.85, 0.7) * (1.0 - arch) * 0.1;
    return col;
}

// === 章节3: 巴赫 — 管风琴齿轮 ===
vec3 ch3_organ_gears(vec2 uv) {
    // 齿轮
    vec2 gear_center = vec2(0.2, 0.5);
    vec2 gear_delta = uv - gear_center;
    float gear_dist = length(gear_delta);
    float gear_angle = atan(gear_delta.y, gear_delta.x);
    float teeth = sin(gear_angle * 12.0 + TIME * 1.5) * 0.5 + 0.5;
    float gear = smoothstep(0.15, 0.12, gear_dist) * teeth;

    // 第二个齿轮
    vec2 gear2_center = vec2(0.8, 0.5);
    vec2 gear2_delta = uv - gear2_center;
    float gear2_dist = length(gear2_delta);
    float gear2_angle = atan(gear2_delta.y, gear2_delta.x);
    float teeth2 = sin(gear2_angle * 12.0 - TIME * 1.5) * 0.5 + 0.5;
    float gear2 = smoothstep(0.15, 0.12, gear2_dist) * teeth2;

    // 管风琴音管
    float pipes = 0.0;
    for (int i = 0; i < 6; i++) {
        float pipe_x = 0.3 + float(i) * 0.08;
        float pipe_height = 0.3 + hash(vec2(float(i), 0.0)) * 0.4;
        float pipe = smoothstep(0.015, 0.0, abs(uv.x - pipe_x)) * step(1.0 - pipe_height, uv.y);
        pipes += pipe;
    }

    // 对位线条
    float wave1 = sin(uv.x * 15.0 + TIME * 1.5) * 0.12;
    float wave2 = sin(uv.x * 15.0 - TIME * 1.5 + 3.14) * 0.12;
    float line1 = smoothstep(0.015, 0.0, abs(uv.y - 0.5 - wave1));
    float line2 = smoothstep(0.015, 0.0, abs(uv.y - 0.5 - wave2));

    // 黄铜 / 暗金
    vec3 col = vec3(0.15, 0.12, 0.08) * 0.2;
    col += vec3(0.7, 0.55, 0.2) * (gear + gear2) * 0.35;
    col += vec3(0.5, 0.4, 0.15) * pipes * 0.3;
    col += vec3(0.3, 0.4, 0.8) * line1 * 0.3;
    col += vec3(0.7, 0.75, 0.9) * line2 * 0.2;
    return col;
}

// === 章节4: 莫扎特 — 洛可可金框 ===
vec3 ch4_rococo(vec2 uv) {
    // 卷草纹
    float scroll = sin(uv.x * 12.0 + sin(uv.y * 10.0) * 2.5 + TIME * 0.2);
    scroll = smoothstep(0.85, 1.0, scroll);

    // 对称花饰
    vec2 sym_uv = vec2(uv.x, abs(uv.y - 0.5));
    float ornament = sin(sym_uv.x * 25.0) * sin(sym_uv.y * 25.0);
    ornament = smoothstep(0.65, 0.85, ornament);

    // 花纹边框
    float border_pattern = sin(uv.x * 40.0) * sin(uv.y * 40.0);
    border_pattern = smoothstep(0.9, 1.0, border_pattern) * 0.3;

    // 象牙白 / 金色
    vec3 col = vec3(0.95, 0.92, 0.85) * 0.1;
    col += vec3(1.0, 0.85, 0.3) * scroll * 0.4;
    col += vec3(1.0, 0.95, 0.85) * ornament * 0.25;
    col += vec3(0.9, 0.8, 0.4) * border_pattern;
    return col;
}

// === 章节5: 贝多芬 — 破碎岩石闪电 ===
vec3 ch5_lightning(vec2 uv) {
    // 闪电
    float lightning = 0.0;
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float offset = hash(vec2(fi, floor(TIME * 3.0))) * 0.6 + 0.2;
        float bolt_x = uv.y * 12.0 + fi * 3.0;
        float bolt = noise(vec2(bolt_x, TIME * 6.0 + fi));
        float line_dist = abs(uv.x - offset - bolt * 0.12);
        float flash_trigger = step(0.65, hash(vec2(fi, floor(TIME * 2.0))));
        // 低血量时闪电更频繁
        flash_trigger = max(flash_trigger, step(0.4, 1.0 - hp_ratio));
        lightning += smoothstep(0.015, 0.0, line_dist) * flash_trigger;
    }

    // 岩石裂纹
    float cracks = fbm(uv * 10.0, 4);
    cracks = smoothstep(0.42, 0.58, cracks);

    // 崩裂效果
    float crumble = noise(uv * 20.0 + TIME * 0.5);
    crumble = smoothstep(0.7, 0.8, crumble) * 0.3;

    // 橙红 / 闪电白
    vec3 col = vec3(0.35, 0.06, 0.04) * 0.25;
    col += vec3(0.8, 0.25, 0.1) * cracks * 0.25;
    col += vec3(1.0, 0.95, 0.8) * lightning * 0.9;
    col += vec3(0.6, 0.2, 0.05) * crumble;

    // 脉冲
    float pulse = sin(TIME * 4.0) * 0.5 + 0.5;
    col += vec3(0.5, 0.1, 0.0) * pulse * 0.08;
    return col;
}

// === 章节6: 爵士 — 霓虹灯管 ===
vec3 ch6_neon(vec2 uv) {
    // 弯曲霓虹灯管
    float tube1 = smoothstep(0.025, 0.0, abs(uv.y - 0.3 - sin(uv.x * 8.0 + TIME) * 0.1));
    float tube2 = smoothstep(0.025, 0.0, abs(uv.y - 0.7 + sin(uv.x * 6.0 - TIME * 0.8) * 0.08));

    // 频闪效果
    float strobe = sin(TIME * 12.0) * 0.5 + 0.5;
    float strobe2 = sin(TIME * 8.0 + 2.0) * 0.5 + 0.5;

    // 光晕
    float halo1 = smoothstep(0.1, 0.0, abs(uv.y - 0.3 - sin(uv.x * 8.0 + TIME) * 0.1)) * 0.3;
    float halo2 = smoothstep(0.1, 0.0, abs(uv.y - 0.7 + sin(uv.x * 6.0 - TIME * 0.8) * 0.08)) * 0.3;

    // 霓虹蓝 / 粉色
    vec3 col = vec3(0.02, 0.02, 0.05) * 0.2;
    col += vec3(0.2, 0.5, 1.0) * (tube1 * strobe + halo1) * 0.6;
    col += vec3(1.0, 0.3, 0.6) * (tube2 * strobe2 + halo2) * 0.5;

    // 背景霓虹反射
    col += vec3(0.1, 0.2, 0.4) * noise(uv * 5.0 + TIME * 0.3) * 0.1;
    return col;
}

// === 章节7: 噪音 — 故障像素 ===
vec3 ch7_glitch(vec2 uv) {
    // 像素块解构
    float block_size = 0.03 + sin(TIME * 2.0) * 0.01;
    vec2 block_uv = floor(uv / block_size) * block_size;
    float block_hash = hash(block_uv + floor(TIME * 8.0));

    // 像素错位
    vec2 offset = vec2(0.0);
    if (block_hash > 0.7) {
        offset.x = (block_hash - 0.7) * 0.15 * sin(TIME * 20.0);
    }
    vec2 shifted_uv = uv + offset;

    // 数据流
    float data_stream = hash(vec2(floor(shifted_uv.x * 40.0), floor(shifted_uv.y * 40.0 + TIME * 10.0)));
    data_stream = step(0.85, data_stream);

    // 色彩分离
    float r = hash(block_uv + vec2(TIME * 3.0, 0.0));
    float g = hash(block_uv + vec2(0.0, TIME * 3.0));
    float b = hash(block_uv + vec2(TIME * 2.0, TIME * 2.0));

    // 全频谱故障色
    vec3 col = vec3(r, g, b) * 0.15;
    col += vec3(1.0) * data_stream * 0.3;

    // 扫描线
    float scanline = sin(uv.y * 200.0 + TIME * 5.0) * 0.5 + 0.5;
    col *= 0.8 + scanline * 0.2;

    return col;
}

void fragment() {
    vec2 uv = UV;

    // === 血条填充区域 ===
    float fill = step(uv.x, hp_ratio);

    // === 章节特定纹理 ===
    vec3 pattern = vec3(0.0);
    if (chapter == 1) {
        pattern = ch1_chladni(uv);
    } else if (chapter == 2) {
        pattern = ch2_gothic(uv);
    } else if (chapter == 3) {
        pattern = ch3_organ_gears(uv);
    } else if (chapter == 4) {
        pattern = ch4_rococo(uv);
    } else if (chapter == 5) {
        pattern = ch5_lightning(uv);
    } else if (chapter == 6) {
        pattern = ch6_neon(uv);
    } else {
        pattern = ch7_glitch(uv);
    }

    // === 血条边框 ===
    float border_width = 0.025;
    float border = 0.0;
    border += step(uv.x, border_width);
    border += step(1.0 - border_width, uv.x);
    border += step(uv.y, border_width);
    border += step(1.0 - border_width, uv.y);
    border = clamp(border, 0.0, 1.0);

    // 圆角
    vec2 corner_dist = min(uv, 1.0 - uv);
    float corner_radius = 0.035;
    float corner = step(corner_dist.x, corner_radius) * step(corner_dist.y, corner_radius);
    float corner_circle = step(corner_radius, length(corner_dist - vec2(corner_radius)));
    border = max(border, corner * corner_circle);

    // === 填充颜色 ===
    vec3 fill_color = bar_fill_color.rgb;

    // 低血量脉冲
    if (hp_ratio < 0.3) {
        float danger_pulse = sin(TIME * 6.0) * 0.5 + 0.5;
        fill_color = mix(fill_color, vec3(1.0, 0.0, 0.0), (0.3 - hp_ratio) * 2.5);
        fill_color *= 0.7 + danger_pulse * 0.3;
    }

    // 叠加章节纹理
    fill_color += pattern * 0.5;

    // 节拍脉动
    fill_color *= 1.0 + beat_intensity * 0.15;

    // === 受击闪白 ===
    fill_color = mix(fill_color, vec3(1.0), damage_flash * 0.7);

    // === 阶段转换 ===
    if (phase_transition > 0.0) {
        float wave = sin(uv.x * 30.0 - TIME * 10.0) * 0.5 + 0.5;
        fill_color += vec3(1.0, 0.9, 0.5) * wave * phase_transition * 0.5;
    }

    // === 血条末端发光 ===
    float edge_glow = smoothstep(0.02, 0.0, abs(uv.x - hp_ratio)) * fill;
    vec3 glow_color = bar_fill_color.rgb;
    if (hp_ratio < 0.3) {
        glow_color = vec3(1.0, 0.2, 0.1);
    }

    // === 合成 ===
    vec3 final_color = bar_bg_color.rgb;
    final_color = mix(final_color, fill_color, fill);
    final_color += glow_color * edge_glow * 0.6;
    final_color = mix(final_color, bar_border_color.rgb + pattern * 0.3, border);
    final_color += pattern * (1.0 - fill) * 0.08;

    float final_alpha = max(border * 0.9, fill * bar_fill_color.a);
    final_alpha = max(final_alpha, (1.0 - fill) * bar_bg_color.a);
    final_alpha = max(final_alpha, edge_glow * 0.5);

    COLOR = vec4(final_color, final_alpha);
}
