# Godot 4.x 技术实施指南：谐振视界 (Resonance Horizon)

**适用版本：** Godot 4.2+ (推荐使用 Forward+ 渲染管线以获得最佳的光影效果)
**核心目标：** 使用 Shader 和粒子系统替代复杂的 3D 建模，实现“科幻神学”视觉风格。

---

## 1. 核心材质：神圣几何 (Sacred Geometry Shader)

这是用于玩家、敌人和基础子弹的通用材质。它不使用贴图，而是利用菲涅尔效应（Fresnel）产生边缘发光的“能量体”质感。

- **节点结构：** `MeshInstance3D` -> `ShaderMaterial`
- **代码 (GDShader):**

```glsl
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// 属性配置
uniform vec3 albedo : source_color = vec3(0.0, 0.0, 0.0); // 核心颜色（通常是黑色或深色）
uniform vec3 emission_color : source_color = vec3(0.0, 1.0, 1.0); // 发光颜色（青色/金色）
uniform float emission_energy : hint_range(0.0, 16.0) = 5.0; // 发光强度
uniform float fresnel_power : hint_range(0.1, 10.0) = 2.0; // 边缘光范围

// 故障效果参数 (受疲劳度或受击控制)
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float time_speed = 10.0;

void fragment() {
    // 基础颜色
    ALBEDO = albedo;
    
    // 计算菲涅尔效应 (边缘发光)
    float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
    
    // 故障抖动 (可选：仅在受击或敌人身上启用)
    float noise = sin(UV.y * 50.0 + TIME * time_speed) * glitch_intensity;
    fresnel += noise;
    
    // 应用发光
    EMISSION = emission_color * fresnel * emission_energy;
    
    // 让材质看起来像玻璃或全息投影
    ROUGHNESS = 0.1;
    METALLIC = 0.8;
}
```

- **使用建议：**
    - **玩家：** 将 `emission_color` 设为金色或青色。
    - **敌人：** 将 `emission_color` 设为洋红或红色，并动态调整 `glitch_intensity`。

---

## 2. 动态环境：脉冲网格 (Pulsing Grid)

创建一个无限延伸的地面，它会随着音乐的 BPM 产生波浪。

- **节点结构：** `MeshInstance3D` (使用一个大的 `PlaneMesh`，例如 100x100)
- **代码 (GDShader):**

```glsl
shader_type spatial;
render_mode unshaded; // 不需要受光照影响，自发光

uniform vec3 grid_color : source_color = vec3(0.0, 1.0, 1.0);
uniform float cell_size = 1.0;
uniform float line_thickness = 0.02;

// 全局音频能量 (由脚本每帧传入)
uniform float audio_energy = 0.0; 

void vertex() {
    // 顶点位移：随着音频能量在Y轴波动
    // 离中心越远，波动可能越小或越大
    float wave = sin(VERTEX.x * 0.5 + TIME) * cos(VERTEX.z * 0.5 + TIME);
    VERTEX.y += wave * audio_energy * 0.5;
}

void fragment() {
    // 程序化生成网格线
    vec2 grid = fract(UV * vec2(100.0, 100.0)); // 假设UV映射为100倍
    float line_x = step(1.0 - line_thickness, grid.x) + step(grid.x, line_thickness);
    float line_y = step(1.0 - line_thickness, grid.y) + step(grid.y, line_thickness);
    
    float grid_mask = clamp(line_x + line_y, 0.0, 1.0);
    
    // 距离衰减 (让远处网格淡出黑色)
    float dist = length(UV - vec2(0.5));
    float alpha = 1.0 - smoothstep(0.3, 0.5, dist);
    
    ALBEDO = grid_color;
    EMISSION = grid_color * 2.0; // 配合WorldEnvironment的Glow
    ALPHA = grid_mask * alpha;
}
```

---

## 3. 性能优化：海量弹幕 (The MultiMesh Strategy)

在 Survivor-like 游戏中，同屏可能需要处理超过 2000 个子弹。绝对不能为每个子弹实例化一个独立的 `MeshInstance3D` 或 `Area3D` 节点。

- **Godot 解决方案：** `MultiMeshInstance3D`

### 3.1. 逻辑与渲染分离

- **逻辑层：** 使用 GDScript 或 GDExtension 管理纯数据结构（例如 `Array`），仅计算坐标和执行简单的距离碰撞检测。
- **渲染层：** 在每帧（`_process`）中，批量更新 `MultiMeshInstance3D` 的变换矩阵缓冲。

### 3.2. 实施步骤

1.  创建一个 `MultiMeshInstance3D` 节点。
2.  在 Inspector 中，设置其 `Multimesh` 属性的 `Transform Format` 为 `3D`。
3.  设置 `Mesh` 为一个简单的几何体（例如低多边形的球体）。
4.  将前述的“神圣几何 Shader”应用到该 `Mesh` 上。
5.  通过脚本批量更新实例：

