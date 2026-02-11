shader_type canvas_item;

// 第七章：合成主脑·噪音 — 数字矩阵地面
// 模拟数据流、二进制代码和数字损坏

global uniform float global_time;
global uniform float beat_phase;
global uniform vec3 chapter_color;

uniform vec4 primary_color : source_color = vec4(0.0, 1.0, 0.3, 1.0);
uniform vec4 secondary_color : source_color = vec4(1.0, 0.0, 0.5, 1.0);
uniform float grid_size : hint_range(4.0, 32.0) = 16.0;
uniform float scroll_speed : hint_range(0.1, 5.0) = 1.0;
uniform float glitch_amount : hint_range(0.0, 1.0) = 0.3;
uniform bool waveform_mode = false;
uniform float fade_alpha : hint_range(0.0, 1.0) = 1.0;
uniform float transition_progress : hint_range(0.0, 1.0) = 0.0;

// 伪随机
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
    vec2 uv = UV;
    float t = global_time * scroll_speed;

    // 网格化
    vec2 grid_uv = floor(uv * grid_size);
    vec2 cell_uv = fract(uv * grid_size);

    // 每列不同的滚动速度
    float col_speed = hash(vec2(grid_uv.x, 0.0)) * 2.0 + 0.5;
    grid_uv.y = floor(uv.y * grid_size - t * col_speed);

    // 随机"字符"亮度
    float char_val = hash(grid_uv);

    // 列头发光（最新的数据）
    float head_y = fract(t * col_speed / grid_size);
    float head_dist = abs(UV.y - head_y);
    float head_glow = exp(-head_dist * 20.0) * 0.8;

    // 故障效果
    float glitch = 0.0;
    if (glitch_amount > 0.0) {
        float glitch_line = step(0.98, hash(vec2(floor(global_time * 10.0), grid_uv.y)));
        glitch = glitch_line * glitch_amount;
    }

    // 颜色
    vec3 base_color = primary_color.rgb * char_val * 0.3;
    base_color += primary_color.rgb * head_glow;

    // 故障时切换到次要色
    base_color = mix(base_color, secondary_color.rgb * char_val, glitch);

    // 波形战争模式：添加波形叠加
    if (waveform_mode) {
        float wave = sin(uv.x * 20.0 + t * 5.0) * 0.5 + 0.5;
        float wave_line = smoothstep(0.02, 0.0, abs(uv.y - 0.5 - wave * 0.3));
        base_color += primary_color.rgb * wave_line * 0.5;
    }

    // 节拍脉冲
    float beat_pulse = exp(-beat_phase * 5.0);
    base_color += primary_color.rgb * beat_pulse * 0.2 * char_val;

    // 扫描线
    float scanline = sin(UV.y * grid_size * 3.14159 * 2.0) * 0.05 + 0.95;
    base_color *= scanline;

    COLOR = vec4(base_color, fade_alpha);
}
