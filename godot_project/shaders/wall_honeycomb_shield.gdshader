# ## wall_honeycomb_shield.gdshader
# ## 蜂巢护盾效果 Shader
# ## 动态生成程序化的六边形网格护盾，并带有激活和破碎的动画效果。
shader_type canvas_item;

# ## 控制参数
uniform float shield_strength : hint_range(0.0, 1.0) = 1.0; // 护盾强度，控制可见性
uniform float shield_activation : hint_range(0.0, 1.0) = 1.0; // 护盾激活/破碎动画 (0=破碎, 1=激活)
uniform vec4 shield_color : source_color = vec4(0.5, 0.8, 1.0, 1.0);
uniform float line_thickness : hint_range(0.01, 0.2) = 0.05;
uniform float grid_scale : hint_range(1.0, 50.0) = 10.0;

# ## 六边形网格函数
# ## 来源: https://www.shadertoy.com/view/llG3z1
vec2 hex_coord(vec2 uv) {
    vec2 r = vec2(1.0, 1.732); // sqrt(3)
    vec2 h = r * 0.5;
    vec2 a = mod(uv, r) - h;
    vec2 b = mod(uv - h, r) - h;
    return dot(a, a) < dot(b, b) ? a : b;
}

void fragment() {
    vec2 scaled_uv = UV * grid_scale;
    
    // 计算到最近六边形中心的距离向量
    vec2 hex_c = hex_coord(scaled_uv);
    
    // 计算到六边形边缘的距离
    // 使用 dot(hex_c, hex_c) 是到中心的距离平方，我们用法线来找边缘
    float dist_to_edge = abs(hex_c.x) * 0.866025 + abs(hex_c.y) * 0.5;
    dist_to_edge = abs(dist_to_edge - 0.5);

    // 绘制线条
    float line = smoothstep(line_thickness, line_thickness + 0.02, dist_to_edge);
    line = 1.0 - line;

    // 护盾激活/破碎动画
    // 从中心向外扩散的圆形 clip
    float activation_mask = smoothstep(shield_activation - 0.1, shield_activation, length(UV - 0.5) * 2.0);
    line *= (1.0 - activation_mask);

    // 最终颜色
    vec4 final_color = shield_color;
    final_color.a *= line * shield_strength;

    COLOR = final_color;
}
