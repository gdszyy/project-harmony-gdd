shader_type canvas_item;

// 章节过渡 Shader
// 用于 ChapterVisualManager 的过渡覆盖层

uniform float transition_progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 from_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 to_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float noise_scale : hint_range(1.0, 20.0) = 8.0;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
    vec2 uv = UV * noise_scale;
    float noise = hash(floor(uv));

    // 基于噪声的渐进式揭示
    float reveal = smoothstep(noise - 0.1, noise + 0.1, transition_progress);

    vec4 color = mix(from_color, to_color, reveal);

    // 过渡边缘发光
    float edge = smoothstep(0.0, 0.05, abs(reveal - 0.5));
    edge = 1.0 - edge;
    color.rgb += vec3(1.0) * edge * 0.5;

    COLOR = color;
}
