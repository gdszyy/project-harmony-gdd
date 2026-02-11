shader_type canvas_item;

// === 全局参数 ===
global uniform float global_time;
global uniform float beat_phase;
global uniform vec3 chapter_color;
global uniform float beat_glow_extra;

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

// === 章节色彩混合强度 ===
uniform float chapter_color_blend : hint_range(0.0, 1.0) = 0.3;

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

    // 使用全局节拍相位计算节拍能量
    float global_beat = exp(-beat_phase * 3.0);
    float effective_beat = max(beat_energy, global_beat);

    // 章节色彩混合：将网格颜色与章节色彩融合
    vec4 chapter_grid_color = vec4(chapter_color, 1.0);
    vec4 blended_primary = mix(grid_color, chapter_grid_color, chapter_color_blend);
    vec4 blended_secondary = mix(grid_color_secondary, chapter_grid_color * 0.5, chapter_color_blend);

    // 脉冲颜色
    vec4 final_color = mix(blended_secondary, blended_primary, effective_beat * 0.5 + 0.5);

    // 节拍时刻的额外发光
    final_color.rgb += chapter_color * beat_glow_extra * 0.5;

    // 距离衰减
    float dist = length(uv - 0.5);
    float alpha = 1.0 - smoothstep(0.3, 0.5, dist);

    // 玩家位置波纹效果
    vec2 player_uv = (player_position / 4096.0) + 0.5;
    float player_dist = length(uv - player_uv);
    float ripple = sin(player_dist * 40.0 - global_time * 5.0) * 0.5 + 0.5;
    ripple *= exp(-player_dist * 5.0) * 0.2;
    final_color.rgb += blended_primary.rgb * ripple;

    COLOR = final_color;
    COLOR.a = grid_mask * alpha * (0.5 + effective_beat * 0.5);
}
