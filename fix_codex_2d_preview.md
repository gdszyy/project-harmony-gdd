# Codex 敌人预览修复说明

## 问题描述

`codex_ui.gd` 中的 Codex 图鉴使用 3D 视口（`SubViewport` + `Camera3D` + `MeshInstance3D`）展示敌人预览，但游戏中所有敌人实际上是 2D 实现（`CharacterBody2D` + `Polygon2D` + 2D shader），导致 Codex 的预览视觉与游戏内实际视觉完全不一致。

## 调查结论

- **游戏定位**：纯 2D 俯视角（GDD.md 明确描述，主场景根节点为 `Node2D`，摄像机为 `Camera2D`）
- **玩家**：`CharacterBody2D`
- **所有敌人**：`CharacterBody2D` + `Polygon2D` + 2D shader（`enemy_glitch.gdshader` 等）
- **Codex 3D 预览**：使用 `BoxMesh`、`SphereMesh`、`CylinderMesh` 等 3D 几何体，与实际游戏视觉完全不同

## 修复内容

### 文件：`godot_project/scripts/ui/codex_ui.gd`

#### 1. 变量声明（第 138-142 行）
- `Camera3D` → `Camera2D`
- `Node3D` → `Node2D`
- 注释更新：`# 敌人 3D 预览节点` → `# 敌人 2D 预览节点`

#### 2. `_process` 函数（第 179-180 行）
- 旧：`_enemy_preview_model.rotation.y += delta * 1.5`（3D Y 轴旋转）
- 新：`_enemy_preview_model.rotation += delta * 0.8`（2D 旋转）

#### 3. 调用点（第 731-733 行）
- `_build_enemy_3d_preview(entry_id, entry)` → `_build_enemy_2d_preview(entry_id, entry)`

#### 4. 新增 `ENEMY_SCENE_PATHS` 常量（第 887-934 行）
映射所有 entry_id 到对应的 `.tscn` 场景路径（覆盖基础敌人、章节敌人、精英、Boss）

#### 5. 新函数 `_build_enemy_2d_preview`（第 937-993 行）
替换原有的 `_build_enemy_3d_preview`：
- 使用 `SubViewport` + `Camera2D` 替代 `SubViewport` + `Camera3D`
- 直接通过 `ResourceLoader.exists()` + `load()` + `instantiate()` 实例化敌人场景
- 禁用物理处理（`set_physics_process(false)`、`set_process(false)`）防止预览中的敌人移动
- 禁用碰撞层（`set_collision_layer(0)`、`set_collision_mask(0)`）防止影响游戏世界
- Boss 使用 `zoom = Vector2(2.5, 2.5)`，普通敌人使用 `zoom = Vector2(4.0, 4.0)`

#### 6. 新函数 `_add_fallback_preview`（第 995-1009 行）
当场景文件不存在时，显示带颜色的占位八边形（`Polygon2D`）

#### 7. 删除所有 3D 模型构建函数（原第 928-2522 行，共约 1594 行）
- `_create_enemy_3d_model`
- `_build_static_model`
- `_build_silence_model`
- `_build_screech_model`
- `_build_pulse_model`
- `_build_wall_model`
- `_build_boss_pythagoras_model`
- `_build_boss_guido_model`
- `_build_boss_bach_model`
- `_build_boss_mozart_model`
- `_build_boss_beethoven_model`
- `_create_chapter_enemy_model`（包含所有章节敌人和精英的 3D 模型）

## 修复效果

修复后，Codex 图鉴的敌人预览将直接展示游戏内实际使用的 `Polygon2D` + 2D shader 视觉效果，与游戏内战斗时看到的敌人外观完全一致。

## 文件行数变化

- 修复前：3979 行
- 修复后：2466 行
- 删除：约 1513 行（3D 模型构建代码）
- 新增：约 130 行（2D 预览实现 + ENEMY_SCENE_PATHS 常量）
