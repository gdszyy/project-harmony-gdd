shader_type canvas_item;

// 第二章：圣咏宗师·圭多 — 教堂玫瑰窗地面
// 模拟哥特式教堂的彩色玻璃窗投影

global uniform float global_time;
global uniform float beat_phase;
global uniform vec3 chapter_color;

uniform vec4 primary_color : source_color = vec4(0.2, 0.1, 0.4, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.6, 0.3, 0.8, 1.0);
uniform vec4 accent_color : source_color = vec4(0.9, 0.7, 1.0, 1.0);
uniform float pattern_scale : hint_range(1.0, 10.0) = 4.0;
uniform float fade_alpha : hint_range(0.0, 1.0) = 1.0;
uniform float transition_progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec2 uv = (UV - 0.5) * pattern_scale;
    float t = global_time * 0.3;

    // 极坐标
    float r = length(uv);
    float a = atan(uv.y, uv.x);

    // 玫瑰窗的径向对称图案
    float petals = 8.0;
    float petal = abs(sin(a * petals + t));
    float ring = abs(sin(r * 6.0 - t * 0.5));

    // 组合图案
    float pattern = petal * ring;
    pattern = smoothstep(0.3, 0.7, pattern);

    // 彩色玻璃效果：不同区域不同颜色
    vec3 color1 = primary_color.rgb;
    vec3 color2 = secondary_color.rgb;
    vec3 color3 = accent_color.rgb;

    float sector = fract(a / 6.28318 * petals);
    vec3 glass_color = mix(color1, color2, sector);
    glass_color = mix(glass_color, color3, pattern * 0.5);

    // 铅条（分隔线）
    float lead = smoothstep(0.02, 0.0, abs(sin(a * petals)));
    lead += smoothstep(0.02, 0.0, abs(sin(r * 6.0)));
    lead = clamp(lead, 0.0, 1.0);

    vec3 final_color = mix(glass_color * 0.3, vec3(0.01), lead);

    // 节拍时光线增强
    float beat_light = exp(-beat_phase * 4.0) * 0.3;
    final_color += glass_color * beat_light * pattern;

    COLOR = vec4(final_color, fade_alpha);
}
