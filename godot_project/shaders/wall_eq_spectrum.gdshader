// wall_eq_spectrum.gdshader
// 结合了 EQ 频谱可视化的墙体 Shader
// 在基础的 enemy_glitch 效果之上，增加了根据音频频谱数据变化的动态发光效果。
shader_type canvas_item;

// 基础故障效果参数 (来自 enemy_glitch.gdshader)
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float hp_ratio : hint_range(0.0, 1.0) = 1.0;
uniform float beat_energy : hint_range(0.0, 1.0) = 0.0;
uniform float is_stunned : hint_range(0.0, 1.0) = 0.0;
uniform vec4 base_tint : source_color = vec4(1.0, 0.2, 0.3, 1.0);
uniform vec4 glitch_color : source_color = vec4(1.0, 0.0, 0.67, 1.0);
uniform float chromatic_offset : hint_range(0.0, 10.0) = 2.0;
uniform float pixel_size : hint_range(1.0, 16.0) = 1.0;

// EQ 频谱专属参数
// 使用 sampler2D 接收频谱数据，比用16个float更高效
uniform sampler2D spectrum_texture; // 16x1 纹理，每个像素代表一个频段的能量
uniform float spectrum_strength : hint_range(0.0, 5.0) = 1.5;
uniform vec4 eq_color : source_color = vec4(1.0, 0.5, 0.0, 1.0);

// 伪随机噪声函数 (来自 enemy_glitch.gdshader)
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
    vec2 uv = UV;
    float time = TIME;
    float intensity = glitch_intensity;

    // 基础故障效果 (简化版 enemy_glitch)
    // 像素化
    float pix = max(1.0, pixel_size * intensity);
    if (pix > 1.5) {
        uv = floor(uv * (1.0 / pix) * 64.0) / 64.0 * pix;
    }

    // 色差
    float ca_offset = chromatic_offset * intensity / 100.0;
    vec4 base_color = texture(TEXTURE, uv);
    if (base_color.a < 0.01) { // 对于 Polygon2D，使用顶点颜色
        base_color = COLOR;
    }
    vec4 color_r = texture(TEXTURE, uv + vec2(ca_offset, 0.0));
    vec4 color_b = texture(TEXTURE, uv - vec2(ca_offset, 0.0));
    vec4 final_color = vec4(color_r.r, base_color.g, color_b.b, base_color.a);
    if (final_color.a < 0.01) { // 再次检查，确保纯色也能应用色差
        final_color = vec4(base_color.r + ca_offset, base_color.g, base_color.b - ca_offset, base_color.a);
    }

    // EQ 频谱可视化
    // 将 UV.x 映射到频谱纹理的采样坐标
    float spectrum_val = texture(spectrum_texture, vec2(uv.x, 0.5)).r;
    
    // 根据频谱值和 UV.y 创建条形图效果
    // 当 uv.y 在频谱值以下时，显示发光颜色
    float eq_mask = smoothstep(0.0, 0.05, (1.0 - uv.y) - spectrum_val * spectrum_strength);
    vec3 emission = eq_color.rgb * eq_mask * (spectrum_val + 0.1); // 频谱越强，光越亮

    // 组合颜色
    final_color.rgb *= base_tint.rgb; // 应用基础色调
    color.rgb = mix(color.rgb, glitch_color.rgb, glitch_intensity * 0.3);
    final_color.rgb += emission; // 叠加 EQ 发光效果

    // 节拍脉冲
    final_color.rgb += vec3(beat_energy * 0.15);

    // HP 越低越亮
    if (hp_ratio < 0.5) {
        float white_blend = (0.5 - hp_ratio) * 1.2;
        final_color.rgb = mix(final_color.rgb, vec3(1.0), white_blend * 0.5);
    }

    COLOR = final_color;
}
