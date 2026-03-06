// summon_phase.gdshader
// 构造体相位 Shader
// 基于 Docs/Summoning_VFX_Design.md 设计
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform float phase_blend : hint_range(-1.0, 1.0) = 0.0; // -1=低通, 0=全频, 1=高通
uniform float emission_energy : hint_range(0.0, 5.0) = 1.0;
uniform vec4 base_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform sampler2D noise_texture;

// 边缘发光参数
uniform float rim_power : hint_range(0.0, 10.0) = 3.0;
uniform float rim_intensity : hint_range(0.0, 5.0) = 1.0;

void vertex() {
    // 低通相位的液态化扭曲
    float liquify_strength = max(0.0, -phase_blend);
    if (liquify_strength > 0.0) {
        float noise = texture(noise_texture, VERTEX.xz * 0.5 + vec2(TIME * 0.2, TIME * 0.1)).r;
        VERTEX += NORMAL * (noise - 0.5) * liquify_strength * 0.2;
    }
}

void fragment() {
    float noise = texture(noise_texture, UV + vec2(TIME * 0.1, 0.0)).r;
    float wireframe_strength = max(0.0, phase_blend);
    float liquify_strength = max(0.0, -phase_blend);
    
    vec3 final_color = base_color.rgb;
    
    // 高通：颜色变亮，边缘锐化 (模拟线框)
    // 简单的线框效果模拟：使用UV边缘
    vec2 grid = abs(fract(UV * 10.0 - 0.5) - 0.5) / fwidth(UV * 10.0);
    float line = min(grid.x, grid.y);
    float wireframe = 1.0 - min(line, 1.0);
    
    vec3 high_pass_color = mix(final_color, vec3(1.0), 0.5);
    high_pass_color += wireframe * vec3(1.0) * 2.0;
    
    // 低通：颜色变暗，增加噪波扭曲
    vec3 low_pass_color = final_color * 0.5 + vec3(0.1, 0.0, 0.2);
    low_pass_color = mix(low_pass_color, final_color, noise * 0.5);
    
    // 混合
    if (phase_blend > 0.0) {
        final_color = mix(final_color, high_pass_color, wireframe_strength);
    } else if (phase_blend < 0.0) {
        final_color = mix(final_color, low_pass_color, liquify_strength);
    }
    
    // 边缘发光 (Rim Light)
    float rim = 1.0 - dot(VIEW, NORMAL);
    rim = smoothstep(0.0, 1.0, rim);
    rim = pow(rim, rim_power);
    
    ALBEDO = final_color;
    EMISSION = final_color * emission_energy + final_color * rim * rim_intensity;
    
    // 透明度处理
    float alpha = 1.0;
    if (phase_blend < 0.0) {
        alpha = mix(1.0, 0.6 + noise * 0.4, liquify_strength);
    } else if (phase_blend > 0.0) {
        // 高通模式下，非线框部分变透明
        alpha = mix(1.0, max(0.2, wireframe), wireframe_strength);
    }
    
    ALPHA = alpha;
}
