shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// === 疲劳等级 (0=正常, 1=严重) ===
uniform float fatigue_level : hint_range(0.0, 1.0) = 0.0;

// === 不和谐度 (额外的视觉干扰) ===
uniform float dissonance_level : hint_range(0.0, 1.0) = 0.0;

// === 节拍脉冲 (用于边缘闪烁) ===
uniform float beat_pulse : hint_range(0.0, 1.0) = 0.0;

// === 密度过载强度 (0=正常, 1=严重过载) ===
uniform float density_overload : hint_range(0.0, 1.0) = 0.0;

// === 疲劳等级指示 (0=无, 1=低, 2=中, 3=高) ===
uniform int fatigue_tier : hint_range(0, 3) = 0;

void fragment() {
    vec2 uv = SCREEN_UV;

    // ================================================================
    // 三级疲劳视觉效果体系
    // Tier 0 (AFI < 0.3): 正常画面，无任何效果
    // Tier 1 (AFI 0.3-0.5): 低疲劳 — 轻微暖色调偏移 + 微弱暗角
    // Tier 2 (AFI 0.5-0.8): 中疲劳 — 色差 + 噪点 + 扫描线
    // Tier 3 (AFI > 0.8): 高疲劳 — 去饱和 + 故障 + 强烈暗角
    // ================================================================

    // === 1. 色差 (Chromatic Aberration) — Tier 2+ ===
    float fatigue_aberration = 0.0;
    if (fatigue_level > 0.3) {
        fatigue_aberration = (fatigue_level - 0.3) * 0.007;
    }
    float dissonance_aberration = 0.0;
    if (dissonance_level > 0.2) {
        dissonance_aberration = (dissonance_level - 0.2) * 0.004;
    }
    // 密度过载额外色差（红色偏移）
    float overload_aberration = density_overload * 0.005;
    float aberration_amount = fatigue_aberration + dissonance_aberration + overload_aberration;

    vec4 final_color;
    if (aberration_amount > 0.0001) {
        vec4 r_col = texture(screen_texture, uv - vec2(aberration_amount, 0.0));
        vec4 g_col = texture(screen_texture, uv);
        vec4 b_col = texture(screen_texture, uv + vec2(aberration_amount, 0.0));
        final_color = vec4(r_col.r, g_col.g, b_col.b, 1.0);
    } else {
        final_color = texture(screen_texture, uv);
    }

    // === 2. Tier 1: 暖色调偏移 + 微弱暗角 ===
    if (fatigue_tier >= 1 && fatigue_level > 0.2) {
        // 轻微暖色偏移（疲劳感的初始信号）
        float warm_strength = smoothstep(0.2, 0.5, fatigue_level) * 0.08;
        final_color.r += warm_strength;
        final_color.g -= warm_strength * 0.3;
        final_color.b -= warm_strength * 0.5;

        // 微弱暗角
        float edge_dist_t1 = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
        float vignette_t1 = smoothstep(0.0, 0.4, edge_dist_t1);
        final_color.rgb *= mix(0.92, 1.0, vignette_t1);
    }

    // === 3. Tier 2: 胶片噪点 + 扫描线 ===
    if (fatigue_tier >= 2 && fatigue_level > 0.3) {
        // 胶片噪点
        float grain_strength = (fatigue_level - 0.3) * 0.3;
        float grain = fract(sin(dot(uv * TIME, vec2(12.9898, 78.233))) * 43758.5453);
        final_color.rgb += (grain - 0.5) * grain_strength;
    }

    if (fatigue_tier >= 2 && fatigue_level > 0.5) {
        // 扫描线
        float scanline_intensity = (fatigue_level - 0.5) * 0.4;
        float scanline = sin(uv.y * 800.0 + TIME * 2.0) * scanline_intensity;
        final_color.rgb -= scanline;

        // 水平故障偏移
        float glitch_offset = sin(TIME * 15.0 + uv.y * 100.0) * fatigue_level * 0.003;
        if (fract(sin(TIME * 7.0) * 43758.5453) > 0.95) {
            final_color.rgb = texture(screen_texture, uv + vec2(glitch_offset, 0.0)).rgb;
        }
    }

    // === 4. Tier 3: 去饱和 + 强烈暗角 + 脉冲警告 ===
    if (fatigue_tier >= 3 && fatigue_level > 0.8) {
        // 去饱和（保留红色作为警告色）
        float desat_strength = (fatigue_level - 0.8) * 5.0;
        float gray = dot(final_color.rgb, vec3(0.299, 0.587, 0.114));
        float redness = final_color.r - (final_color.g + final_color.b) * 0.5;
        if (redness < 0.2) {
            final_color.rgb = mix(final_color.rgb, vec3(gray), desat_strength);
        }

        // 强烈暗角（红色警告边框）
        float edge_dist_t3 = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
        float vignette_t3 = smoothstep(0.0, 0.2, edge_dist_t3);
        float pulse = sin(TIME * 3.0) * 0.5 + 0.5;
        vec3 danger_color = vec3(0.6, 0.0, 0.0) * (1.0 - vignette_t3) * (0.3 + pulse * 0.2);
        final_color.rgb += danger_color;
    }

    // === 5. 密度过载专属效果 — 红色边缘闪烁 + 画面抖动 ===
    if (density_overload > 0.01) {
        // 红色边缘脉冲
        float edge_dist_ol = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
        float vignette_ol = smoothstep(0.0, 0.25, edge_dist_ol);
        float overload_pulse = sin(TIME * 6.0) * 0.5 + 0.5;
        vec3 overload_tint = vec3(1.0, 0.2, 0.0) * (1.0 - vignette_ol) * density_overload * (0.2 + overload_pulse * 0.15);
        final_color.rgb += overload_tint;

        // 画面微抖（高密度过载时）
        if (density_overload > 0.5) {
            float shake = sin(TIME * 30.0) * density_overload * 0.002;
            vec4 shake_color = texture(screen_texture, uv + vec2(shake, 0.0));
            final_color.rgb = mix(final_color.rgb, shake_color.rgb, density_overload * 0.3);
        }
    }

    // === 6. 不和谐度视觉效果 — 紫色边缘 ===
    if (dissonance_level > 0.2) {
        float edge_dist = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
        float vignette = smoothstep(0.0, 0.3, edge_dist);
        vec3 dissonance_tint = vec3(0.4, 0.0, 0.6) * (1.0 - vignette) * dissonance_level;
        final_color.rgb += dissonance_tint;
    }

    // === 7. 节拍边缘闪烁 ===
    float edge_dist = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
    float beat_vignette = smoothstep(0.0, 0.15, edge_dist);
    vec3 beat_glow = vec3(0.0, 0.8, 0.6) * (1.0 - beat_vignette) * beat_pulse * 0.3;
    final_color.rgb += beat_glow;

    COLOR = final_color;
}
