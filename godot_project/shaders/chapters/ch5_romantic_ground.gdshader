shader_type canvas_item;

// 第五章：风暴指挥·贝多芬 — 浪漫主义风暴地面
// 模拟狂风暴雨中的大地，闪电照亮的荒野

global uniform float global_time;
global uniform float beat_phase;
global uniform vec3 chapter_color;

uniform vec4 primary_color : source_color = vec4(0.15, 0.1, 0.3, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.5, 0.1, 0.2, 1.0);
uniform vec4 accent_color : source_color = vec4(0.8, 0.3, 0.4, 1.0);
uniform float pattern_scale : hint_range(1.0, 10.0) = 4.0;
uniform float storm_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float fade_alpha : hint_range(0.0, 1.0) = 1.0;
uniform float transition_progress : hint_range(0.0, 1.0) = 0.0;

// 简化噪声
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

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

void fragment() {
    vec2 uv = UV * pattern_scale;
    float t = global_time;

    // 风暴云层投影
    vec2 wind_uv = uv + vec2(t * 0.3, t * 0.1);
    float cloud_shadow = fbm(wind_uv * 1.5);
    cloud_shadow = smoothstep(0.3, 0.7, cloud_shadow);

    // 地面基础色
    float ground_noise = fbm(uv * 3.0 + vec2(0.0, t * 0.05));
    vec3 ground = mix(primary_color.rgb * 0.3, primary_color.rgb * 0.5, ground_noise);

    // 云影投射
    ground *= mix(1.0, 0.4, cloud_shadow * storm_intensity);

    // 雨水涟漪
    float ripple = 0.0;
    for (int i = 0; i < 5; i++) {
        vec2 ripple_center = vec2(hash(vec2(float(i), floor(t * 2.0))),
                                   hash(vec2(float(i) + 10.0, floor(t * 2.0))));
        ripple_center = ripple_center * pattern_scale;
        float d = length(uv - ripple_center);
        float ripple_t = fract(t * 2.0 + float(i) * 0.2);
        ripple += smoothstep(0.3, 0.0, abs(d - ripple_t * 0.5)) * (1.0 - ripple_t);
    }
    ground += accent_color.rgb * ripple * 0.2 * storm_intensity;

    // 闪电照亮效果（节拍同步）
    float lightning = exp(-beat_phase * 2.0);
    float flash = lightning * step(0.95, hash(vec2(floor(t * 4.0), 0.0)));
    ground += vec3(0.8, 0.7, 1.0) * flash * 0.5;

    // 常规节拍脉冲
    float beat_glow = exp(-beat_phase * 4.0) * 0.15;
    ground += secondary_color.rgb * beat_glow;

    // 章节色调
    ground = mix(ground, chapter_color, 0.03);

    COLOR = vec4(ground, fade_alpha);
}
