# 《Project Harmony》场景美术落地方案

**作者：** Manus AI
**版本：** 1.0
**日期：** 2026年2月12日

---

## 0. 引言：从概念到代码

本文档是连接《场景美术落地指南》与Godot引擎实现的桥梁，为开发者提供将章节视觉概念转化为具体游戏场景的详细技术路径。它基于《技术美术蓝图》中确立的“2D增强”核心决策，旨在通过最小化对现有架构的改动，高效实现丰富且差异化的章节视觉。

**核心实现策略：**
1.  **坚持2D架构**：所有场景都在现有的纯2D节点（`Node2D`）体系内构建。
2.  **启用后处理**：在主场景中添加`WorldEnvironment`节点，启用Glow（辉光）、Tonemapping和色彩校正，这是实现高质量光影效果的关键。
3.  **分层场景构建**：使用多个`CanvasLayer`或`Node2D`节点对场景进行分层（背景、游戏层、前景、VFX），以实现深度感和复杂的视觉效果。
4.  **Shader驱动**：大量使用程序化Shader来创建动态地面、环境效果和视觉反馈，减少对静态贴图的依赖。
5.  **信号驱动**：新创建的`ChapterVisualManager`将监听`ChapterManager`发出的信号（如`chapter_started`），并据此切换场景的视觉元素（如地面Shader、环境粒子、背景等）。

---

## 1. 全局资产管线：从AI到Godot

所有章节的场景资产都遵循统一的管线：

1.  **AI生成**：使用《场景美术落地指南》中提供的Prompt，通过NanoBanana等AI工具生成带有`#00FF00`纯绿幕背景的`.png`格式原始资产。
2.  **批量抠图**：使用自动化脚本（如Python的`rembg`库或ImageMagick命令行工具）对所有原始资产进行批量处理，去除绿幕背景，生成具有透明通道的最终资产。
    ```bash
    # 示例：使用rembg批量处理
    rembg p /path/to/raw_assets /path/to/final_assets
    ```
3.  **资产组织**：在`Assets/Scene/`目录下，为每个章节创建独立的子目录（如`Ch1_Pythagoras/`），并将处理后的资产存入其中。
4.  **引擎导入**：将最终资产导入Godot项目。对于需要平铺的背景或地面，需在导入设置中启用`Repeat`。

---

## 2. 第一章：律动尊者·毕达哥拉斯

### 2.1 场景构成 (Scene Tree)

```
- Chapter1 (Node2D)
  - Background (CanvasLayer, layer = -10)
    - WhiteNoiseBarrier (TextureRect, texture=Ch1_Noise_Barrier.png, layout_mode=anchors, anchors_preset=FULL_RECT, stretch_mode=TILE)
  - Ground (TextureRect, texture=Ch1_Chladni_Ground.png, material=new ShaderMaterial(shader=chladni_pattern.gdshader))
  - Pillars (Node2D)
    - Pillar1 (TextureRect, texture=Ch1_Light_Pillar.png)
    - Pillar2 (TextureRect, texture=Ch1_Light_Pillar.png)
    - ...
  - GameplayLayer (Node2D) # 玩家和敌人所在层
```

### 2.2 Shader与VFX实现

- **全局环境** (`WorldEnvironment`): Glow效果**必须开启**，强度(Intensity)设为`1.2`，阈值(Threshold)设为`0.8`，以突出光线感。
- **地面Shader** (`chladni_pattern.gdshader`): 基于现有的`pulsing_grid.gdshader`进行修改。核心是实现克拉尼图形的数学公式。该Shader需要接收来自`ChapterVisualManager`的uniforms，用于在不同波次间切换频率参数，改变图形的复杂性。
- **克拉尼图形机制实现**: `ChapterVisualManager`监听`wave_started`信号，根据`WaveData`中的定义，通过`set_shader_parameter`方法更新地面Shader的`frequency_x`和`frequency_y`等参数。同时，需要创建一个覆盖整个地面的`Area2D`，其碰撞形状由克拉尼图形的“安全区”程序化生成，用于判断玩家是否在安全区内。

