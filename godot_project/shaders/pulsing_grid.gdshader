shader_type canvas_item;

// === 网格外观 ===
uniform vec4 grid_color : source_color = vec4(0.0, 1.0, 0.8, 1.0);
uniform vec4 grid_color_secondary : source_color = vec4(0.0, 0.4, 0.8, 1.0);
uniform float cell_size = 64.0;
uniform float line_thickness : hint_range(0.0, 0.5) = 0.05;
uniform float sub_line_thickness : hint_range(0.0, 0.5) = 0.02;

// === 音频驱动 ===
uniform float beat_energy : hint_range(0.0, 2.0) = 0.0;
uniform float time = 0.0;

// === 玩家位置 (用于波纹效果) ===
uniform vec2 player_position = vec2(0.0, 0.0);

void fragment() {
    // 使用 SCREEN_UV 或 UV，这里用 UV 配合大型 Sprite
    vec2 uv = UV;
    
    // 世界坐标模拟
    vec2 world_pos = (uv - 0.5) * 4096.0;
    
    // 基础网格
    vec2 grid_main = fract(world_pos / cell_size);
    float line_x = step(1.0 - line_thickness, grid_main.x) + step(grid_main.x, line_thickness);
    float line_y = step(1.0 - line_thickness, grid_main.y) + step(grid_main.y, line_thickness);
    float main_grid = clamp(line_x + line_y, 0.0, 1.0);
    
    // 次级网格
    vec2 grid_sub = fract(world_pos / (cell_size * 0.25));
    float sub_x = step(1.0 - sub_line_thickness, grid_sub.x) + step(grid_sub.x, sub_line_thickness);
    float sub_y = step(1.0 - sub_line_thickness, grid_sub.y) + step(grid_sub.y, sub_line_thickness);
    float sub_grid = clamp(sub_x + sub_y, 0.0, 1.0) * 0.3;
    
    float grid_mask = clamp(main_grid + sub_grid, 0.0, 1.0);
    
    // 脉冲颜色
    vec4 final_color = mix(grid_color_secondary, grid_color, beat_energy * 0.5 + 0.5);
    
    // 距离衰减
    float dist = length(uv - 0.5);
    float alpha = 1.0 - smoothstep(0.3, 0.5, dist);
    
    COLOR = final_color;
    COLOR.a = grid_mask * alpha * (0.5 + beat_energy * 0.5);
}