```gdscript
extends MultiMeshInstance3D

# 假设 bullet_data 是一个包含所有子弹位置的数组
func _process_bullets(bullet_data: Array):
    # 如果子弹数量变化，调整实例计数
    if multimesh.instance_count != bullet_data.size():
        multimesh.instance_count = bullet_data.size()
    
    for i in range(bullet_data.size()):
        var bullet = bullet_data[i]
        var t = Transform3D()
        t.origin = bullet.position
        # 根据弹体大小参数缩放
        t = t.scaled(Vector3.ONE * bullet.size) 
        
        multimesh.set_instance_transform(i, t)
        
        # 进阶：如果需要不同颜色，需开启 Custom Data 并通过 set_instance_custom_data 传入颜色
        # multimesh.set_instance_custom_data(i, bullet.color)
```

---

## 4. 听感疲劳视觉化：全屏后处理 (Post-Processing)

使用 Godot 的 `WorldEnvironment` 和全屏 `CanvasLayer` Shader 来实现世界的“崩坏”效果。

### 4.1. WorldEnvironment 设置

- **Background Mode:** `Custom Color` (设为纯黑 `#000000`)
- **Glow (泛光):**
    - **Enabled:** `On`
    - **Intensity:** `1.5`
    - **Bloom:** `0.5`
    - **Blend Mode:** `Additive`

> **重要提示:** 这将使所有材质的 `EMISSION` 通道产生辉光，是营造霓虹感的关键。

### 4.2. 疲劳滤镜 (Fatigue Filter)

创建一个 `CanvasLayer`，并在其中添加一个填满全屏的 `ColorRect`。为这个 `ColorRect` 赋予一个专用的 `ShaderMaterial`。

- **代码 (GDShader):**

```glsl
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float fatigue_level : hint_range(0.0, 1.0) = 0.0; // 0=正常, 1=严重

void fragment() {
    vec2 uv = SCREEN_UV;
    
    // 1. 色差 (Chromatic Aberration) - 随疲劳增加
    float aberration_amount = fatigue_level * 0.02;
    vec4 r_col = texture(screen_texture, uv - vec2(aberration_amount, 0.0));
    vec4 g_col = texture(screen_texture, uv);
    vec4 b_col = texture(screen_texture, uv + vec2(aberration_amount, 0.0));
    
    vec4 final_color = vec4(r_col.r, g_col.g, b_col.b, 1.0);
    
    // 2. 扫描线/噪点 (Scanlines & Noise) - 高疲劳时出现
    if (fatigue_level > 0.5) {
        float scanline = sin(uv.y * 800.0) * 0.1 * fatigue_level;
        float noise = fract(sin(dot(uv, vec2(12.9898, 78.233) * TIME)) * 43758.5453) * 0.2 * fatigue_level;
        final_color.rgb -= scanline;
        final_color.rgb += noise;
    }
    
    // 3. 饱和度抽离 (Desaturation) - 濒死感
    if (fatigue_level > 0.8) {
        float gray = dot(final_color.rgb, vec3(0.299, 0.587, 0.114));
        // 保留红色作为警告色
        float redness = final_color.r - (final_color.g + final_color.b) * 0.5;
        if (redness < 0.2) {
             final_color.rgb = mix(final_color.rgb, vec3(gray), (fatigue_level - 0.8) * 5.0);
        }
    }

    COLOR = final_color;
}
```

---

## 5. 音频驱动 (Audio Driver)

要让画面随音乐跳动，需要从 Godot 的音频总线中提取频谱数据。

1.  **添加 AudioBus:** 在 Godot 底部的 **Audio** 面板中，为背景音乐轨道添加一个名为 
`"Music"` 的 Bus。
2.  **添加分析器:** 在 `"Music"` Bus 上添加 `SpectrumAnalyzer` 效果器。
3.  **脚本读取:**

```gdscript
# GlobalMusicManager.gd (Autoload)
extends Node

var spectrum_analyzer : AudioEffectSpectrumAnalyzerInstance

func _ready():
    # 获取频谱分析实例
    var bus_idx = AudioServer.get_bus_index("Music")
    spectrum_analyzer = AudioServer.get_bus_effect_instance(bus_idx, 0) # 假设它是第0个效果

func get_beat_energy() -> float:
    # 获取低频部分的能量 (鼓点/贝斯)
    # 频率范围 20Hz - 200Hz
    var magnitude = spectrum_analyzer.get_magnitude_for_frequency_range(20.0, 200.0)
    return magnitude.length() * 10.0 # 放大倍数
```

4.  **连接 Shader:** 在任何对象的 `_process` 函数中：

```gdscript
var energy = GlobalMusicManager.get_beat_energy()
material_override.set_shader_parameter("audio_energy", energy)
```

---

## 6. 总结与最佳实践

本技术实施指南专为独立开发者设计，核心策略是通过 Shader 和 GPU 加速技术，以最小的美术资源投入实现高质量的视觉效果。关键要点包括：

- **菲涅尔效应 (Fresnel Effect)** 是创造"能量体"质感的核心，适用于所有几何体。
- **MultiMeshInstance3D** 是处理海量弹幕的唯一可行方案，避免使用传统的节点实例化。
- **全屏后处理 (Post-Processing)** 是表现"听感疲劳"系统的关键，通过动态调整 `fatigue_level` 参数实现实时反馈。
- **音频驱动** 通过 `SpectrumAnalyzer` 实现画面与音乐的同步，是本游戏"战斗即是调频"核心隐喻的技术基础。

遵循这些原则，即使是小型团队也能在 Godot 4.x 中实现《谐振视界》所需的"科幻神学"视觉风格。