### 2.3 地图机制代码逻辑

**`Chapter1_VisualManager.gd`**

```gdscript
# 伪代码
extends Node

@onready var ground = get_node("Ground")

func _ready():
    ChapterManager.wave_started.connect(_on_wave_started)

func _on_wave_started(wave_data):
    if wave_data.has("chladni_params"):
        var params = wave_data.chladni_params
        ground.material.set_shader_parameter("frequency_x", params.x)
        ground.material.set_shader_parameter("frequency_y", params.y)
        _update_safe_zone_collision(params) # 更新安全区的碰撞体
```

---

## 3. 第二章：圣咏宗师·圭多

### 3.1 场景构成 (Scene Tree)

```
- Chapter2 (Node2D)
  - Background (CanvasLayer, layer = -10)
    - RoseWindow (TextureRect, texture=Ch2_Rose_Window.png, material=new ShaderMaterial(shader=glow_pulse.gdshader))
  - Ground (TextureRect, texture=Ch2_Stone_Floor.png, material=new ShaderMaterial(shader=cathedral_floor.gdshader))
  - Altars (Node2D)
    - EchoAltar1 (Node2D)
      - Sprite (TextureRect, texture=Ch2_Altar.png)
      - ActivationArea (Area2D)
      - EchoPlayer (AudioStreamPlayer)
  - VFX (CanvasLayer, layer = 5)
    - VolumetricLight (Node2D) # 使用多个半透明拉伸的Light Texture模拟体积光
```

### 3.2 Shader与VFX实现

- **全局环境** (`WorldEnvironment`): 启用`VolumetricFog`（如果坚持2D，则用VFX节点模拟）。Glow效果保持开启。色彩校正(Color Correction)应偏向冷色调，增加蓝色和青色的饱和度。
- **地面Shader** (`cathedral_floor.gdshader`): 在石砖纹理基础上，叠加五线谱图案。五线谱的线条颜色和亮度可以通过`beat_energy` uniform进行驱动，实现随节拍的微弱脉动。
- **视觉回响**: `SpellVisualManager`需要增强。当`chord_cast`信号发出时，除了播放法术本身的视觉效果，还额外创建一个“回声”视觉效果：一个快速放大并淡出的、与和弦色彩一致的半透明圆环。

### 3.3 地图机制代码逻辑

**`EchoAltar.gd`**

```gdscript
# 伪代码
extends Node2D

@onready var activation_area = get_node("ActivationArea")
var last_chord = null
var is_active = false

func _ready():
    activation_area.body_entered.connect(_on_player_entered)
    SpellcraftSystem.chord_cast.connect(_on_chord_cast)

func _on_player_entered(body):
    if body.is_in_group("player"):
        # 玩家进入范围，准备记录和弦
        pass

func _on_chord_cast(chord_data):
    if is_active or get_global_mouse_position().distance_to(global_position) > activation_range:
        return

    # 记录和弦并进入激活状态
    is_active = true
    last_chord = chord_data
    $Sprite.material.set_shader_parameter("active", 1.0) # 播放激活视觉
    
    # 延迟后回响
    await get_tree().create_timer(2.0).timeout
    _play_echo(last_chord)
    is_active = false
    $Sprite.material.set_shader_parameter("active", 0.0)

func _play_echo(chord_data):
    # 在圣坛位置生成一个弱化版的和弦法术
    var echo_spell = SpellFactory.create_echo_spell(chord_data)
    echo_spell.global_position = global_position
    get_parent().add_child(echo_spell)
```


---

## 4. 第三章：大构建师·巴赫

### 4.1 场景构成 (Scene Tree)

本章需要实现伪3D的立体感，但仍在2D框架内。我们将使用Y-sort和缩放来模拟高度差。

