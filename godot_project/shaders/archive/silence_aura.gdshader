shader_type canvas_item;

// Silence 敌人专用光环 Shader — 吸收/黑洞效果
// 应用于 Silence 敌人的光环 Sprite2D / ColorRect

uniform float aura_radius : hint_range(0.0, 1.0) = 0.8;
uniform float absorption_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float pulse_speed : hint_range(0.0, 5.0) = 2.0;
uniform float player_proximity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 aura_color : source_color = vec4(0.1, 0.0, 0.2, 0.6);
uniform float rotation_speed : hint_range(0.0, 3.0) = 0.5;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
    vec2 center = vec2(0.5);
    vec2 uv = UV - center;

    // 旋转 UV
    float angle = TIME * rotation_speed;
    mat2 rot = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle)));
    vec2 rotated_uv = rot * uv;

    float dist = length(uv);

    // 基础光环形状（径向渐变）
    float aura = smoothstep(aura_radius, aura_radius * 0.3, dist);

    // 脉冲呼吸效果
    float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
    aura *= mix(0.6, 1.0, pulse);

    // 玩家靠近时光环增强
    aura *= mix(1.0, 1.5, player_proximity);

    // 旋涡纹理（螺旋线）
    float spiral_angle = atan(rotated_uv.y, rotated_uv.x);
    float spiral = sin(spiral_angle * 3.0 + dist * 20.0 - TIME * 2.0) * 0.5 + 0.5;
    spiral *= smoothstep(aura_radius, 0.1, dist);

    // 吸收粒子效果（向中心汇聚的点）
    float particles = 0.0;
    for (int i = 0; i < 6; i++) {
        float fi = float(i);
        float particle_angle = fi * 1.047 + TIME * (0.5 + fi * 0.1);
        float particle_dist = mod(fi * 0.15 + TIME * 0.3, aura_radius);
        vec2 particle_pos = vec2(cos(particle_angle), sin(particle_angle)) * (aura_radius - particle_dist);
        float particle = smoothstep(0.03, 0.0, length(uv - particle_pos));
        particles += particle;
    }

    // 合成颜色
    vec4 color = aura_color;
    color.a = aura * absorption_intensity;

    // 螺旋纹理叠加
    color.rgb += vec3(spiral * 0.1);

    // 粒子叠加（更亮的点）
    color.rgb += vec3(particles * 0.3);

    // 边缘高亮
    float edge = smoothstep(aura_radius, aura_radius - 0.05, dist) - smoothstep(aura_radius - 0.05, aura_radius - 0.1, dist);
    color.rgb += vec3(edge * 0.4 * (0.5 + pulse * 0.5));

    COLOR = color;
}
