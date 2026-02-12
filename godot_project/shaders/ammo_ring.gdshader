shader_type canvas_item;

// ============================================================
// 弹药环形 HUD 着色器
// 绘制可变长度弧形弧段，支持填充比例和颜色
// ============================================================

uniform float start_angle : hint_range(-3.1416, 3.1416) = 0.0;
uniform float end_angle : hint_range(-3.1416, 3.1416) = 1.5708;
uniform float fill_ratio : hint_range(0.0, 1.0) = 1.0;
uniform vec3 arc_color : source_color = vec3(0.0, 1.0, 0.831);
uniform float inner_radius : hint_range(0.0, 0.5) = 0.35;
uniform float outer_radius : hint_range(0.0, 0.5) = 0.45;
uniform float is_active : hint_range(0.0, 1.0) = 0.0;
uniform float is_depleted : hint_range(0.0, 1.0) = 0.0;
uniform float time_sec : hint_range(0.0, 9999.0) = 0.0;

void fragment() {
    vec2 uv = UV;
    vec2 center = vec2(0.5);
    vec2 delta = uv - center;
    float dist = length(delta);
    float angle = atan(delta.y, delta.x);

    // 弧段区域判定
    float in_ring = step(inner_radius, dist) * step(dist, outer_radius);

    // 角度范围判定（处理跨越 -PI/PI 的情况）
    float total_arc = end_angle - start_angle;
    if (total_arc < 0.0) total_arc += 6.2832;

    float angle_offset = angle - start_angle;
    if (angle_offset < 0.0) angle_offset += 6.2832;

    float in_arc = step(angle_offset, total_arc);

    // 填充比例
    float fill_arc = total_arc * fill_ratio;
    float in_fill = step(angle_offset, fill_arc);

    // 基础弧段
    float arc_mask = in_ring * in_arc;
    float fill_mask = in_ring * in_arc * in_fill;
    float empty_mask = arc_mask * (1.0 - in_fill);

    // 颜色
    vec3 filled_color = arc_color;
    vec3 empty_color = arc_color * 0.2;

    // 激活高亮
    if (is_active > 0.5) {
        float flash = sin(time_sec * 8.0) * 0.3 + 0.7;
        filled_color *= (1.0 + flash * 0.3);
    }

    // 耗尽警告
    if (is_depleted > 0.5) {
        filled_color = vec3(0.3);
        float red_flash = sin(time_sec * 6.0) * 0.5 + 0.5;
        filled_color += vec3(1.0, 0.1, 0.1) * red_flash * 0.3;
    }

    // 边缘辉光
    float edge_inner = smoothstep(0.01, 0.0, abs(dist - inner_radius)) * arc_mask;
    float edge_outer = smoothstep(0.01, 0.0, abs(dist - outer_radius)) * arc_mask;
    float edge_glow = (edge_inner + edge_outer) * 0.3;

    // 合成
    vec3 final_color = filled_color * fill_mask + empty_color * empty_mask;
    final_color += arc_color * edge_glow;

    float final_alpha = max(fill_mask * 0.8, empty_mask * 0.3);
    final_alpha = max(final_alpha, edge_glow);

    COLOR = vec4(final_color, final_alpha);
}
