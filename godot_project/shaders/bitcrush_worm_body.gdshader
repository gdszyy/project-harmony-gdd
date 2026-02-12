shader_type canvas_item;

// 比特破碎虫 (Bit-Crushing Worm) 身体段着色器
// Issue #70: 多分辨率块着色器
// 在方块表面程序化生成像素网格图案，分辨率可控
// 使用噪声函数产生混沌、损坏的视觉效果

uniform float resolution : hint_range(2.0, 32.0) = 8.0;
uniform float corruption : hint_range(0.0, 1.0) = 0.0;
uniform float time_scale : hint_range(0.1, 5.0) = 1.0;
uniform vec4 base_color : source_color = vec4(0.0, 0.8, 0.5, 1.0);
uniform vec4 corrupt_color : source_color = vec4(1.0, 0.0, 0.5, 1.0);
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float beat_energy : hint_range(0.0, 1.0) = 0.0;

// 伪随机噪声
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// 2D 值噪声
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f); // smoothstep

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
    vec2 uv = UV;
    float t = TIME * time_scale;

    // 像素化：使用 floor() 创建块状外观
    vec2 pixel_uv = floor(uv * resolution) / resolution;

    // 每个"像素块"的唯一标识
    vec2 block_id = floor(uv * resolution);

    // 故障偏移：高损坏度时 UV 随机跳跃
    if (corruption > 0.0) {
        float glitch_chance = hash(block_id + vec2(floor(t * 8.0)));
        if (glitch_chance < corruption * 0.4) {
            pixel_uv.x += (hash(block_id + t) - 0.5) * corruption * 0.15;
        }
        // 行偏移故障
        float row_glitch = hash(vec2(block_id.y, floor(t * 3.0)));
        if (row_glitch < corruption * 0.2) {
            pixel_uv.x += (row_glitch - 0.5) * 0.3;
        }
    }

    // 基于噪声的块颜色变化
    float block_noise = noise(block_id * 0.5 + vec2(t * 0.3));
    float block_brightness = 0.4 + block_noise * 0.6;

    // 损坏区域使用不同颜色
    float corrupt_mask = noise(block_id * 0.3 + vec2(t * 0.5, t * 0.2));
    corrupt_mask = smoothstep(1.0 - corruption, 1.0, corrupt_mask);

    vec3 color = mix(
        base_color.rgb * block_brightness,
        corrupt_color.rgb * block_brightness,
        corrupt_mask
    );

    // 块边缘高亮（网格线效果）
    vec2 cell_uv = fract(uv * resolution);
    float edge = 1.0 - smoothstep(0.0, 0.08, min(cell_uv.x, cell_uv.y));
    edge += 1.0 - smoothstep(0.92, 1.0, max(cell_uv.x, cell_uv.y));
    color += vec3(edge * 0.15);

    // 扫描线
    if (scanline_intensity > 0.0) {
        float scanline = sin(UV.y * resolution * 6.28318) * 0.5 + 0.5;
        color *= 1.0 - scanline * scanline_intensity * 0.3;
    }

    // 故障闪烁
    if (glitch_intensity > 0.0) {
        float flicker = hash(vec2(floor(t * 15.0), block_id.y));
        if (flicker < glitch_intensity * 0.3) {
            color = vec3(1.0) - color; // 颜色反转
        }
    }

    // 节拍脉冲发光
    color += base_color.rgb * beat_energy * 0.4;

    // 整体亮度随损坏度降低
    color *= 1.0 - corruption * 0.2;

    // Alpha：块状透明度变化
    float alpha = base_color.a;
    if (corruption > 0.5) {
        float dissolve = hash(block_id + vec2(floor(t * 2.0)));
        if (dissolve < (corruption - 0.5) * 0.4) {
            alpha *= 0.3;
        }
    }

    COLOR = vec4(color, alpha);
}
