# 弹体不可见问题分析报告

## 问题描述

图鉴（Codex）中的法术演示区域能够正常显示弹体，但在测试场（Test Chamber）和实际游戏（Main Game）中，弹体完全不可见。

## 根因分析

经过对三个场景的完整代码审查，确认问题的**核心根因**是 **3D 弹幕渲染器 `ProjectileManager3D` 使用了 `QuadMesh`，而该 QuadMesh 在俯视正交摄像机下几乎不可见**。同时还存在 2D 弹体被 3D 覆盖层遮挡的次要问题。

### 根因 1（主要）：QuadMesh 朝向与俯视摄像机不兼容

**文件**: `scripts/systems/projectile_manager_3d.gd` 第 40-42 行

```gdscript
var quad := QuadMesh.new()
quad.size = Vector2(mesh_size, mesh_size)
mm.mesh = quad
```

在 Godot 4 中，`QuadMesh` 默认面向 **-Z 轴**（即位于 XY 平面上）。而 `RenderBridge3D` 的 3D 摄像机配置为：

```gdscript
_camera_3d.position = Vector3(0, camera_height, 0)
_camera_3d.rotation_degrees = Vector3(-90, 0, 0)  # 垂直俯视
```

摄像机沿 **-Y 轴**方向俯视，而 QuadMesh 的面法线指向 **-Z 轴**。这意味着摄像机的视线方向与 QuadMesh 的面**平行**——从俯视角度看，QuadMesh 只是一条无限细的线，几乎完全不可见。

**对比图鉴演示**：图鉴中使用的是 `SphereMesh`（球体），球体在任何角度都可见，因此演示正常。

### 根因 2（次要）：3D 覆盖层遮挡 2D 弹体

**文件**: `scripts/systems/render_bridge_3d.gd` 第 179-183 行

```gdscript
var overlay_layer := CanvasLayer.new()
overlay_layer.layer = 5  # 在 2D 游戏内容之上
overlay_layer.add_child(_viewport_container)
```

`ProjectileManager` 的 2D `MultiMeshInstance2D` 弹体渲染在默认 CanvasLayer 0 上，而 `RenderBridge3D` 的 3D 覆盖层在 CanvasLayer 5 上。虽然代码中已尝试使用 `BLEND_MODE_PREMULT_ALPHA` 来解决透明度问题，但 Glow 后处理会污染 SubViewport 的 alpha 通道（参见代码注释中提到的 Godot Issue #28141），导致 3D 覆盖层的"透明"区域实际上并不完全透明，从而遮挡了下层的 2D 弹体。

### 根因 3（辅助）：2D 弹体 Shader 的 blend_add 模式

**文件**: `shaders/projectile_glow.gdshader` 第 2 行

```glsl
render_mode blend_add;
```

`blend_add` 模式将弹体颜色与背景颜色相加。如果 3D 覆盖层的 Glow 后处理导致背景 alpha 异常（接近不透明），`blend_add` 的弹体颜色会被吞没，进一步加剧不可见问题。

## 渲染管线对比

| 特性 | 图鉴演示（正常） | 测试场/实际游戏（异常） |
|------|:---:|:---:|
| 3D 弹体几何体 | `SphereMesh`（球体） | `QuadMesh`（四边形面片） |
| 俯视可见性 | 球体任何角度可见 | QuadMesh 面向 -Z，俯视看到边缘 |
| 渲染环境 | 独立 SubViewport，不受其他层干扰 | 叠加在 2D 之上的 SubViewport |
| 2D 弹体渲染 | 不使用（纯 3D） | 被 3D overlay 层遮挡 |
| Glow 后处理 | 独立环境，不影响其他层 | 污染 alpha 通道，遮挡下层 |

## 修复方案

### 方案 A：修复 QuadMesh 朝向（推荐，最小改动）

在 `projectile_manager_3d.gd` 中将 QuadMesh 的朝向设置为面向 Y 轴（即放置在 XZ 平面上），使其在俯视摄像机下可见：

```gdscript
# projectile_manager_3d.gd - _setup_multimesh()
var quad := QuadMesh.new()
quad.size = Vector2(mesh_size, mesh_size)
quad.orientation = PlaneMesh.FACE_Y  # ★ 修复：面向Y轴，俯视可见
mm.mesh = quad
```

同时，在 `update_projectiles()` 中需要将旋转轴从 `Vector3.UP` 改为正确的轴，因为 QuadMesh 现在在 XZ 平面上：

```gdscript
# 旋转保持不变，因为 Vector3.UP 旋转在 XZ 平面上是正确的
var t = Transform3D()
t = t.rotated(Vector3.UP, -rot_2d)
t.origin = pos_3d
```

### 方案 B：替换为 PlaneMesh（替代方案）

将 QuadMesh 替换为 `PlaneMesh`，它默认就在 XZ 平面上（面向 Y 轴）：

```gdscript
var plane := PlaneMesh.new()
plane.size = Vector2(mesh_size, mesh_size)
mm.mesh = plane
```

### 方案 C：使用 SphereMesh（与图鉴一致）

如果希望与图鉴演示完全一致，可以使用低面数 SphereMesh：

```gdscript
var sphere := SphereMesh.new()
sphere.radius = mesh_size / 2.0
sphere.height = mesh_size
sphere.radial_segments = 8
sphere.rings = 4
mm.mesh = sphere
```

注意：SphereMesh 在 MultiMesh 中的性能开销略高于 QuadMesh/PlaneMesh，但对于 5000 个实例仍在可接受范围内。

### 补充修复：3D Shader 添加 billboard 模式（如果继续使用 QuadMesh）

在 `projectile_glow_3d.gdshader` 中添加 billboard 支持，确保 QuadMesh 始终面向摄像机：

```glsl
shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, cull_disabled;
// 注意：MultiMesh 不支持 shader 级别的 billboard，
// 需要在 CPU 端设置 Transform 或使用 FACE_Y orientation
```

## 推荐修复步骤

1. **修改 `projectile_manager_3d.gd`**：将 QuadMesh 设置 `orientation = PlaneMesh.FACE_Y`（方案 A）
2. **验证 3D 弹体在测试场中可见**
3. **（可选）调整 `render_bridge_3d.gd` 中 Glow 参数**：降低 `glow_bloom` 值以减少 alpha 通道污染
4. **（可选）在 `projectile_glow_3d.gdshader` 中添加 `cull_disabled`**：确保双面渲染
