shader_type canvas_item;

// 敌人故障 Shader — Glitch Art 视觉效果
// 应用于所有敌人的 Polygon2D / Sprite2D
// 通过 uniform 参数控制故障强度、颜色偏移、扫描线等

// === 控制参数 ===
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float hp_ratio : hint_range(0.0, 1.0) = 1.0;
uniform float beat_energy : hint_range(0.0, 1.0) = 0.0;
uniform float is_stunned : hint_range(0.0, 1.0) = 0.0;
uniform vec4 base_tint : source_color = vec4(1.0, 0.2, 0.3, 1.0);
uniform vec4 glitch_color : source_color = vec4(1.0, 0.0, 0.67, 1.0);

// === 故障效果参数 ===
uniform float scanline_density : hint_range(10.0, 200.0) = 80.0;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.3;
uniform float chromatic_offset : hint_range(0.0, 10.0) = 2.0;
uniform float noise_speed : hint_range(0.0, 10.0) = 3.0;
uniform float pixel_size : hint_range(1.0, 16.0) = 1.0;

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
    float time = TIME * noise_speed;
    float intensity = glitch_intensity;

    // 眩晕时故障加剧
    intensity = max(intensity, is_stunned * 0.6);

    // === 像素化 ===
    float pix = max(1.0, pixel_size * intensity);
    if (pix > 1.5) {
        uv = floor(uv * (1.0 / pix) * 64.0) / 64.0 * pix;
    }

    // === 水平撕裂 (Horizontal Tear) ===
    float tear = 0.0;
    if (intensity > 0.3) {
        float tear_line = step(0.95 - intensity * 0.3, hash(vec2(floor(time * 8.0), floor(uv.y * 20.0))));
        tear = tear_line * intensity * 0.05;
    }
    uv.x += tear;

    // === 色差 (Chromatic Aberration) ===
    float ca_offset = chromatic_offset * intensity / 100.0;
    vec4 color_r = texture(TEXTURE, uv + vec2(ca_offset, 0.0));
    vec4 color_g = texture(TEXTURE, uv);
    vec4 color_b = texture(TEXTURE, uv - vec2(ca_offset, 0.0));
    vec4 color = vec4(color_r.r, color_g.g, color_b.b, color_g.a);

    // 如果没有纹理（纯 Polygon2D），使用顶点颜色
    if (color.a < 0.01) {
        color = COLOR;
        // 对纯色也应用色差偏移效果
        color.r = COLOR.r + ca_offset * 2.0 * sin(time);
        color.b = COLOR.b - ca_offset * 2.0 * cos(time);
    }

    // === 扫描线 ===
    float scanline = sin(FRAGCOORD.y * scanline_density * 0.1) * 0.5 + 0.5;
    scanline = mix(1.0, scanline, scanline_strength * intensity);
    color.rgb *= scanline;

    // === 噪点 (Film Grain) ===
    if (intensity > 0.2) {
        float grain = hash(uv * time * 100.0) * intensity * 0.3;
        color.rgb += vec3(grain);
    }

    // === HP 相关效果 ===
    // 低 HP 时颜色偏向白色（信号崩溃）
    if (hp_ratio < 0.5) {
        float white_blend = (0.5 - hp_ratio) * 1.2;
        color.rgb = mix(color.rgb, vec3(1.0), white_blend * 0.5);
    }

    // === 节拍脉冲 ===
    color.rgb += vec3(beat_energy * 0.15);

    // === 随机闪烁 ===
    if (intensity > 0.6) {
        float flicker = step(0.7, hash(vec2(time * 20.0, 0.0)));
        color.a *= mix(1.0, 0.3, flicker * intensity);
    }

    // === 应用基础色调 ===
    color.rgb *= base_tint.rgb;
    color.rgb = mix(color.rgb, glitch_color.rgb, glitch_intensity * 0.3);

    COLOR = color;
}
