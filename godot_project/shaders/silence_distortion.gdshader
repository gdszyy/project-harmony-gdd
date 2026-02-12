## silence_distortion.gdshader
## 寂静敌人的空间扭曲光环效果
## 实现引力透镜般的背景扭曲，并带有脉冲呼吸感。
shader_type canvas_item;

// Godot 4.x 需要这个 hint 来访问屏幕纹理
render_mode blend_add, unshaded;

// ============================================================
// Uniforms
// ============================================================

## 扭曲强度，控制引力透镜效果的强弱
uniform float distortion_amount : hint_range(0.0, 0.5, 0.01) = 0.05;
## 脉冲呼吸效果的速度
uniform float pulse_speed : hint_range(0.1, 5.0) = 1.5;
## 脉冲呼吸效果的强度
uniform float pulse_intensity : hint_range(0.0, 1.0) = 0.2;
## 中心黑洞的大小（0到1，相对于UV坐标）
uniform float core_radius : hint_range(0.0, 1.0) = 0.25;


// ============================================================
// Fragment Shader
// ============================================================

void fragment() {
    // 中心点 UV 坐标 (0.5, 0.5)
    vec2 center = vec2(0.5);
    // 当前片元到中心的向量和距离
    vec2 to_center = center - UV;
    float dist_from_center = length(to_center);

    // 如果在核心半径内，则完全透明（黑洞效果）
    if (dist_from_center < core_radius) {
        COLOR.a = 0.0;
        return;
    }

    // 脉冲效果，使用时间函数模拟呼吸
    float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_intensity;
    
    // 计算扭曲强度，离中心越近，扭曲越强
    // 使用 smoothstep 创建一个平滑的过渡区域
    float distortion_falloff = 1.0 - smoothstep(core_radius, 0.5, dist_from_center);
    float current_distortion = distortion_amount * distortion_falloff * pulse;

    // 计算扭曲向量，径向向外
    vec2 distortion_vector = normalize(to_center) * current_distortion;
    
    // 将扭曲应用到屏幕 UV 上
    vec2 distorted_screen_uv = SCREEN_UV - distortion_vector;

    // 从屏幕纹理中采样扭曲后的颜色
    vec4 screen_color = texture(SCREEN_TEXTURE, distorted_screen_uv);

    // 输出最终颜色
    // 我们只扭曲背景，所以自己的颜色是透明的
    COLOR = screen_color;
    // 在边缘处添加一点微光，让效果更明显
    float edge_glow = smoothstep(0.45, 0.5, dist_from_center);
    COLOR.a = 1.0 - edge_glow;
}
