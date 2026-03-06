// resonance_cable.gdshader
// 共鸣网络线缆 Shader
// 基于 Docs/Summoning_VFX_Design.md 设计
shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_disabled, unshaded;

uniform vec4 cable_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float uv_offset = 0.0;
uniform float pulse_speed = 2.0;
uniform float pulse_width = 0.2;
uniform float emission_strength = 2.0;

// 伤害闪烁效果
uniform float damage_flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
    // 基础线缆透明度 (边缘淡出)
    float edge_alpha = sin(UV.y * PI);
    
    // 能量脉冲效果 (滚动UV)
    float pulse = fract(UV.x - uv_offset * pulse_speed);
    // 创建一个移动的光团
    float pulse_glow = smoothstep(0.5 - pulse_width, 0.5, pulse) * smoothstep(0.5 + pulse_width, 0.5, pulse);
    
    // 基础颜色
    vec3 final_color = cable_color.rgb;
    float final_alpha = cable_color.a * edge_alpha;
    
    // 叠加脉冲
    final_color += cable_color.rgb * pulse_glow * 2.0;
    final_alpha += pulse_glow * 0.5;
    
    // 伤害闪烁
    if (damage_flash > 0.0) {
        // 闪烁时产生电弧般的噪点
        float noise = fract(sin(dot(UV + TIME, vec2(12.9898, 78.233))) * 43758.5453);
        if (noise > 0.5) {
            final_color = mix(final_color, flash_color.rgb, damage_flash);
            final_alpha = mix(final_alpha, 1.0, damage_flash);
        }
    }
    
    ALBEDO = final_color;
    EMISSION = final_color * emission_strength;
    ALPHA = clamp(final_alpha, 0.0, 1.0);
}
