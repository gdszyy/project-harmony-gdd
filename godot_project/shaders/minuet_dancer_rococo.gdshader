shader_type canvas_item;
// 小步舞曲舞者 — 洛可可烛台 Shader (Issue #67)
// 用于烛台几何体的程序化视觉增强
// 实现：金色光泽、火焰辉光、节拍脉冲、狂暴模式

// === 控制参数 ===
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float hp_ratio : hint_range(0.0, 1.0) = 1.0;
uniform float beat_energy : hint_range(0.0, 1.0) = 0.0;
uniform float is_enraged : hint_range(0.0, 1.0) = 0.0;
uniform float is_spinning : hint_range(0.0, 1.0) = 0.0;
uniform vec4 base_tint : source_color = vec4(0.95, 0.88, 0.92, 1.0);

// === 洛可可视觉参数 ===
uniform float gold_shimmer_speed : hint_range(0.0, 10.0) = 2.0;
uniform float gold_shimmer_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float flame_glow_radius : hint_range(0.0, 1.0) = 0.3;
uniform float flame_glow_intensity : hint_range(0.0, 2.0) = 1.0;

// 伪随机噪声
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
    vec2 uv = UV;
    float time = TIME;
    vec4 color = COLOR;

    // === 金色光泽（洛可可风格的微妙闪烁）===
    float shimmer = sin(uv.y * 20.0 + time * gold_shimmer_speed) * 0.5 + 0.5;
    shimmer *= sin(uv.x * 15.0 + time * gold_shimmer_speed * 0.7) * 0.5 + 0.5;
    vec3 gold = vec3(1.0, 0.85, 0.5);
    color.rgb = mix(color.rgb, color.rgb + gold * shimmer * gold_shimmer_intensity, 0.5);

    // === 火焰辉光（顶部区域发光）===
    float flame_dist = distance(uv, vec2(0.5, 0.1)); // 顶部中心
    float flame_glow = smoothstep(flame_glow_radius, 0.0, flame_dist) * flame_glow_intensity;
    // 火焰闪烁
    flame_glow *= 0.8 + sin(time * 8.0) * 0.1 + sin(time * 12.3) * 0.1;
    color.rgb += vec3(1.0, 0.9, 0.5) * flame_glow;

    // === 节拍脉冲 ===
    color.rgb += vec3(beat_energy * 0.2);
    // 节拍时金色边缘增强
    float edge = 1.0 - smoothstep(0.0, 0.15, min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y)));
    color.rgb += gold * edge * beat_energy * 0.5;

    // === 狂暴模式 ===
    if (is_enraged > 0.5) {
        // 红色脉冲
        float rage_pulse = sin(time * 6.0) * 0.3 + 0.7;
        color.rgb = mix(color.rgb, vec3(1.0, 0.2, 0.1), is_enraged * 0.4 * rage_pulse);
        // 火焰变红
        color.rgb += vec3(0.3, 0.0, 0.0) * flame_glow * is_enraged;
    }

    // === 旋转模式（旋风过渡）===
    if (is_spinning > 0.5) {
        // 溶解效果
        float dissolve = hash(uv * 50.0 + vec2(time * 5.0));
        if (dissolve > 1.0 - is_spinning * 0.8) {
            color.a *= 0.3;
        }
        // 发光增强
        color.rgb += vec3(1.0, 0.95, 0.7) * is_spinning * 0.3;
    }

    // === 故障效果（低强度，保持优雅感）===
    if (glitch_intensity > 0.2) {
        // 轻微扫描线
        float scanline = sin(FRAGCOORD.y * 60.0) * 0.5 + 0.5;
        color.rgb *= mix(1.0, scanline, glitch_intensity * 0.2);
        // 轻微色差
        float ca = glitch_intensity * 0.01;
        color.r += sin(uv.x * 100.0 + time * 3.0) * ca;
        color.b -= sin(uv.x * 100.0 + time * 3.0) * ca;
    }

    // === HP 相关效果 ===
    if (hp_ratio < 0.3) {
        // 低 HP 时金色褪色
        float fade = (0.3 - hp_ratio) / 0.3;
        color.rgb = mix(color.rgb, vec3(0.5), fade * 0.4);
        // 闪烁
        color.a *= 0.7 + sin(time * 10.0) * 0.3;
    }

    // 应用基础色调
    color.rgb *= base_tint.rgb;
    COLOR = color;
}
