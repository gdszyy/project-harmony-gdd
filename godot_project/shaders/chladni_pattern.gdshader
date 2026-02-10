shader_type canvas_item;

// ============================================================
// 克拉尼图形着色器 (Chladni Pattern Shader)
// 用于第一章 Boss 战"律动尊者·毕达哥拉斯"的核心视觉机制。
// 生成数学上精确的克拉尼图形（振动平板的驻波图案），
// 线条为致死区域，节点为安全区。
//
// 克拉尼图形公式：
//   f(x,y) = A * sin(n*pi*x/L) * sin(m*pi*y/L)
//           + B * sin(m*pi*x/L) * sin(n*pi*y/L)
// 其中 n, m 为模态参数，决定图形复杂度。
// ============================================================

// === 图形参数 ===
uniform float pattern_n : hint_range(1.0, 8.0) = 2.0;
uniform float pattern_m : hint_range(1.0, 8.0) = 3.0;
uniform float pattern_blend : hint_range(-1.0, 1.0) = 0.5;

// === 叠加图形（阶段二使用） ===
uniform float overlay_n : hint_range(0.0, 8.0) = 0.0;
uniform float overlay_m : hint_range(0.0, 8.0) = 0.0;
uniform float overlay_blend : hint_range(-1.0, 1.0) = 0.5;
uniform float overlay_intensity : hint_range(0.0, 1.0) = 0.0;

// === 视觉配置 ===
uniform vec4 line_color : source_color = vec4(0.8, 0.2, 0.15, 0.9);
uniform vec4 safe_color : source_color = vec4(0.15, 0.6, 1.0, 0.5);
uniform vec4 danger_glow_color : source_color = vec4(1.0, 0.3, 0.1, 0.6);
uniform float line_sharpness : hint_range(1.0, 50.0) = 15.0;
uniform float glow_radius : hint_range(0.0, 0.2) = 0.05;

// === 动画 ===
uniform float time = 0.0;
uniform float beat_energy : hint_range(0.0, 1.0) = 0.0;
uniform float transition_progress : hint_range(0.0, 1.0) = 1.0;
uniform float rotation_speed : hint_range(0.0, 2.0) = 0.1;

// === 安全节点高亮 ===
uniform float safe_node_pulse : hint_range(0.0, 1.0) = 0.0;

// 克拉尼函数：计算给定点的振动幅度
float chladni(vec2 uv, float n, float m, float blend) {
    float PI = 3.14159265359;
    float a = sin(n * PI * uv.x) * sin(m * PI * uv.y);
    float b = sin(m * PI * uv.x) * sin(n * PI * uv.y);
    return mix(a, b, blend * 0.5 + 0.5);
}

// 旋转矩阵
vec2 rotate2d(vec2 uv, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return vec2(uv.x * c - uv.y * s, uv.x * s + uv.y * c);
}

void fragment() {
    // 将 UV 映射到 [-1, 1] 范围
    vec2 uv = (UV - 0.5) * 2.0;
    
    // 应用缓慢旋转
    uv = rotate2d(uv, time * rotation_speed);
    
    // 映射到 [0, 1] 用于克拉尼计算
    vec2 chladni_uv = uv * 0.5 + 0.5;
    
    // 主图形
    float pattern = chladni(chladni_uv, pattern_n, pattern_m, pattern_blend);
    
    // 叠加图形（阶段二）
    if (overlay_intensity > 0.01) {
        float overlay = chladni(chladni_uv, overlay_n, overlay_m, overlay_blend);
        pattern = mix(pattern, pattern + overlay * 0.7, overlay_intensity);
    }
    
    // 节拍能量影响图形振动
    float beat_distortion = beat_energy * 0.1;
    pattern += sin(time * 8.0) * beat_distortion;
    
    // 计算线条（零值附近为线条/致死区域）
    float abs_pattern = abs(pattern);
    
    // 锐利的线条
    float line_mask = 1.0 - smoothstep(0.0, 1.0 / line_sharpness, abs_pattern);
    
    // 柔和的发光
    float glow_mask = 1.0 - smoothstep(0.0, glow_radius, abs_pattern);
    glow_mask = glow_mask * glow_mask; // 二次衰减
    
    // 安全区域（远离零值的区域）
    float safe_mask = smoothstep(0.1, 0.3, abs_pattern);
    
    // 节拍脉冲效果
    float pulse = 1.0 + beat_energy * 0.3;
    line_mask *= pulse;
    
    // 颜色混合
    vec4 final_color = vec4(0.0);
    
    // 危险区域发光
    final_color += danger_glow_color * glow_mask * 0.5;
    
    // 线条
    final_color += line_color * line_mask;
    
    // 安全区域柔和高亮
    float safe_pulse = 0.5 + safe_node_pulse * 0.5 * sin(time * 3.0);
    final_color += safe_color * safe_mask * safe_pulse * 0.3;
    
    // 边缘衰减（圆形裁剪）
    float dist = length(uv);
    float edge_fade = 1.0 - smoothstep(0.8, 1.0, dist);
    
    // 过渡动画（淡入）
    float alpha = final_color.a * edge_fade * transition_progress;
    
    // 节拍闪烁
    alpha *= (1.0 + beat_energy * 0.2);
    
    COLOR = vec4(final_color.rgb, alpha);
}