```
- Chapter3 (Node2D)
  - Background (CanvasLayer, layer = -10)
    - MechanicalNetwork (TextureRect, texture=Ch3_Mechanical_Network.png, stretch_mode=TILE)
    - OrganPipes (TextureRect, texture=Ch3_Organ_Pipes.png)
  - GameplayLayer (Node2D)
    - YSort # 启用YSort以处理不同平台的高度遮挡
      - GearPlatform1 (Node2D)
        - Sprite (TextureRect, texture=Ch3_Gear_Platform.png)
        - Collision (CollisionPolygon2D)
      - GearPlatform2 (Node2D)
        - Sprite (TextureRect, texture=Ch3_Gear_Platform.png)
        - ...
      - Player (CharacterBody2D)
      - Enemies (Node2D)
```

### 4.2 Shader与VFX实现

- **全局环境**: 色彩校正应偏向暖色调，增加黄色和橙色的饱和度，模拟黄铜和蒸汽的光感。Glow效果用于提亮金属高光和蒸汽。
- **齿轮旋转**: `GearPlatform`节点的`Sprite`将通过脚本控制其`rotation`属性，转速与BPM同步。`ChapterVisualManager`负责协调所有齿轮的同步旋转。
- **立体感模拟**: 不同平台的`z_index`将根据其逻辑高度进行设置。当玩家或敌人在“较低”的平台时，其`scale`属性可以被微弱地缩小（例如0.95），以增强视觉上的深度感。

### 4.3 地图机制代码逻辑

**`Chapter3_VisualManager.gd`**

```gdscript
# 伪代码
extends Node

@onready var gear_platforms = get_node("GameplayLayer/YSort").get_children()

func _process(delta):
    var base_rotation_speed = BPMManager.get_bpm() / 60.0 * 0.1
    for platform in gear_platforms:
        platform.rotation += base_rotation_speed * platform.rotation_direction * delta

func _ready():
    SpellcraftSystem.chord_progression_success.connect(_on_progression_success)

func _on_progression_success(progression_type):
    # 根据和弦进行操控平台
    var player_platform = Player.get_current_platform()
    if progression_type == "D_T": # 属到主，稳定
        player_platform.apply_effect("lock_rotation", 2.0) # 锁定旋转2秒
    elif progression_type == "T_D": # 主到属，加速
        for platform in gear_platforms:
            if platform != player_platform:
                platform.apply_effect("speed_boost", 1.0)
```

---

## 5. 第四章：古典完形·莫扎特

### 5.1 场景构成 (Scene Tree)

```
- Chapter4 (Node2D)
  - Background (CanvasLayer, layer = -10)
    - Chandelier (TextureRect, texture=Ch4_Chandelier.png)
  - Ground (TextureRect, texture=Ch4_Marble_Floor.png, material=new ShaderMaterial(shader=marble_reflection.gdshader))
  - Walls (Node2D)
    - MirrorFrameLeft (TextureRect, texture=Ch4_Mirror_Frame.png)
    - MirrorFrameRight (TextureRect, texture=Ch4_Mirror_Frame.png)
  - GameplayLayer (Node2D)
    - SymmetryAxis (Line2D) # 视觉上的对称轴
```

### 5.2 Shader与VFX实现

- **全局环境**: 光线明亮，Glow效果的阈值(Threshold)应调低至`0.6`，以产生大范围的柔和辉光。Tonemap应使用`ACES`模式，以获得更电影感的色彩。
- **地面反射**: `marble_reflection.gdshader`需要模拟伪反射。这可以通过在Shader中对屏幕纹理(`SCREEN_TEXTURE`)进行垂直翻转和扭曲采样来实现，以模拟地面反射上方的弹幕和玩家。这是一个开销较大的效果，需要进行性能测试。
- **弹道反射**: 这不是一个视觉效果，而是游戏逻辑。`ProjectileManager`需要修改，当弹体运动到一个`Area2D`（代表对称轴）时，计算其入射角，然后以相同的角度创建一个新的反射弹体。

### 5.3 地图机制代码逻辑

**`SymmetryAxis.gd`**

