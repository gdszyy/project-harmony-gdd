shader_type canvas_item;

// 第六章：即兴宗师·帕克 — 爵士俱乐部地面
// 模拟昏暗的爵士酒吧，聚光灯与烟雾弥漫

global uniform float global_time;
global uniform float beat_phase;
global uniform vec3 chapter_color;

uniform vec4 primary_color : source_color = vec4(0.1, 0.05, 0.15, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.8, 0.5, 0.1, 1.0);
uniform vec4 accent_color : source_color = vec4(0.0, 0.8, 1.0, 1.0);
uniform float pattern_scale : hint_range(1.0, 10.0) = 3.0;
uniform bool swing_mode = false;
uniform float fade_alpha : hint_range(0.0, 1.0) = 1.0;
uniform float transition_progress : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
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
    vec2 uv = (UV - 0.5) * pattern_scale;
    float t = global_time;

    // 深色木地板
    float wood_grain = sin(uv.x * 20.0 + noise(uv * 5.0) * 3.0) * 0.5 + 0.5;
    wood_grain = smoothstep(0.3, 0.7, wood_grain);
    vec3 floor_color = mix(primary_color.rgb * 0.5, primary_color.rgb * 0.8, wood_grain * 0.3);

    // 木板缝隙
    float plank = smoothstep(0.01, 0.0, abs(fract(uv.x * 3.0) - 0.5) - 0.48);
    floor_color = mix(floor_color, vec3(0.01), plank * 0.5);

    // 聚光灯效果（中心偏移，缓慢移动）
    vec2 spot_center = vec2(sin(t * 0.2) * 0.3, cos(t * 0.15) * 0.2);
    float spot_dist = length(uv - spot_center);
    float spotlight = smoothstep(1.5, 0.0, spot_dist);
    spotlight = spotlight * spotlight;  // 更集中的光锥
    floor_color += secondary_color.rgb * spotlight * 0.4;

    // 第二个聚光灯（较弱）
    vec2 spot2_center = vec2(cos(t * 0.18) * 0.5, sin(t * 0.22) * 0.3);
    float spot2_dist = length(uv - spot2_center);
    float spotlight2 = smoothstep(1.2, 0.0, spot2_dist);
    floor_color += accent_color.rgb * spotlight2 * spotlight2 * 0.15;

    // 烟雾效果（缓慢飘动的噪声）
    float smoke = noise(uv * 2.0 + vec2(t * 0.1, t * 0.05));
    smoke = smoothstep(0.3, 0.7, smoke) * 0.08;
    floor_color += vec3(smoke);

    // 摇摆模式：聚光灯更强烈，颜色更暖
    if (swing_mode) {
        float swing_pulse = sin(t * 3.0) * 0.5 + 0.5;
        floor_color += secondary_color.rgb * spotlight * swing_pulse * 0.2;
    }

    // 节拍脉冲：聚光灯闪烁
    float beat_glow = exp(-beat_phase * 3.0) * 0.3;
    floor_color += secondary_color.rgb * beat_glow * spotlight;

    // 章节色调
    floor_color = mix(floor_color, chapter_color, 0.02);

    COLOR = vec4(floor_color, fade_alpha);
}
