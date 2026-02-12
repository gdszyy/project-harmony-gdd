shader_type canvas_item;

// 对位爬虫 (Counterpoint Crawler) 金属着色器
// Issue #66: 腿部和炮塔的简单金属外观
// 程序化生成金属高光和反射效果

uniform vec4 metal_color : source_color = vec4(0.6, 0.45, 0.2, 1.0);
uniform vec4 highlight_color : source_color = vec4(1.0, 0.9, 0.6, 1.0);
uniform float shininess : hint_range(0.0, 1.0) = 0.6;
uniform float beat_energy : hint_range(0.0, 1.0) = 0.0;
uniform float wear : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
    vec2 uv = UV;

    // 基础金属色
    vec3 color = metal_color.rgb;

    // 纵向渐变 — 模拟圆柱体反射
    float cylinder_highlight = 1.0 - abs(uv.x - 0.5) * 2.0;
    cylinder_highlight = pow(cylinder_highlight, 2.0);
    color = mix(color, highlight_color.rgb, cylinder_highlight * shininess * 0.4);

    // 横向条纹 — 模拟车削痕迹
    float lathe_lines = sin(uv.y * 80.0) * 0.5 + 0.5;
    color *= 0.95 + lathe_lines * 0.05;

    // 磨损效果
    if (wear > 0.0) {
        float wear_noise = hash(floor(uv * 20.0));
        if (wear_noise < wear * 0.3) {
            color *= 0.7;
        }
    }

    // 节拍脉冲
    color += highlight_color.rgb * beat_energy * 0.2;

    // 边缘暗化
    float edge = smoothstep(0.0, 0.1, uv.x) * smoothstep(0.0, 0.1, 1.0 - uv.x);
    color *= 0.6 + edge * 0.4;

    COLOR = vec4(color, metal_color.a);
}
