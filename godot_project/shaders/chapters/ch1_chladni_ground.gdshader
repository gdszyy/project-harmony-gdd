shader_type canvas_item;

// 第一章：律动尊者·毕达哥拉斯 — 克拉尼图形地面
// 模拟金属板上的振动模式，沙粒聚集在节线上

global uniform float global_time;
global uniform float beat_phase;
global uniform vec3 chapter_color;

uniform vec4 primary_color : source_color = vec4(0.9, 0.85, 0.6, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.3, 0.25, 0.15, 1.0);
uniform float pattern_scale : hint_range(1.0, 20.0) = 8.0;
uniform float line_width : hint_range(0.01, 0.1) = 0.03;
uniform float animation_speed : hint_range(0.1, 2.0) = 0.5;
uniform float fade_alpha : hint_range(0.0, 1.0) = 1.0;
uniform float transition_progress : hint_range(0.0, 1.0) = 0.0;

// 克拉尼图形函数：矩形板的振动模式
float chladni(vec2 uv, float m, float n) {
    return cos(m * 3.14159 * uv.x) * cos(n * 3.14159 * uv.y)
         - cos(n * 3.14159 * uv.x) * cos(m * 3.14159 * uv.y);
}

void fragment() {
    vec2 uv = UV * pattern_scale;
    float t = global_time * animation_speed;

    // 混合多个振动模式
    float mode1 = chladni(uv, 3.0, 2.0 + sin(t * 0.3) * 0.5);
    float mode2 = chladni(uv, 5.0, 3.0 + cos(t * 0.2) * 0.5);
    float pattern = mix(mode1, mode2, sin(t * 0.1) * 0.5 + 0.5);

    // 节线检测（沙粒聚集的位置）
    float line = smoothstep(line_width, 0.0, abs(pattern));

    // 节拍脉冲：节线在节拍时刻发光
    float beat_glow = exp(-beat_phase * 3.0) * 0.5;
    line += beat_glow * smoothstep(line_width * 2.0, 0.0, abs(pattern));

    // 混合颜色
    vec3 bg = secondary_color.rgb;
    vec3 fg = primary_color.rgb;
    vec3 final_color = mix(bg, fg, line);

    // 添加微弱的章节色调
    final_color = mix(final_color, chapter_color, 0.05);

    COLOR = vec4(final_color, fade_alpha);
}
