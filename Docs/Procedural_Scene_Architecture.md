# 《Project Harmony》程序化场景架构规范

**作者：** Manus AI
**版本：** 1.0
**日期：** 2026年2月12日

**关联文档：**
- [《程序化场景实现方案》](./Procedural_Scene_Implementation.md)（各章节逐层元素清单）
- [《技术美术蓝图》](./ART_IMPLEMENTATION_FRAMEWORK.md)（Shader体系与视觉管理器）
- [《美术与VFX方向》](./Art_And_VFX_Direction.md)（美术圣经）

---

## 目录

1. [核心设计哲学](#1-核心设计哲学无位图的程序化世界)
2. [2.5D场景分层架构](#2-25d场景分层架构)
3. [程序化元素放置与组合规范](#3-程序化元素放置与组合规范)
4. [场景树重构方案](#4-场景树重构方案)
5. [视差系统实现](#5-视差系统实现)
6. [程序化几何体生成器](#6-程序化几何体生成器)
7. [章节场景配置数据结构](#7-章节场景配置数据结构)
8. [ChapterSceneBuilder 核心实现](#8-chapterscenebuilder-核心实现)
9. [新增Shader清单与优先级](#9-新增shader清单与优先级)
10. [性能预算与优化策略](#10-性能预算与优化策略)
11. [与现有系统的衔接](#11-与现有系统的衔接)

---

## 1. 核心设计哲学：无位图的程序化世界

本文档是对此前《场景美术落地方案》的重大修订与深化，旨在彻底贯彻项目的核心美学——**"科幻神学 / 极简几何 / 故障艺术"**。我们在此确立一个根本性原则：

> **游戏内不应出现任何位图美术资源（贴图、精灵图）。所有的视觉元素，从宏大的背景到微小的粒子，都必须由代码、数学和Shader程序化生成。**

这一决策并非出于技术炫耀，而是基于对项目美学方向的深刻理解。项目的美术风格——极简几何、故障艺术、程序化纹理——天然地排斥位图。引入位图资源不仅会破坏风格的统一性，还会在"无限分辨率"和"动态响应性"两个维度上造成不可调和的矛盾。

**风格统一性**方面，纯程序化生成能确保所有视觉元素共享统一的"数字感"和"几何感"。当一个由数学公式生成的克拉尼图形地面与一个由`Polygon2D`顶点构成的几何体敌人同屏出现时，它们在视觉语言上是一致的。而如果引入一张手绘或AI生成的位图贴图，无论其质量多高，都会因为"像素化"和"有机感"而与周围的程序化元素产生割裂。

**无限分辨率**方面，程序化视觉在任何分辨率下都保持清晰锐利，没有像素化或纹理密度问题。这对于一款需要在不同分辨率的显示器上运行的PC游戏至关重要。

**动态响应性**方面，程序化元素可以轻易地与游戏状态（BPM、不和谐度、章节机制）深度绑定。一个Shader的`uniform`参数可以在每一帧被更新，使得"整个世界随音乐呼吸"的通感体验成为可能。位图则无法做到这一点。

---

## 2. 2.5D场景分层架构

为了在纯2D框架内实现丰富的深度感和层次感，我们采用一个基于`CanvasLayer`和`z_index`的**标准化七层模型**。这种结构将在`main_game.tscn`中由`ChapterSceneBuilder`统一管理。

| 层级 (Layer) | 节点类型 | z_index / layer | 用途与元素 | 视差系数 |
| :--- | :--- | :---: | :--- | :---: |
| **L-3: 天穹层 (Sky)** | `CanvasLayer` (layer=-3) | N/A | 宇宙背景、星空、极光等最远景的程序化Shader | 0.05 |
| **L-2: 远景层 (Far BG)** | `CanvasLayer` (layer=-2) | N/A | 远处的、巨大的几何结构剪影（如山脉、废墟、巨型钟摆） | 0.2 |
| **L-1: 中景层 (Mid BG)** | `CanvasLayer` (layer=-1) | N/A | 主要的环境装饰物，如浮动的几何体、旋转的齿轮、光柱 | 0.5 |
| **L0: 地面层 (Ground)** | `Node2D` (z_index=-10) | -10 | 玩家和敌人活动的核心平面，由`ColorRect`+`ShaderMaterial`构成 | 1.0 |
| **L0: 游戏层 (Gameplay)** | `Node2D` (z_index=0~99) | 0~99 | 玩家、敌人、弹体、可交互的场景机制 | 1.0 |
| **L1: 前景层 (Foreground)** | `CanvasLayer` (layer=1) | N/A | 靠近摄像机的环境元素，如飘过的粒子、屏幕边缘装饰 | 1.3 |
| **L2: VFX层 (VFX Overlay)** | `CanvasLayer` (layer=2) | N/A | 全屏覆盖性视觉效果：后处理Shader、章节过渡、全屏闪光 | N/A |

**关键设计决策：**

天穹层和远景层使用`CanvasLayer`而非`Node2D`的原因在于，`CanvasLayer`拥有独立的变换矩阵，不受`Camera2D`的影响。这使得我们可以通过手动控制其`offset`属性来实现精确的视差效果，而不需要将它们放在`Camera2D`的子树下。

地面层和游戏层共享同一个`CanvasLayer`（默认layer=0），通过`z_index`区分绘制顺序。这确保了地面Shader和游戏实体在同一坐标空间中，简化了碰撞检测和位置计算。

VFX层不参与视差，因为它的内容（全屏Shader效果）始终覆盖整个视口，不随摄像机移动。

---

## 3. 程序化元素放置与组合规范

场景的丰富度来自于在上述分层模型中，如何创造性地组合不同类型的程序化元素。所有元素都必须是以下三种类型之一。

### 3.1. 类型一：程序化几何体 (Procedural Geometry)

这是构成场景结构和装饰的基础。它们通过GDScript代码动态生成顶点数据，然后由`Polygon2D`或`Line2D`节点渲染。

**适用节点**为`Polygon2D`（用于填充形状，如齿轮、山脉剪影、建筑轮廓）和`Line2D`（用于线条元素，如光柱、数据流、螺旋线、网格线）。**形状生成**通过项目的工具类`ProceduralGeometry`（见第6节）或直接在`_draw()`函数中用数学公式生成`PackedVector2Array`。**材质**可以使用简单的`CanvasItemMaterial`（用于纯色填充加混合模式），或更复杂的`ShaderMaterial`来实现动态效果（如发光、故障、能量流动）。

### 3.2. 类型二：程序化着色器 (Procedural Shaders)

这是渲染大面积、复杂、动态背景的核心。它们通常应用于一个覆盖全屏（或覆盖整个层）的`ColorRect`节点上。

**适用节点**为`ColorRect` + `ShaderMaterial`。**Shader类型**为`canvas_item`。**核心技术**包括在Fragment Shader中使用`UV`、`TIME`（通过`global uniform float global_time`）、`beat_phase`等全局变量，结合噪声函数（Simplex/Value Noise）、分形算法、数学图案（克拉尼图形、玫瑰窗、卷草纹）来生成无限变化的视觉效果。

### 3.3. 类型三：程序化粒子 (Procedural Particles)

这是营造氛围和动态感的关键。它们使用`GPUParticles2D`，其所有参数（颜色、速度、大小、方向）都由代码或`ParticleProcessMaterial`控制，不依赖任何贴图。

**适用节点**为`GPUParticles2D`。**Process Material**为`ParticleProcessMaterial`。**核心技术**包括使用`color_ramp`（通过`GradientTexture1D`程序化生成）控制粒子生命周期内的颜色变化，使用`scale_curve`、`velocity_curve`等控制动态行为。

---

## 4. 场景树重构方案

以下是重构后的`main_game.tscn`节点树，整合了七层模型和现有的游戏系统：

```
MainGame (Node2D)
│
├── GlobalVisualEnvironment (Autoload, 不在场景树中显式存在)
│
├── SkyLayer (CanvasLayer, layer=-3)
│   └── SkyRect (ColorRect + ShaderMaterial)
│
├── FarBGLayer (CanvasLayer, layer=-2)
│   └── FarBGContainer (Node2D)
│       ├── [动态生成的 Polygon2D 剪影]
│       └── ...
│
├── MidBGLayer (CanvasLayer, layer=-1)
│   └── MidBGContainer (Node2D)
│       ├── [动态生成的 Polygon2D/Line2D 装饰]
│       ├── [GPUParticles2D 环境粒子]
│       └── ...
│
├── GroundShaderRect (ColorRect, z_index=-10)
│   └── ShaderMaterial (章节地面Shader)
│
├── EventHorizon (Node2D, z_index=-5)
│
├── Player (CharacterBody2D, z_index=10)
│   ├── PlayerVisual (Polygon2D)
│   ├── PlayerVisualEnhancer (Node)
│   ├── CollisionShape2D
│   ├── PickupArea (Area2D)
│   └── Camera2D
│
├── EnemySpawner (Node2D, z_index=5)
│
├── ProjectileManager (Node2D, z_index=15)
│   └── MultiMeshInstance2D
│
├── SpellVisualManager (Node2D, z_index=20)
│
├── DeathVFXManager (Node2D, z_index=25)
│
├── ForegroundLayer (CanvasLayer, layer=1)
│   └── ForegroundContainer (Node2D)
│       ├── [GPUParticles2D 前景粒子]
│       ├── [ColorRect + ShaderMaterial 前景效果]
│       └── ...
│
├── VFXOverlayLayer (CanvasLayer, layer=2)
│   ├── PostProcessRect (ColorRect + ShaderMaterial)
│   └── TransitionOverlay (ColorRect + ShaderMaterial)
│
├── ChapterSceneBuilder (Node)  ← 核心管理器
│
└── HUD (CanvasLayer, layer=10)
    └── ...
```

**与现有`ChapterVisualManager`的关系：** `ChapterSceneBuilder`是对现有`ChapterVisualManager`的扩展。`ChapterVisualManager`已经实现了地面Shader管理和环境VFX管理（中景层），`ChapterSceneBuilder`在此基础上增加了对天穹层、远景层、前景层和VFX覆盖层的管理，以及视差系统的驱动。两者可以合并为一个类，也可以保持`ChapterSceneBuilder`作为`ChapterVisualManager`的子节点。

---

## 5. 视差系统实现

视差系统是实现2.5D深度感的核心。它通过监听`Camera2D`的位置变化，以不同的系数移动各个`CanvasLayer`的`offset`属性。

```gdscript
## parallax_controller.gd
## 视差控制器
## 附加到 ChapterSceneBuilder 或作为独立 Autoload
class_name ParallaxController
extends Node

# ============================================================
# 配置
# ============================================================

## 各层的视差系数配置
const LAYER_PARALLAX: Dictionary = {
    "SkyLayer": 0.05,       # 天穹层几乎不动
    "FarBGLayer": 0.2,      # 远景层缓慢移动
    "MidBGLayer": 0.5,      # 中景层中速移动
    # 地面层和游戏层跟随摄像机 (1.0)，由 Camera2D 自动处理
    "ForegroundLayer": 1.3,  # 前景层比摄像机移动更快
}

# ============================================================
# 状态
# ============================================================
var _camera: Camera2D = null
var _layers: Dictionary = {}  # name -> CanvasLayer
var _last_camera_pos: Vector2 = Vector2.ZERO

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
    # 延迟一帧以确保场景树完全加载
    await get_tree().process_frame
    _find_camera()
    _find_layers()

func _process(_delta: float) -> void:
    if _camera == null:
        return

    var camera_pos: Vector2 = _camera.global_position
    var delta_pos: Vector2 = camera_pos - _last_camera_pos

    if delta_pos.length_squared() < 0.01:
        return

    for layer_name in _layers:
        var layer: CanvasLayer = _layers[layer_name]
        var factor: float = LAYER_PARALLAX.get(layer_name, 1.0)
        # CanvasLayer 的 offset 是相对于摄像机的偏移
        # 视差系数 < 1.0 的层需要"落后"于摄像机
        # 视差系数 > 1.0 的层需要"超前"于摄像机
        layer.offset = -camera_pos * (1.0 - factor)

    _last_camera_pos = camera_pos

# ============================================================
# 初始化
# ============================================================

func _find_camera() -> void:
    _camera = get_viewport().get_camera_2d()
    if _camera:
        _last_camera_pos = _camera.global_position

func _find_layers() -> void:
    for layer_name in LAYER_PARALLAX:
        var layer = get_node_or_null("/root/MainGame/" + layer_name)
        if layer and layer is CanvasLayer:
            _layers[layer_name] = layer
```

---

## 6. 程序化几何体生成器

为了避免在每个章节的场景构建代码中重复编写几何体生成逻辑，我们创建一个静态工具类`ProceduralGeometry`，提供所有章节共用的几何体生成函数。

```gdscript
## procedural_geometry.gd
## 程序化几何体生成器
## 提供各种几何形状的顶点生成函数
class_name ProceduralGeometry

# ============================================================
# 基础形状
# ============================================================

## 生成正多边形
static func create_regular_polygon(radius: float, sides: int) -> Polygon2D:
    var poly := Polygon2D.new()
    var points := PackedVector2Array()
    for i in sides:
        var angle := (TAU / sides) * i - PI / 2.0
        points.append(Vector2.from_angle(angle) * radius)
    poly.polygon = points
    return poly

## 生成齿轮形状（已存在于 ChapterVisualManager，提取为公共方法）
static func create_gear(radius: float, teeth: int) -> Polygon2D:
    var poly := Polygon2D.new()
    var points := PackedVector2Array()
    var inner_radius := radius * 0.7
    for i in range(teeth * 2):
        var angle := (TAU / (teeth * 2)) * i
        var r := radius if i % 2 == 0 else inner_radius
        points.append(Vector2.from_angle(angle) * r)
    poly.polygon = points
    return poly

## 生成星形
static func create_star(outer_radius: float, inner_radius: float,
                        points_count: int) -> Polygon2D:
    var poly := Polygon2D.new()
    var points := PackedVector2Array()
    for i in range(points_count * 2):
        var angle := (TAU / (points_count * 2)) * i - PI / 2.0
        var r := outer_radius if i % 2 == 0 else inner_radius
        points.append(Vector2.from_angle(angle) * r)
    poly.polygon = points
    return poly

# ============================================================
# 章节特化形状
# ============================================================

## 第一章：正多面体的2D投影（剪影）
static func create_polyhedron_silhouette(radius: float, complexity: int) -> Polygon2D:
    var poly := Polygon2D.new()
    var points := PackedVector2Array()
    # 使用不规则多边形模拟多面体的2D投影
    var base_sides := complexity + 5
    for i in base_sides:
        var angle := (TAU / base_sides) * i
        var r := radius * (0.8 + 0.2 * sin(angle * 3.0 + float(complexity)))
        points.append(Vector2.from_angle(angle) * r)
    poly.polygon = points
    return poly

## 第二章：哥特式尖拱
static func create_gothic_arch(width: float, height: float) -> Polygon2D:
    var poly := Polygon2D.new()
    var points := PackedVector2Array()
    var half_w := width * 0.5
    # 底部两个角
    points.append(Vector2(-half_w, 0))
    points.append(Vector2(-half_w, -height * 0.6))
    # 左侧弧线（用折线近似）
    for i in range(8):
        var t := float(i) / 7.0
        var angle := PI * 0.5 + t * PI * 0.5
        var x := -half_w + half_w * (1.0 - cos(angle))
        var y := -height * 0.6 - half_w * sin(angle) * 0.8
        points.append(Vector2(x, y))
    # 尖顶
    points.append(Vector2(0, -height))
    # 右侧弧线（镜像）
    for i in range(7, -1, -1):
        var t := float(i) / 7.0
        var angle := PI * 0.5 + t * PI * 0.5
        var x := half_w - half_w * (1.0 - cos(angle))
        var y := -height * 0.6 - half_w * sin(angle) * 0.8
        points.append(Vector2(x, y))
    points.append(Vector2(half_w, -height * 0.6))
    points.append(Vector2(half_w, 0))
    poly.polygon = points
    return poly

## 第五章：分形山脉轮廓
static func create_mountain_silhouette(width: float, max_height: float,
                                        detail: int) -> Polygon2D:
    var poly := Polygon2D.new()
    var points := PackedVector2Array()
    # 底部左角
    points.append(Vector2(-width * 0.5, 0))
    # 使用中点位移算法生成山脉轮廓
    var mountain_points: Array[float] = []
    var segments := 1 << detail  # 2^detail
    mountain_points.resize(segments + 1)
    mountain_points[0] = 0.0
    mountain_points[segments] = 0.0
    var displacement := max_height
    var step := segments
    while step > 1:
        var half_step := step / 2
        for i in range(half_step, segments, step):
            var avg := (mountain_points[i - half_step] + mountain_points[i + half_step]) * 0.5
            mountain_points[i] = avg + randf_range(-displacement, displacement)
        displacement *= 0.5
        step = half_step
    # 转换为顶点
    for i in range(segments + 1):
        var x := -width * 0.5 + width * float(i) / float(segments)
        var y := -abs(mountain_points[i])
        points.append(Vector2(x, y))
    # 底部右角
    points.append(Vector2(width * 0.5, 0))
    poly.polygon = points
    return poly

## 第六章：摩天大楼剪影
static func create_building_silhouette(width: float, height: float,
                                        window_rows: int) -> Polygon2D:
    var poly := Polygon2D.new()
    var points := PackedVector2Array()
    var half_w := width * 0.5
    # 简单的矩形建筑
    points.append(Vector2(-half_w, 0))
    points.append(Vector2(-half_w, -height))
    # 顶部可以有装饰（Art Deco 风格的阶梯状）
    points.append(Vector2(-half_w * 0.7, -height))
    points.append(Vector2(-half_w * 0.7, -height * 1.1))
    points.append(Vector2(-half_w * 0.3, -height * 1.1))
    points.append(Vector2(-half_w * 0.3, -height * 1.2))
    points.append(Vector2(half_w * 0.3, -height * 1.2))
    points.append(Vector2(half_w * 0.3, -height * 1.1))
    points.append(Vector2(half_w * 0.7, -height * 1.1))
    points.append(Vector2(half_w * 0.7, -height))
    points.append(Vector2(half_w, -height))
    points.append(Vector2(half_w, 0))
    poly.polygon = points
    return poly

# ============================================================
# Line2D 辅助
# ============================================================

## 生成黄金比例螺旋线
static func create_golden_spiral(turns: float, scale: float,
                                  segments: int) -> Line2D:
    var line := Line2D.new()
    var phi := (1.0 + sqrt(5.0)) / 2.0  # 黄金比例
    for i in range(segments + 1):
        var t := float(i) / float(segments) * turns * TAU
        var r := scale * pow(phi, t / (TAU * 0.5))
        line.add_point(Vector2(cos(t), sin(t)) * r)
    line.width = 2.0
    return line

## 生成正弦波线条
static func create_sine_wave(amplitude: float, frequency: float,
                              length: float, segments: int) -> Line2D:
    var line := Line2D.new()
    for i in range(segments + 1):
        var x := float(i) / float(segments) * length
        var y := sin(x * frequency) * amplitude
        line.add_point(Vector2(x - length * 0.5, y))
    line.width = 1.5
    return line
```

---

## 7. 章节场景配置数据结构

为了使场景构建过程数据驱动而非硬编码，我们定义一个`ChapterSceneConfig`资源类型，每个章节对应一个配置文件。

```gdscript
## chapter_scene_config.gd
## 章节场景配置资源
class_name ChapterSceneConfig
extends Resource

# ============================================================
# 天穹层配置
# ============================================================
@export var sky_shader_path: String = ""
@export var sky_primary_color: Color = Color.BLACK
@export var sky_secondary_color: Color = Color.BLACK

# ============================================================
# 远景层配置
# ============================================================
@export var far_bg_elements: Array[Dictionary] = []
# 每个元素的格式:
# {
#   "type": "polyhedron" | "arch" | "mountain" | "building" | "pendulum",
#   "count": int,
#   "size_range": Vector2(min, max),
#   "color": Color,
#   "alpha_range": Vector2(min, max),
#   "rotation_speed": float,  # 0 = 静态
#   "y_range": Vector2(min, max),
# }

# ============================================================
# 中景层配置
# ============================================================
@export var mid_bg_elements: Array[Dictionary] = []
# 格式同上，额外支持:
# {
#   "type": "gear" | "light_shaft" | "data_stream" | "particle",
#   "particle_config": Dictionary,  # 如果 type == "particle"
# }

# ============================================================
# 地面层配置
# ============================================================
@export var ground_shader_path: String = "res://shaders/pulsing_grid.gdshader"
@export var ground_primary_color: Color = Color.WHITE
@export var ground_secondary_color: Color = Color.GRAY
@export var ground_accent_color: Color = Color.WHITE

# ============================================================
# 前景层配置
# ============================================================
@export var foreground_shader_path: String = ""  # 可选的前景全屏Shader
@export var foreground_shader_params: Dictionary = {}
@export var foreground_particles: Array[Dictionary] = []

# ============================================================
# VFX覆盖层配置
# ============================================================
@export var post_process_shader_path: String = ""
@export var post_process_params: Dictionary = {}

# ============================================================
# 视差配置（可选覆盖默认值）
# ============================================================
@export var parallax_overrides: Dictionary = {}
```

---

## 8. ChapterSceneBuilder 核心实现

`ChapterSceneBuilder`是整个场景构建系统的核心。它消费`ChapterManager`发出的信号，读取`ChapterSceneConfig`配置，并调用`ProceduralGeometry`和Shader资源来填充各个层级。

```gdscript
## chapter_scene_builder.gd
## 章节场景构建器
## 负责根据章节配置，动态构建和切换场景的所有视觉层
class_name ChapterSceneBuilder
extends Node

# ============================================================
# 配置
# ============================================================

## 章节场景配置文件路径映射
const CHAPTER_CONFIGS: Dictionary = {
    0: "res://resources/scene_configs/ch1_pythagoras.tres",
    1: "res://resources/scene_configs/ch2_guido.tres",
    2: "res://resources/scene_configs/ch3_bach.tres",
    3: "res://resources/scene_configs/ch4_mozart.tres",
    4: "res://resources/scene_configs/ch5_beethoven.tres",
    5: "res://resources/scene_configs/ch6_ellington.tres",
    6: "res://resources/scene_configs/ch7_noise.tres",
}

# ============================================================
# 节点引用
# ============================================================
var _sky_layer: CanvasLayer
var _far_bg_layer: CanvasLayer
var _mid_bg_layer: CanvasLayer
var _foreground_layer: CanvasLayer
var _vfx_layer: CanvasLayer

var _sky_rect: ColorRect
var _ground_rect: ColorRect
var _post_process_rect: ColorRect
var _foreground_rect: ColorRect

var _far_bg_container: Node2D
var _mid_bg_container: Node2D
var _foreground_container: Node2D

var _current_config: ChapterSceneConfig = null
var _current_chapter: int = -1

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
    _cache_node_references()
    _connect_signals()

func _cache_node_references() -> void:
    var root = get_node("/root/MainGame")
    _sky_layer = root.get_node("SkyLayer")
    _far_bg_layer = root.get_node("FarBGLayer")
    _mid_bg_layer = root.get_node("MidBGLayer")
    _foreground_layer = root.get_node("ForegroundLayer")
    _vfx_layer = root.get_node("VFXOverlayLayer")

    _sky_rect = _sky_layer.get_node("SkyRect")
    _ground_rect = root.get_node("GroundShaderRect")
    _post_process_rect = _vfx_layer.get_node("PostProcessRect")
    _foreground_rect = _foreground_layer.get_node_or_null("ForegroundRect")

    _far_bg_container = _far_bg_layer.get_node("FarBGContainer")
    _mid_bg_container = _mid_bg_layer.get_node("MidBGContainer")
    _foreground_container = _foreground_layer.get_node("ForegroundContainer")

func _connect_signals() -> void:
    if ChapterManager.has_signal("chapter_started"):
        ChapterManager.chapter_started.connect(_on_chapter_started)

# ============================================================
# 章节切换
# ============================================================

func _on_chapter_started(chapter: int, _chapter_name: String) -> void:
    if _current_chapter == chapter:
        return
    _current_chapter = chapter
    _build_chapter_scene(chapter)

func _build_chapter_scene(chapter: int) -> void:
    var config_path: String = CHAPTER_CONFIGS.get(chapter, "")
    if config_path.is_empty():
        push_warning("ChapterSceneBuilder: No config for chapter %d" % chapter)
        return

    _current_config = load(config_path) as ChapterSceneConfig
    if _current_config == null:
        push_warning("ChapterSceneBuilder: Failed to load config: %s" % config_path)
        return

    # 清理所有动态生成的内容
    _clear_all_layers()

    # 逐层构建
    _build_sky_layer()
    _build_far_bg_layer()
    _build_mid_bg_layer()
    _build_ground_layer()
    _build_foreground_layer()
    _build_vfx_layer()

# ============================================================
# 各层构建
# ============================================================

func _build_sky_layer() -> void:
    if _current_config.sky_shader_path.is_empty():
        _sky_rect.visible = false
        return
    _sky_rect.visible = true
    var shader = load(_current_config.sky_shader_path)
    if shader:
        var mat := ShaderMaterial.new()
        mat.shader = shader
        mat.set_shader_parameter("primary_color", _current_config.sky_primary_color)
        mat.set_shader_parameter("secondary_color", _current_config.sky_secondary_color)
        _sky_rect.material = mat

func _build_far_bg_layer() -> void:
    for elem_config in _current_config.far_bg_elements:
        var count: int = elem_config.get("count", 1)
        for i in count:
            var node := _create_bg_element(elem_config)
            if node:
                _far_bg_container.add_child(node)

func _build_mid_bg_layer() -> void:
    for elem_config in _current_config.mid_bg_elements:
        var elem_type: String = elem_config.get("type", "")
        if elem_type == "particle":
            var particles := _create_particle_emitter(elem_config.get("particle_config", {}))
            if particles:
                _mid_bg_container.add_child(particles)
        else:
            var count: int = elem_config.get("count", 1)
            for i in count:
                var node := _create_bg_element(elem_config)
                if node:
                    _mid_bg_container.add_child(node)

func _build_ground_layer() -> void:
    var shader = load(_current_config.ground_shader_path)
    if shader:
        var mat := ShaderMaterial.new()
        mat.shader = shader
        mat.set_shader_parameter("primary_color", _current_config.ground_primary_color)
        mat.set_shader_parameter("secondary_color", _current_config.ground_secondary_color)
        mat.set_shader_parameter("accent_color", _current_config.ground_accent_color)
        _ground_rect.material = mat

func _build_foreground_layer() -> void:
    # 前景全屏Shader（如有）
    if not _current_config.foreground_shader_path.is_empty() and _foreground_rect:
        var shader = load(_current_config.foreground_shader_path)
        if shader:
            var mat := ShaderMaterial.new()
            mat.shader = shader
            for key in _current_config.foreground_shader_params:
                mat.set_shader_parameter(key, _current_config.foreground_shader_params[key])
            _foreground_rect.material = mat
            _foreground_rect.visible = true

    # 前景粒子
    for particle_config in _current_config.foreground_particles:
        var particles := _create_particle_emitter(particle_config)
        if particles:
            _foreground_container.add_child(particles)

func _build_vfx_layer() -> void:
    if _current_config.post_process_shader_path.is_empty():
        _post_process_rect.visible = false
        return
    _post_process_rect.visible = true
    var shader = load(_current_config.post_process_shader_path)
    if shader:
        var mat := ShaderMaterial.new()
        mat.shader = shader
        for key in _current_config.post_process_params:
            mat.set_shader_parameter(key, _current_config.post_process_params[key])
        _post_process_rect.material = mat

# ============================================================
# 元素工厂
# ============================================================

func _create_bg_element(config: Dictionary) -> Node2D:
    var elem_type: String = config.get("type", "")
    var size_range: Vector2 = config.get("size_range", Vector2(50, 200))
    var color: Color = config.get("color", Color(0.5, 0.5, 0.5, 0.2))
    var alpha_range: Vector2 = config.get("alpha_range", Vector2(0.05, 0.2))
    var rotation_speed: float = config.get("rotation_speed", 0.0)
    var y_range: Vector2 = config.get("y_range", Vector2(-400, 400))

    var size := randf_range(size_range.x, size_range.y)
    var node: Node2D = null

    match elem_type:
        "polyhedron":
            node = ProceduralGeometry.create_polyhedron_silhouette(size, randi_range(3, 8))
        "arch":
            node = ProceduralGeometry.create_gothic_arch(size, size * 2.0)
        "gear":
            node = ProceduralGeometry.create_gear(size, randi_range(8, 20))
        "mountain":
            node = ProceduralGeometry.create_mountain_silhouette(size * 4, size, 6)
        "building":
            node = ProceduralGeometry.create_building_silhouette(size, size * randf_range(2, 5), 8)
        "pendulum":
            node = _create_pendulum(size)
        "star":
            node = ProceduralGeometry.create_star(size, size * 0.4, randi_range(4, 8))
        _:
            node = ProceduralGeometry.create_regular_polygon(size, randi_range(3, 8))

    if node and node is Polygon2D:
        (node as Polygon2D).color = Color(color.r, color.g, color.b,
            randf_range(alpha_range.x, alpha_range.y))

    if node:
        node.position = Vector2(
            randf_range(-800, 800),
            randf_range(y_range.x, y_range.y)
        )
        # 如果有旋转速度，启动旋转动画
        if abs(rotation_speed) > 0.001:
            var direction := 1.0 if randf() > 0.5 else -1.0
            var tween := node.create_tween().set_loops()
            tween.tween_property(node, "rotation",
                node.rotation + TAU * direction,
                TAU / abs(rotation_speed))

    return node

func _create_pendulum(length: float) -> Node2D:
    var pivot := Node2D.new()
    var arm := Line2D.new()
    arm.add_point(Vector2.ZERO)
    arm.add_point(Vector2(0, length))
    arm.width = 3.0
    arm.default_color = Color(0.7, 0.5, 0.2, 0.15)
    pivot.add_child(arm)

    var bob := ProceduralGeometry.create_regular_polygon(length * 0.1, 12)
    bob.position = Vector2(0, length)
    bob.color = Color(0.7, 0.5, 0.2, 0.2)
    pivot.add_child(bob)

    # 钟摆动画（与BPM同步的简谐运动）
    var tween := pivot.create_tween().set_loops()
    var swing_angle := 0.3  # 约17度
    tween.tween_property(pivot, "rotation", swing_angle, 0.5).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(pivot, "rotation", -swing_angle, 1.0).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(pivot, "rotation", 0.0, 0.5).set_ease(Tween.EASE_IN_OUT)

    return pivot

func _create_particle_emitter(config: Dictionary) -> GPUParticles2D:
    var particles := GPUParticles2D.new()
    particles.amount = config.get("amount", 20)
    particles.lifetime = config.get("lifetime", 8.0)
    particles.preprocess = config.get("preprocess", 4.0)

    var mat := ParticleProcessMaterial.new()
    mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    var box_size: Vector3 = config.get("emission_box", Vector3(600, 400, 0))
    mat.emission_box_extents = box_size
    mat.direction = config.get("direction", Vector3(0, -1, 0))
    mat.spread = config.get("spread", 30.0)
    mat.initial_velocity_min = config.get("velocity_min", 5.0)
    mat.initial_velocity_max = config.get("velocity_max", 15.0)
    mat.gravity = config.get("gravity", Vector3.ZERO)
    mat.scale_min = config.get("scale_min", 0.5)
    mat.scale_max = config.get("scale_max", 2.0)
    mat.color = config.get("color", Color(0.9, 0.85, 0.6, 0.3))

    particles.process_material = mat
    return particles

# ============================================================
# 清理
# ============================================================

func _clear_all_layers() -> void:
    _clear_container(_far_bg_container)
    _clear_container(_mid_bg_container)
    _clear_container(_foreground_container)

func _clear_container(container: Node) -> void:
    if container == null:
        return
    for child in container.get_children():
        child.queue_free()
```

---

## 9. 新增Shader清单与优先级

以下是实现完整七层场景所需的新增Shader清单。已有的Shader（如克拉尼图形、玫瑰窗、数字矩阵地面Shader）不再重复列出。

| 优先级 | Shader名称 | 层级 | 章节 | 功能描述 |
| :---: | :--- | :--- | :--- | :--- |
| **P0** | `starfield_sky.gdshader` | 天穹层 | 第1章 | 程序化星空，噪声驱动的闪烁星星 |
| **P0** | `storm_clouds_sky.gdshader` | 天穹层 | 第5章 | 多层噪声云层，闪电效果 |
| **P0** | `digital_static_sky.gdshader` | 天穹层 | 第7章 | 数字静电噪声背景 |
| **P1** | `dark_vault_sky.gdshader` | 天穹层 | 第2章 | 幽暗穹顶渐变 |
| **P1** | `clockwork_sky.gdshader` | 天穹层 | 第3章 | 精密星图与网格 |
| **P1** | `chandelier_sky.gdshader` | 天穹层 | 第4章 | 水晶吊灯光晕 |
| **P1** | `art_deco_sky.gdshader` | 天穹层 | 第6章 | 装饰艺术几何图案 |
| **P1** | `baroque_scroll_ground.gdshader` | 地面层 | 第3章 | 巴洛克卷草纹地面 |
| **P1** | `crystal_floor_ground.gdshader` | 地面层 | 第4章 | 水晶/大理石地面 |
| **P1** | `turbulent_water_ground.gdshader` | 地面层 | 第5章 | 汹涌水面 |
| **P1** | `art_deco_floor_ground.gdshader` | 地面层 | 第6章 | Art Deco镶嵌舞池 |
| **P2** | `string_vibration_fg.gdshader` | 前景层 | 第1章 | 弦振波纹光晕 |
| **P2** | `chromatic_aberration_vfx.gdshader` | VFX层 | 第2章 | 色差后处理 |
| **P2** | `brass_tint_fg.gdshader` | 前景层 | 第3章 | 黄铜色调叠加 |
| **P2** | `lens_flare_fg.gdshader` | 前景层 | 第4章 | 六边形镜头光晕 |
| **P2** | `rain_on_lens_fg.gdshader` | 前景层 | 第5章 | 镜头雨滴效果 |
| **P2** | `film_grain_vfx.gdshader` | VFX层 | 第6章 | 老电影颗粒 |
| **P2** | `pixel_sort_vfx.gdshader` | VFX层 | 第7章 | 像素排序故障 |
| **P3** | `depth_of_field_vfx.gdshader` | VFX层 | 第3章 | 景深模糊 |
| **P3** | `saturation_boost_vfx.gdshader` | VFX层 | 第4章 | 饱和度提升 |
| **P3** | `dynamic_vignette_vfx.gdshader` | VFX层 | 第5章 | 情绪暗角 |
| **P3** | `screen_tear_vfx.gdshader` | VFX层 | 第7章 | 屏幕撕裂与块化 |

**总计新增Shader：** 21个。其中P0优先级3个（必须实现），P1优先级8个（核心体验），P2优先级7个（增强体验），P3优先级4个（锦上添花）。

---

## 10. 性能预算与优化策略

纯程序化场景的性能优势在于不需要纹理采样和纹理内存，但Fragment Shader的计算复杂度需要严格控制。

| 层级 | 性能预算 | 优化策略 |
| :--- | :--- | :--- |
| **天穹层** | ≤ 0.5ms/帧 | Shader复杂度控制在50行以内；使用`step()`替代`smoothstep()`减少计算 |
| **远景层** | ≤ 0.3ms/帧 | 几何体数量限制在10个以内；使用简单的纯色填充而非ShaderMaterial |
| **中景层** | ≤ 0.5ms/帧 | 几何体数量限制在20个以内；粒子数量限制在50个以内 |
| **地面层** | ≤ 1.0ms/帧 | 这是最复杂的Shader，允许更高的计算预算；但应避免多次纹理采样 |
| **前景层** | ≤ 0.3ms/帧 | 前景Shader应尽量简单；粒子数量限制在30个以内 |
| **VFX层** | ≤ 0.5ms/帧 | 后处理Shader应避免使用`SCREEN_TEXTURE`的多次采样 |
| **总计** | ≤ 3.1ms/帧 | 在60FPS下，总渲染预算为16.67ms，场景渲染占比约18.6% |

**关键优化手段：**

对于远景层和中景层的几何体，当它们完全位于视口之外时，应设置`visible = false`以跳过渲染。这可以通过`VisibleOnScreenNotifier2D`节点自动实现。

对于天穹层的Shader，由于它覆盖全屏且位于最底层，可以考虑降低其渲染分辨率（通过使用一个较小的`SubViewport`然后拉伸到全屏）来减少Fragment Shader的调用次数。

对于粒子系统，应优先使用`GPUParticles2D`而非`CPUParticles2D`，并确保粒子不使用自定义Shader（使用`ParticleProcessMaterial`的内置功能即可）。

---

## 11. 与现有系统的衔接

### 11.1. 与 ChapterVisualManager 的关系

`ChapterSceneBuilder`与现有的`ChapterVisualManager`（定义于《技术美术蓝图》第7节）存在功能重叠。建议的整合方案是将`ChapterSceneBuilder`作为`ChapterVisualManager`的**扩展模块**，而非替代品。

具体来说，`ChapterVisualManager`继续负责地面Shader的管理和章节过渡动画（这些功能已经实现），而`ChapterSceneBuilder`负责天穹层、远景层、中景层、前景层和VFX覆盖层的内容填充。两者共享同一个`chapter_started`信号。

### 11.2. 与 GlobalVisualEnvironment 的关系

`GlobalVisualEnvironment`（定义于《技术美术蓝图》第6节）负责全局的后处理效果（Bloom、Tonemap、Color Adjustment）。VFX覆盖层中的后处理Shader是对`GlobalVisualEnvironment`的**补充**，用于实现章节特化的后处理效果（如第2章的色差、第6章的胶片颗粒），而非替代全局后处理。

### 11.3. 与 ParallaxController 的关系

`ParallaxController`是一个独立的、轻量级的脚本，可以作为`ChapterSceneBuilder`的子节点存在。它不依赖于任何章节配置，只需要知道各个`CanvasLayer`的引用和它们的视差系数。

### 11.4. 信号流

```
ChapterManager.chapter_started(chapter, name)
    │
    ├──→ ChapterVisualManager._on_chapter_started()
    │       ├── 切换地面Shader
    │       ├── 清理/重建环境VFX（中景层粒子）
    │       └── 播放过渡动画
    │
    └──→ ChapterSceneBuilder._on_chapter_started()
            ├── 加载 ChapterSceneConfig
            ├── 构建天穹层
            ├── 构建远景层
            ├── 构建中景层（与 ChapterVisualManager 协调）
            ├── 构建前景层
            └── 构建VFX覆盖层
```

---

## 参考文献

[1] [Godot Engine Documentation - CanvasLayer](https://docs.godotengine.org/en/stable/classes/class_canvaslayer.html) — CanvasLayer节点的官方文档
[2] [Godot Engine Documentation - CanvasItem Shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/canvas_item_shader.html) — Canvas Item Shader参考
[3] [Godot Engine Documentation - GPUParticles2D](https://docs.godotengine.org/en/stable/classes/class_gpuparticles2d.html) — GPU粒子系统文档
[4] [Tech-Artists.Org - A game with no textures, all procedural shaders](https://www.tech-artists.org/t/a-game-with-no-textures-all-procedural-shaders/8603) — 纯程序化Shader游戏的先例
[5] [Geometry Wars Warping Grid](https://discussions.unity.com/t/vector-grid-geometry-wars-style-fluid-mesh-system/526991) — Geometry Wars风格的程序化网格系统
