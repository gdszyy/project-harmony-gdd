shader_type spatial;
render_mode unshaded, cull_disabled;

// === 边界外观 ===
uniform vec3 noise_color_a : source_color = vec3(0.8, 0.8, 0.8);
uniform vec3 noise_color_b : source_color = vec3(0.1, 0.1, 0.1);
uniform float noise_scale : hint_range(1.0, 100.0) = 40.0;
uniform float distortion_strength : hint_range(0.0, 1.0) = 0.3;
uniform float alpha_fade : hint_range(0.0, 1.0) = 0.7;

float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    vec2 uv = UV * noise_scale;

    // 动态白噪音
    float noise = random(floor(uv) + floor(TIME * 30.0));

    // 扫描线叠加
    float scanline = sin(UV.y * 200.0 + TIME * 10.0) * 0.1;

    vec3 color = mix(noise_color_b, noise_color_a, noise) + scanline;

    // 垂直渐变 (底部更透明)
    float gradient = smoothstep(0.0, 0.5, UV.y);

    ALBEDO = color;
    EMISSION = color * 0.5;
    ALPHA = alpha_fade * gradient;
}
