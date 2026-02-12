shader_type canvas_item;

// Pulse 敌人 LED 倒计时 Shader
// 继承自 enemy_glitch，并添加了基于 UV 的分面点亮效果

// === 基础故障效果参数 (从 enemy_glitch 继承) ===
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float hp_ratio : hint_range(0.0, 1.0) = 1.0;
uniform float beat_energy : hint_range(0.0, 1.0) = 0.0;
uniform float is_stunned : hint_range(0.0, 1.0) = 0.0;
uniform vec4 base_tint : source_color = vec4(0.2, 0.6, 1.0, 1.0);
uniform vec4 glitch_color : source_color = vec4(1.0, 0.0, 0.67, 1.0);

// === 故障效果细节参数 (从 enemy_glitch 继承) ===
uniform float scanline_density : hint_range(10.0, 200.0) = 80.0;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.3;
uniform float chromatic_offset : hint_range(0.0, 10.0) = 2.0;
uniform float noise_speed : hint_range(0.0, 10.0) = 3.0;
uniform float pixel_size : hint_range(1.0, 16.0) = 1.0;

// === Pulse 专属参数 ===
uniform float countdown_progress : hint_range(0.0, 1.0) = 0.0; // 蓄力进度 (0.0 到 1.0)
uniform int face_count = 8; // 几何体的面数

// 伪随机噪声 (从 enemy_glitch 继承)
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
    vec2 uv = UV;
    float time = TIME * noise_speed;
    float intensity = glitch_intensity;

    // 眩晕时故障加剧
    intensity = max(intensity, is_stunned * 0.6);

    // === 基础故障效果 (从 enemy_glitch 复制) ===
    // 像素化
    float pix = max(1.0, pixel_size * intensity);
    if (pix > 1.5) {
        uv = floor(uv * (1.0 / pix) * 64.0) / 64.0 * pix;
    }
    // 水平撕裂
    float tear = 0.0;
    if (intensity > 0.3) {
        float tear_line = step(0.95 - intensity * 0.3, hash(vec2(floor(time * 8.0), floor(uv.y * 20.0))));
        tear = tear_line * intensity * 0.05;
    }
    uv.x += tear;

    // 色差
    float ca_offset = chromatic_offset * intensity / 100.0;
    vec4 color_r = texture(TEXTURE, uv + vec2(ca_offset, 0.0));
    vec4 color_g = texture(TEXTURE, uv);
    vec4 color_b = texture(TEXTURE, uv - vec2(ca_offset, 0.0));
    vec4 color = vec4(color_r.r, color_g.g, color_b.b, color_g.a);

    if (color.a < 0.01) {
        color = COLOR;
    }

    // === Pulse LED 倒计时效果 ===
    vec2 centered_uv = UV - vec2(0.5);
    float angle = atan(centered_uv.y, centered_uv.x);
    float segment_angle = TAU / float(face_count);
    
    // 将角度映射到 [0, face_count) 的面索引
    float face_index = floor(mod((angle + segment_angle / 2.0) / TAU * float(face_count), float(face_count)));

    // 计算当前应该点亮到哪个面
    float lit_faces = floor(countdown_progress * float(face_count + 1));

    float emission = 0.0;
    if (face_index < lit_faces) {
        emission = 0.4; // 点亮面的基础亮度
        // 最后一个点亮的面更亮，有呼吸效果
        if (face_index >= lit_faces - 1.0) {
            emission += (sin(TIME * 20.0) * 0.5 + 0.5) * 0.3;
        }
    }

    // 蓄力快完成时，所有面一起闪烁
    if (countdown_progress > 0.95) {
        float blink = step(0.5, sin(TIME * 40.0) * 0.5 + 0.5);
        emission += blink * 0.5;
    }
    
    color.rgb += vec3(emission);

    // === 后处理故障效果 (从 enemy_glitch 复制) ===
    // 扫描线
    float scanline = sin(FRAGCOORD.y * scanline_density * 0.1) * 0.5 + 0.5;
    scanline = mix(1.0, scanline, scanline_strength * intensity);
    color.rgb *= scanline;

    // 噪点
    if (intensity > 0.2) {
        float grain = hash(uv * time * 100.0) * intensity * 0.3;
        color.rgb += vec3(grain);
    }

    // 低 HP 效果
    if (hp_ratio < 0.5) {
        float white_blend = (0.5 - hp_ratio) * 1.2;
        color.rgb = mix(color.rgb, vec3(1.0), white_blend * 0.5);
    }

    // 节拍脉冲
    color.rgb += vec3(beat_energy * 0.15);

    // 应用基础色调
    color.rgb *= base_tint.rgb;
    color.rgb = mix(color.rgb, glitch_color.rgb, glitch_intensity * 0.3);

    COLOR = color;
}
