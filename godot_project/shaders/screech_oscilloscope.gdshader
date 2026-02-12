shader_type canvas_item;

// Screech 低通(Sub-Bass)形态的示波器效果 Shader
// 用于在球体上绘制利萨茹(Lissajous)曲线

uniform vec4 base_color : source_color = vec4(0.2, 1.0, 0.8, 1.0);
uniform float thickness : hint_range(0.01, 0.2) = 0.05;

// 利萨茹曲线参数
uniform float freq_x = 3.0;
uniform float freq_y = 4.0;
uniform float phase_shift = 0.5; // 相位差

void fragment() {
    vec2 uv = UV * 2.0 - 1.0; // 将 UV 映射到 [-1, 1] 范围
    float aspect = 1.0; // 如果不是正方形，需要传入屏幕宽高比
    uv.x *= aspect;

    float time = TIME * 0.8;

    // 生成利萨茹曲线坐标
    // 我们不是直接画点，而是计算当前 uv 离曲线有多远
    float angle = atan(uv.y, uv.x);
    float radius = length(uv);

    // 随时间变化的频率和相位，让图案动起来
    float current_freq_x = freq_x + sin(time * 0.3) * 0.2;
    float current_freq_y = freq_y + cos(time * 0.5) * 0.2;
    float current_phase = phase_shift * PI + sin(time * 0.2) * PI;

    // 计算在当前角度下，利萨茹曲线应该在的半径
    // 这是一种简化的近似，通过参数方程反求半径
    // x = R * cos(theta) = sin(A*t + d)
    // y = R * sin(theta) = sin(B*t)
    // 这是一个复杂问题，我们用更直接的距离场方法

    // 直接在 fragment shader 中迭代计算曲线上的点，然后计算距离
    float min_dist = 100.0;
    const int steps = 150;
    for (int i = 0; i < steps; i++) {
        float t = float(i) / float(steps) * 2.0 * PI;
        vec2 point_on_curve;
        point_on_curve.x = sin(current_freq_x * t + current_phase);
        point_on_curve.y = sin(current_freq_y * t);

        min_dist = min(min_dist, distance(uv, point_on_curve));
    }

    // 根据距离场绘制线条
    float line = smoothstep(thickness, thickness - 0.02, min_dist);

    // 基础形状是一个球体，超出半径的区域透明
    float circle = 1.0 - smoothstep(0.95, 1.0, length(uv));

    vec3 final_color = base_color.rgb * line;

    COLOR = vec4(final_color, line * circle * base_color.a);
}