```gdscript
# 伪代码
extends Area2D

func _ready():
    self.body_entered.connect(_on_projectile_entered)

func _on_projectile_entered(body):
    if body.is_in_group("projectiles"):
        var projectile = body
        
        # 仅反射单音弹体
        if projectile.is_complex_chord():
            return

        # 计算反射向量
        var reflect_vector = projectile.velocity.bounce(self.get_collision_normal())
        
        # 创建反射弹体
        var reflected_proj = ProjectileFactory.create_reflected(projectile, reflect_vector)
        get_parent().add_child(reflected_proj)
        
        # 销毁原弹体
        projectile.queue_free()
```


---

## 6. 第五章：狂想者·贝多芬

### 6.1 场景构成 (Scene Tree)

```
- Chapter5 (Node2D)
  - Background (CanvasLayer, layer = -10)
    - StormySky (TextureRect, texture=Ch5_Stormy_Sky.png, material=new ShaderMaterial(shader=sky_lightning.gdshader))
    - GothicRuin (TextureRect, texture=Ch5_Gothic_Ruin.png)
  - Ground (TextureRect, texture=Ch5_Cliff_Ground.png)
  - VFX (CanvasLayer, layer = 5)
    - Rain (GPUParticles2D, process_material=rain_material)
  - GameplayLayer (Node2D)
    - WaterPuddles (Node2D) # 水洼区域
      - Puddle1 (Area2D)
        - Sprite (TextureRect, material=new ShaderMaterial(shader=puddle.gdshader))
```

### 6.2 Shader与VFX实现

- **全局环境**: 动态调整是核心。`ChapterVisualManager`需要监听`BPMManager.bpm_changed`和`PlayerStats.unharmony_changed`信号，并实时更新`WorldEnvironment`的色彩校正参数。BPM升高，色调变暖；不和谐度升高，对比度增加，屏幕边缘出现暗角。
- **节奏性落雷**: `sky_lightning.gdshader`负责在背景天空绘制闪电。而真正的落雷伤害则由`ChapterVisualManager`实现。它会根据“命运动机”的节奏，在随机位置实例化一个“落雷”场景，该场景包含一个伤害区域和一个闪电动画。
- **导电水洼**: `puddle.gdshader`平时只渲染一个普通的水洼效果。当落雷击中其对应的`Area2D`时，`ChapterVisualManager`会调用该Shader的一个函数，激活其“导电”效果（例如，水面出现电弧动画），并使其在一段时间内对进入的玩家造成伤害。

### 6.3 地图机制代码逻辑

**`Chapter5_VisualManager.gd`**

```gdscript
# 伪代码
extends Node

var fate_motif_timer = 0.0

func _process(delta):
    # 命运雷暴计时器
    fate_motif_timer += delta
    if fate_motif_timer >= BEETHOVEN_FATE_MOTIF_INTERVAL:
        fate_motif_timer = 0.0
        _trigger_fate_lightning_sequence()

func _trigger_fate_lightning_sequence():
    # 短-短-短-长 节奏的落雷
    var timeline = get_tree().create_tween()
    timeline.tween_callback(func(): _spawn_lightning(Player.global_position + rand_offset()))
    timeline.tween_interval(0.2)
    timeline.tween_callback(func(): _spawn_lightning(Player.global_position + rand_offset()))
    timeline.tween_interval(0.2)
    timeline.tween_callback(func(): _spawn_lightning(Player.global_position + rand_offset()))
    timeline.tween_interval(0.4)
    timeline.tween_callback(func(): _spawn_lightning_large(Player.global_position))

func _on_unharmony_changed(new_value):
    var intensity = smoothstep(50.0, 100.0, new_value)
    WorldEnvironment.environment.adjustment_contrast = 1.0 + 0.5 * intensity
    # 增加落雷频率
    BEETHOVEN_FATE_MOTIF_INTERVAL = 10.0 - 5.0 * intensity
```

---

## 7. 第六章：摇摆公爵·艾灵顿

### 7.1 场景构成 (Scene Tree)

