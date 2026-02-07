shader_type spatial;
render_mode unshaded, cull_disabled;

// === 网格外观 ===
uniform vec3 grid_color : source_color = vec3(0.0, 1.0, 0.8);
uniform vec3 grid_color_secondary : source_color = vec3(0.0, 0.4, 0.8);
uniform float cell_size = 2.0;
uniform float line_thickness : hint_range(0.005, 0.1) = 0.02;
uniform float sub_line_thickness : hint_range(0.002, 0.05) = 0.008;

// === 音频驱动 ===
uniform float audio_energy : hint_range(0.0, 2.0) = 0.0;
uniform float beat_pulse : hint_range(0.0, 1.0) = 0.0;

// === 玩家位置 (用于波纹效果) ===
uniform vec3 player_position = vec3(0.0, 0.0, 0.0);

// === 动画 ===
uniform float scroll_speed = 0.1;

void vertex() {
    // 顶点位移：随音频能量在Y轴波动
    float dist_to_player = length(VERTEX.xz - player_position.xz);
    float wave = sin(VERTEX.x * 0.5 + TIME * 1.5) * cos(VERTEX.z * 0.5 + TIME * 1.2);

    // 玩家脚下的波纹
    float ripple = sin(dist_to_player * 3.0 - TIME * 6.0) * exp(-dist_to_player * 0.15);

    VERTEX.y += wave * audio_energy * 0.3 + ripple * 0.2 + beat_pulse * 0.15;
}

void fragment() {
    // 世界坐标网格
    vec2 world_uv = UV * 100.0;

    // 主网格线
    vec2 grid_main = fract(world_uv / cell_size);
    float line_x = step(1.0 - line_thickness, grid_main.x) + step(grid_main.x, line_thickness);
    float line_y = step(1.0 - line_thickness, grid_main.y) + step(grid_main.y, line_thickness);
    float main_grid = clamp(line_x + line_y, 0.0, 1.0);

    // 次级网格线 (更细)
    vec2 grid_sub = fract(world_uv / (cell_size * 0.25));
    float sub_x = step(1.0 - sub_line_thickness, grid_sub.x) + step(grid_sub.x, sub_line_thickness);
    float sub_y = step(1.0 - sub_line_thickness, grid_sub.y) + step(grid_sub.y, sub_line_thickness);
    float sub_grid = clamp(sub_x + sub_y, 0.0, 1.0) * 0.3;

    float grid_mask = clamp(main_grid + sub_grid, 0.0, 1.0);

    // 距离衰减 (远处淡出)
    float dist = length(UV - vec2(0.5));
    float alpha = 1.0 - smoothstep(0.3, 0.5, dist);

    // 节拍脉冲颜色
    vec3 final_color = mix(grid_color_secondary, grid_color, beat_pulse * 0.5 + 0.5);

    // 玩家附近高亮
    float player_dist = length(UV * 100.0 - player_position.xz);
    float player_glow = exp(-player_dist * 0.05) * 0.5;

    ALBEDO = final_color;
    EMISSION = final_color * (1.5 + beat_pulse * 1.5 + player_glow);
    ALPHA = grid_mask * alpha;
}
