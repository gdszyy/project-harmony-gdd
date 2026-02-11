shader_type canvas_item;

// 第四章：宫廷乐长·莫扎特 — 洛可可宫廷地面
// 模拟华丽的宫廷地板，涡卷花纹与棋盘格交织

global uniform float global_time;
global uniform float beat_phase;
global uniform vec3 chapter_color;

uniform vec4 primary_color : source_color = vec4(0.9, 0.7, 0.8, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.5, 0.3, 0.5, 1.0);
uniform vec4 accent_color : source_color = vec4(1.0, 0.85, 0.9, 1.0);
uniform float pattern_scale : hint_range(1.0, 10.0) = 6.0;
uniform float fade_alpha : hint_range(0.0, 1.0) = 1.0;
uniform float transition_progress : hint_range(0.0, 1.0) = 0.0;

// 涡卷花纹函数
float scroll_pattern(vec2 uv) {
    float a = atan(uv.y, uv.x);
    float r = length(uv);
    // 对数螺旋
    float spiral = sin(a * 3.0 - log(r + 0.001) * 8.0);
    return smoothstep(0.0, 0.3, spiral) * smoothstep(1.5, 0.0, r);
}

void fragment() {
    vec2 uv = UV * pattern_scale;
    float t = global_time * 0.2;

    // 棋盘格底纹
    vec2 grid = floor(uv);
    float checker = mod(grid.x + grid.y, 2.0);
    vec3 floor_color = mix(secondary_color.rgb * 0.4, secondary_color.rgb * 0.6, checker);

    // 涡卷花纹装饰（在每个格子中心）
    vec2 cell_uv = fract(uv) - 0.5;
    float scroll = scroll_pattern(cell_uv * 2.0);
    floor_color = mix(floor_color, accent_color.rgb * 0.5, scroll * 0.3);

    // 大理石纹理模拟
    float marble = sin(uv.x * 3.0 + sin(uv.y * 2.0 + t) * 2.0) * 0.5 + 0.5;
    marble = smoothstep(0.3, 0.7, marble);
    floor_color = mix(floor_color, primary_color.rgb * 0.4, marble * 0.15);

    // 格子边线（金色镶边）
    vec2 edge = abs(fract(uv) - 0.5);
    float border = smoothstep(0.48, 0.5, max(edge.x, edge.y));
    floor_color = mix(floor_color, accent_color.rgb * 0.3, border);

    // 节拍脉冲：地板微弱发光
    float beat_glow = exp(-beat_phase * 4.0) * 0.2;
    floor_color += accent_color.rgb * beat_glow * (1.0 - checker * 0.5);

    // 章节色调
    floor_color = mix(floor_color, chapter_color, 0.03);

    COLOR = vec4(floor_color, fade_alpha);
}