```
- Chapter6 (Node2D)
  - Background (CanvasLayer, layer = -10)
    - VelvetCurtain (TextureRect, texture=Ch6_Velvet_Curtain.png)
    - NeonSigns (Node2D)
      - NeonSwing (TextureRect, texture=Ch6_Neon_Sign_Swing.png)
  - Ground (TextureRect, material=new ShaderMaterial(shader=dance_floor.gdshader))
  - VFX (CanvasLayer, layer = 5)
    - VolumetricSmoke (GPUParticles2D, process_material=smoke_material)
  - GameplayLayer (Node2D)
    - Spotlight (SpotLight2D) # Godot 4.x 的 2D 灯光
```

### 7.2 Shader与VFX实现

- **全局环境**: 必须启用`WorldEnvironment`的`SDFGI`或`SSIL`（如果性能允许），或者使用2D灯光。`SpotLight2D`是本章的核心视觉元素。
- **摇摆聚光灯**: `Spotlight`的移动将由一个脚本控制，其运动轨迹不是线性的，而是带有“摇摆”节奏的缓入缓出曲线。可以使用`Tween`或`AnimationPlayer`来精心设计其路径。
- **相位指示**: `ChapterVisualManager`监听`Player.phase_changed`信号，并根据新的相位改变`Spotlight`的`color`属性。

### 7.3 地图机制代码逻辑

**`Chapter6_VisualManager.gd`**

```gdscript
# 伪代码
extends Node

@onready var spotlight = get_node("GameplayLayer/Spotlight")
var spotlight_target = null

func _process(delta):
    if spotlight_target:
        spotlight.global_position = spotlight.global_position.lerp(spotlight_target.global_position, delta * 2.0)
    else:
        # 随机游走
        pass

func _ready():
    # 定期选择一个高威胁敌人作为聚光灯目标
    get_tree().create_timer(5.0).timeout.connect(_select_spotlight_target)
    Player.phase_changed.connect(_on_phase_changed)

func _select_spotlight_target():
    var enemies = get_tree().get_nodes_in_group("enemies")
    spotlight_target = enemies.pick_random()

func _on_phase_changed(new_phase):
    if new_phase == "high_pass":
        spotlight.color = Color.BLUE
    elif new_phase == "low_pass":
        spotlight.color = Color.RED
    else:
        spotlight.color = Color.GOLD
```

---

## 8. 第七章：合成主脑·噪音

### 8.1 场景构成 (Scene Tree)

```
- Chapter7 (Node2D)
  - Background (CanvasLayer, layer = -10)
    - Codefall (TextureRect, material=new ShaderMaterial(shader=data_cascade.gdshader))
  - Ground (TextureRect, material=new ShaderMaterial(shader=spectrum_floor.gdshader))
  - VFX (CanvasLayer, layer = 10)
    - GlobalGlitch (ColorRect, material=new ShaderMaterial(shader=global_glitch.gdshader))
  - GameplayLayer (Node2D)
    - PhaseZones (Node2D)
      - HighPassZone (Area2D)
      - LowPassZone (Area2D)
```

### 8.2 Shader与VFX实现

- **全局故障**: `global_glitch.gdshader`是一个全屏后处理Shader，它会根据`ChapterVisualManager`传递的`corruption_level` uniform来增加色度偏移、像素错位和扫描线等效果的强度。
- **频谱地面**: `spectrum_floor.gdshader`的核心是FFT（快速傅里叶变换）的视觉模拟。它会接收一个包含当前音轨频谱数据的数组uniform，并据此实时更新柱状图的高度。
- **相位区域**: `PhaseZones`中的每个`Area2D`都代表一个相位区域。当玩家进入时，`ChapterVisualManager`会激活对应相位的全屏视觉效果（例如，进入`HighPassZone`时，激活强烈的蓝色滤镜和高频抖动效果）。

### 8.3 地图机制代码逻辑

**`Chapter7_VisualManager.gd`**

