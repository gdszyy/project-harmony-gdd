shader_type canvas_item;

// 第三章：大构建师·巴赫 — 巴洛克齿轮地面
// 模拟精密的机械宇宙，齿轮与赋格交织

global uniform float global_time;
global uniform float beat_phase;
global uniform vec3 chapter_color;

uniform vec4 primary_color : source_color = vec4(0.7, 0.5, 0.2, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.3, 0.2, 0.1, 1.0);
uniform vec4 accent_color : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform float pattern_scale : hint_range(1.0, 10.0) = 5.0;
uniform float rotation_speed : hint_range(0.1, 2.0) = 0.3;
uniform float fade_alpha : hint_range(0.0, 1.0) = 1.0;
uniform float transition_progress : hint_range(0.0, 1.0) = 0.0;

// 齿轮形状函数
float gear(vec2 uv, float teeth, float inner_r, float outer_r) {
    float a = atan(uv.y, uv.x);
    float r = length(uv);
    float tooth = smoothstep(0.0, 0.05, sin(a * teeth) * 0.5 + 0.5);
    float gear_r = mix(inner_r, outer_r, tooth);
    return smoothstep(gear_r + 0.02, gear_r, r) * smoothstep(inner_r * 0.3, inner_r * 0.35, r);
}

void fragment() {
    vec2 uv = (UV - 0.5) * pattern_scale;
    float t = global_time * rotation_speed;

    // 多个齿轮层
    vec3 final_color = secondary_color.rgb * 0.3;

    // 大齿轮（缓慢旋转）
    vec2 uv1 = uv;
    float c1 = cos(t * 0.5);
    float s1 = sin(t * 0.5);
    uv1 = vec2(uv1.x * c1 - uv1.y * s1, uv1.x * s1 + uv1.y * c1);
    float g1 = gear(uv1, 12.0, 0.8, 1.0);
    final_color = mix(final_color, primary_color.rgb * 0.5, g1 * 0.6);

    // 中齿轮（反向旋转）
    vec2 uv2 = uv - vec2(0.6, 0.3);
    float c2 = cos(-t * 0.8);
    float s2 = sin(-t * 0.8);
    uv2 = vec2(uv2.x * c2 - uv2.y * s2, uv2.x * s2 + uv2.y * c2);
    float g2 = gear(uv2, 8.0, 0.4, 0.55);
    final_color = mix(final_color, primary_color.rgb * 0.6, g2 * 0.5);

    // 小齿轮（快速旋转）
    vec2 uv3 = uv + vec2(0.5, -0.4);
    float c3 = cos(t * 1.2);
    float s3 = sin(t * 1.2);
    uv3 = vec2(uv3.x * c3 - uv3.y * s3, uv3.x * s3 + uv3.y * c3);
    float g3 = gear(uv3, 6.0, 0.25, 0.35);
    final_color = mix(final_color, accent_color.rgb * 0.4, g3 * 0.5);

    // 五线谱线条（水平）
    float staff_line = smoothstep(0.02, 0.0, abs(fract(uv.y * 2.0) - 0.5));
    final_color += primary_color.rgb * staff_line * 0.1;

    // 节拍脉冲：齿轮边缘发光
    float beat_glow = exp(-beat_phase * 3.0) * 0.4;
    final_color += accent_color.rgb * beat_glow * max(g1, max(g2, g3));

    // 章节色调
    final_color = mix(final_color, chapter_color, 0.03);

    COLOR = vec4(final_color, fade_alpha);
}
