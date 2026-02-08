shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// === 疲劳等级 (0=正常, 1=严重) ===
uniform float fatigue_level : hint_range(0.0, 1.0) = 0.0;

// === 不和谐度 (额外的视觉干扰) ===
uniform float dissonance_level : hint_range(0.0, 1.0) = 0.0;

// === 节拍脉冲 (用于边缘闪烁) ===
uniform float beat_pulse : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec2 uv = SCREEN_UV;

    // === 1. 色差 (Chromatic Aberration) — 仅在中高疲劳时出现 ===
    // 修复：添加阈值保护，疲劳度 > 0.3 时才开始出现色差
    // 修复：降低色差系数，避免画面严重失真
    float fatigue_aberration = 0.0;
    if (fatigue_level > 0.3) {
        fatigue_aberration = (fatigue_level - 0.3) * 0.007;
    }
    float dissonance_aberration = 0.0;
    if (dissonance_level > 0.2) {
        dissonance_aberration = (dissonance_level - 0.2) * 0.004;
    }
    float aberration_amount = fatigue_aberration + dissonance_aberration;

    vec4 final_color;
    if (aberration_amount > 0.0001) {
        vec4 r_col = texture(screen_texture, uv - vec2(aberration_amount, 0.0));
        vec4 g_col = texture(screen_texture, uv);
        vec4 b_col = texture(screen_texture, uv + vec2(aberration_amount, 0.0));
        final_color = vec4(r_col.r, g_col.g, b_col.b, 1.0);
    } else {
        final_color = texture(screen_texture, uv);
    }

    // === 2. 胶片噪点 (Film Grain) — 中等疲劳时出现 ===
    if (fatigue_level > 0.3) {
        float grain_strength = (fatigue_level - 0.3) * 0.3;
        float grain = fract(sin(dot(uv * TIME, vec2(12.9898, 78.233))) * 43758.5453);
        final_color.rgb += (grain - 0.5) * grain_strength;
    }

    // === 3. 扫描线 (Scanlines) — 高疲劳时出现 ===
    if (fatigue_level > 0.5) {
        float scanline_intensity = (fatigue_level - 0.5) * 0.4;
        float scanline = sin(uv.y * 800.0 + TIME * 2.0) * scanline_intensity;
        final_color.rgb -= scanline;

        // 水平故障偏移
        float glitch_offset = sin(TIME * 15.0 + uv.y * 100.0) * fatigue_level * 0.003;
        if (fract(sin(TIME * 7.0) * 43758.5453) > 0.95) {
            final_color.rgb = texture(screen_texture, uv + vec2(glitch_offset, 0.0)).rgb;
        }
    }

    // === 4. 饱和度抽离 (Desaturation) — 濒死感 ===
    if (fatigue_level > 0.8) {
        float desat_strength = (fatigue_level - 0.8) * 5.0;
        float gray = dot(final_color.rgb, vec3(0.299, 0.587, 0.114));
        // 保留红色作为警告色
        float redness = final_color.r - (final_color.g + final_color.b) * 0.5;
        if (redness < 0.2) {
            final_color.rgb = mix(final_color.rgb, vec3(gray), desat_strength);
        }
    }

    // === 5. 不和谐度视觉效果 — 紫色边缘 ===
    if (dissonance_level > 0.2) {
        float edge_dist = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
        float vignette = smoothstep(0.0, 0.3, edge_dist);
        vec3 dissonance_tint = vec3(0.4, 0.0, 0.6) * (1.0 - vignette) * dissonance_level;
        final_color.rgb += dissonance_tint;
    }

    // === 6. 节拍边缘闪烁 ===
    float edge_dist = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
    float beat_vignette = smoothstep(0.0, 0.15, edge_dist);
    vec3 beat_glow = vec3(0.0, 0.8, 0.6) * (1.0 - beat_vignette) * beat_pulse * 0.3;
    final_color.rgb += beat_glow;

    COLOR = final_color;
}