```gdscript
# 伪代码
extends Node

@onready var global_glitch_mat = get_node("VFX/GlobalGlitch").material

func _ready():
    for zone in get_node("GameplayLayer/PhaseZones").get_children():
        zone.body_entered.connect(Callable(self, "_on_player_enter_phase_zone").bind(zone.phase_type))
        zone.body_exited.connect(Callable(self, "_on_player_exit_phase_zone").bind(zone.phase_type))

func _on_player_enter_phase_zone(body, phase_type):
    if body.is_in_group("player"):
        global_glitch_mat.set_shader_parameter("current_phase", phase_type)
        Player.current_phase_zone = phase_type

func _on_player_exit_phase_zone(body, phase_type):
    if body.is_in_group("player") and Player.current_phase_zone == phase_type:
        global_glitch_mat.set_shader_parameter("current_phase", "none")
        Player.current_phase_zone = "none"

func _process(delta):
    # 实时更新频谱数据到地面Shader
    var spectrum_data = AudioManager.get_spectrum_data()
    get_node("Ground").material.set_shader_parameter("spectrum_data", spectrum_data)
```


---

## 9. 实施优先级与风险评估

### 9.1 实施优先级

以下表格按照"影响力/工作量"比值从高到低排列，建议按此顺序推进：

| 优先级 | 任务 | 影响力 | 工作量 | 理由 |
| :---: | :--- | :---: | :---: | :--- |
| **P0** | 启用`WorldEnvironment`后处理（Glow, Tonemap） | ★★★★★ | ★☆☆☆☆ | 一次性操作，立刻提升所有章节的视觉质量 |
| **P0** | 创建`ChapterVisualManager`框架 | ★★★★★ | ★★☆☆☆ | 所有章节差异化的基础设施 |
| **P1** | 实现第一章（克拉尼图形安全区） | ★★★★☆ | ★★☆☆☆ | 教程章节，玩家的第一印象 |
| **P1** | 实现第七章（频谱污染） | ★★★★☆ | ★★★★☆ | 最终Boss战的核心场景 |
| **P2** | 实现第五章（命运雷暴） | ★★★★☆ | ★★★☆☆ | 动态天气系统是高影响力的视觉特性 |
| **P2** | 实现第二章（回声圣坛） | ★★★☆☆ | ★★☆☆☆ | 机制相对简单，可快速实现 |
| **P3** | 实现第三章（对位齿轮平台） | ★★★☆☆ | ★★★★☆ | 伪3D的立体感实现有一定技术难度 |
| **P3** | 实现第四章（镜像对称轴） | ★★★☆☆ | ★★★☆☆ | 弹道反射逻辑需要仔细调试 |
| **P3** | 实现第六章（即兴聚光灯） | ★★★☆☆ | ★★☆☆☆ | 2D灯光系统的应用 |

### 9.2 风险评估

| 风险 | 可能性 | 影响 | 缓解策略 |
| :--- | :---: | :---: | :--- |
| **地面反射Shader性能不足**（第四章） | 中 | 高 | 使用预渲染的静态反射贴图替代实时反射 |
| **频谱数据传递延迟**（第七章） | 中 | 中 | 使用`AudioEffectSpectrumAnalyzer`的缓存数据 |
| **AI生成资产风格不一致** | 高 | 中 | 建立严格的Prompt模板和风格参考图库 |
| **绿幕抠图边缘问题** | 中 | 低 | 在Prompt中避免绿色元素；使用`rembg`等AI抠图工具 |
| **多平台旋转的碰撞体同步**（第三章） | 中 | 高 | 简化碰撞体为圆形；或使用`PhysicsServer2D`手动同步 |

---

## 参考文献

[1] `GDD.md` — 游戏核心设计文档
[2] `Docs/Scene_And_Art_Design.md` — 场景地图机制与美术风格设计文档
[3] `Docs/Art_And_VFX_Direction.md` — 美术与VFX方向总文档
[4] `Docs/ART_IMPLEMENTATION_FRAMEWORK.md` — 技术美术蓝图
[5] `Docs/关卡与Boss整合设计文档_v3.0.md` — 关卡与Boss整合设计文档
