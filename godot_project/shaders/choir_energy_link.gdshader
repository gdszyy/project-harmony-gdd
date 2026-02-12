shader_type canvas_item;

## Choir Energy Link Shader
##
## 用于连接唱诗班成员的动态能量线，具有流动和脉冲效果。

// 定义 uniform 变量，用于在 GDScript 中控制 shader
uniform vec4 base_color : source_color = vec4(0.6, 0.1, 0.1, 1.0); // 基础颜色
uniform float flow_speed : hint_range(0.0, 5.0) = 1.0;       // 能量流动速度
uniform float link_intensity : hint_range(0.0, 5.0) = 1.0;   // 链接强度/亮度
uniform float beat_energy : hint_range(0.0, 1.0) = 0.0;      // 与节拍同步的能量值

// 简单的 2D 随机/噪声函数，用于生成纹理
float rand(vec2 co){
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    // 1. 能量流动效果
    // 通过将时间乘以流动速度并加到 UV 的 x 坐标上，实现水平滚动效果。
    vec2 noisy_uv = UV;
    noisy_uv.x += TIME * flow_speed * 0.2;
    // 通过拉伸 y 方向的坐标，使噪声呈现为垂直条纹状
    float noise = rand(noisy_uv * vec2(2.0, 20.0));

    // 2. 能量核心
    // 使用 UV.y 创建一个中心发光带，模拟能量线的核心部分。
    // abs(UV.y - 0.5) * 2.0 会得到一个从中心 0 到边缘 1 的梯度。
    float core = 1.0 - abs(UV.y - 0.5) * 2.0;
    core = pow(core, 2.0); // 使用 pow 使核心更窄、更亮。

    // 3. 节拍脉冲效果
    // beat_energy 由外部脚本根据音乐节拍传入，用于实现与音乐同步的脉冲发光。
    float pulse = beat_energy * 1.5; // 增强脉冲的视觉强度。

    // 4. 组合效果
    // 将核心、噪声和脉冲效果结合，形成最终的能量强度。
    float final_intensity = (core + noise * 0.5) * link_intensity + pulse;

    // 5. 计算最终颜色
    // 将基础颜色与计算出的强度相乘，并确保 alpha 通道受强度影响，实现发光效果。
    COLOR = vec4(base_color.rgb * final_intensity, base_color.a * core);
}
