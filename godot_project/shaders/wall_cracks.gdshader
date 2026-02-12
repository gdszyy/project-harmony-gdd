# ## wall_cracks.gdshader
# ## 墙体裂缝效果 Shader
# ## 使用 Worley 噪声生成程序化的裂缝图案，裂缝中带有发光效果。
shader_type canvas_item;

# ## 控制参数
uniform float crack_intensity : hint_range(0.0, 1.0) = 1.0; // 裂缝强度
uniform vec4 crack_color : source_color = vec4(1.0, 0.1, 0.0, 1.0); // 裂缝发光颜色
uniform float crack_scale : hint_range(1.0, 20.0) = 8.0;
uniform float crack_width : hint_range(0.01, 0.1) = 0.03;

# ## 2D 伪随机函数
vec2 hash(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

# ## Worley 噪声函数 (F1)
float worley(vec2 p) {
    vec2 i_p = floor(p);
    vec2 f_p = fract(p);

    float min_dist = 1.0;

    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 neighbor = vec2(float(x), float(y));
            vec2 point = hash(i_p + neighbor);
            vec2 diff = neighbor + point - f_p;
            float dist = length(diff);
            min_dist = min(min_dist, dist);
        }
    }
    return min_dist;
}

void fragment() {
    vec2 uv = UV * crack_scale;
    
    // 计算 Worley 噪声值
    float noise = worley(uv);
    
    // 根据噪声值生成裂缝
    float crack = smoothstep(crack_width, crack_width + 0.01, noise);
    crack = 1.0 - crack;
    
    // 最终颜色
    vec4 final_color = crack_color;
    final_color.a *= crack * crack_intensity;

    COLOR = final_color;
}
