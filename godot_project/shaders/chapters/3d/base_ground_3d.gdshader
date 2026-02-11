shader_type spatial;
render_mode unshaded, world_vertex_coords;

// === 全局参数 ===
global uniform float global_time;
global uniform float beat_phase;
global uniform vec3 chapter_color;

// === 局部参数 ===
uniform int chapter_index = 0;
uniform float grid_scale = 1.0;

void fragment() {
    // 使用世界坐标进行平铺
    vec2 world_uv = VERTEX.xz * 0.1 * grid_scale;
    
    // 基础网格
    vec2 grid = fract(world_uv);
    float line = smoothstep(0.02, 0.0, abs(grid.x - 0.5) - 0.48) + 
                 smoothstep(0.02, 0.0, abs(grid.y - 0.5) - 0.48);
    
    // 章节特定逻辑
    vec3 final_color = chapter_color * 0.2;
    
    if (chapter_index == 0) {
        // 毕达哥拉斯：克拉尼图形模拟
        float d = length(world_uv);
        float pattern = sin(world_uv.x * 5.0) * cos(world_uv.y * 5.0);
        final_color += chapter_color * step(abs(pattern), 0.1 * beat_phase);
    } else if (chapter_index == 6) {
        // 数字：扫描线
        float scan = sin(world_uv.y * 20.0 - global_time * 10.0) * 0.5 + 0.5;
        final_color += chapter_color * scan * 0.3;
    }
    
    // 网格线发光
    final_color += chapter_color * line * (0.5 + beat_phase);
    
    ALBEDO = final_color;
    EMISSION = final_color * 2.0; // 3D 环境下利用自发光触发 Glow
}
