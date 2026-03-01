# TutorialHintManager 路径断裂修复报告

## 任务信息

- **任务 ID**: tsk-cad66928-e2f（对应 Hub 任务 tsk-7fadf4f5-0c4）
- **仓库**: gdszyy/project-harmony-gdd
- **PR**: [#132](https://github.com/gdszyy/project-harmony-gdd/pull/132)
- **分支**: `fix/tutorial-hint-manager-autoload`
- **完成时间**: 2026-03-01

## 问题描述

TutorialHintManager 未注册为 Autoload，但有 10 处代码通过 `/root/TutorialHintManager` 访问它，全部返回 `null`。

同时，`main_game.tscn` 在 HUD 子节点下有一个 TutorialHintManager 实例（通过 `tutorial_hint.tscn` 场景实例化），路径为 `/root/MainGame/HUD/TutorialHintManager`，与代码期望的 `/root/TutorialHintManager` 不匹配。

## 根本原因分析

| 问题 | 详情 |
|------|------|
| 缺少 Autoload 注册 | `project.godot` 的 `[autoload]` 段未包含 `TutorialHintManager` |
| 路径不匹配 | 代码期望 `/root/TutorialHintManager`，但节点实际在 `/root/MainGame/HUD/TutorialHintManager` |
| 重复实例化风险 | `main_game.tscn` 中存在场景实例，若同时注册 Autoload 会导致双重实例 |

## 修复内容

### 文件 1：`godot_project/project.godot`

在 `[autoload]` 段末尾添加：

```ini
TutorialHintManager="*res://scripts/ui/tutorial_hint_manager.gd"
```

**说明**：使用 `*` 前缀表示启用该 Autoload（Godot 4 格式）。脚本路径为 `res://scripts/ui/tutorial_hint_manager.gd`，该脚本 `extends CanvasLayer`，在 `_ready()` 中设置 `layer = 100` 并创建所有 UI 元素。

### 文件 2：`godot_project/scenes/main_game.tscn`

1. 移除 `ext_resource` 定义：
   ```
   [ext_resource type="PackedScene" uid="uid://tutorial_hint_001" path="res://scenes/ui/tutorial_hint.tscn" id="37_tutorial"]
   ```

2. 移除节点实例：
   ```
   [node name="TutorialHintManager" parent="HUD" instance=ExtResource("37_tutorial")]
   ```

3. 更新 `load_steps` 从 `45` 到 `44`

## 受益代码（10 处访问点）

| 文件 | 行号 | 访问次数 |
|------|------|---------|
| `scripts/entities/enemies/bosses/boss_pythagoras.gd` | 479, 709, 1029 | 3 |
| `scripts/systems/enemy_spawner.gd` | 492, 501, 523 | 3 |
| `scripts/systems/mutator_manager.gd` | 300 | 1 |
| `scripts/systems/timed_milestone_manager.gd` | 240 | 1 |
| `scripts/systems/tutorial_manager.gd` | 193 | 1 |
| `scripts/ui/tutorial_sequence.gd` | 517 | 1 |

## 验证结果

- `project.godot` 中 `TutorialHintManager` Autoload 注册：✅
- `main_game.tscn` 中重复节点已移除：✅
- 所有 10 处 `/root/TutorialHintManager` 路径访问代码无需修改：✅（注册 Autoload 后路径自动有效）
- PR 已创建并推送：✅ [PR #132](https://github.com/gdszyy/project-harmony-gdd/pull/132)

## 技术说明

在 Godot 4 中，当一个脚本被注册为 Autoload 时：
1. 引擎在启动时自动实例化该脚本（作为 Node）
2. 将其挂载到场景树根节点 `/root/` 下
3. 节点名称即为 `project.godot` 中定义的键名（本例为 `TutorialHintManager`）
4. 所有代码可通过 `get_node("/root/TutorialHintManager")` 或 `TutorialHintManager`（全局引用）访问

`tutorial_hint_manager.gd` 中的 `@export` 变量默认值与 `tutorial_hint.tscn` 中设置的值完全一致，因此直接使用脚本注册 Autoload 不会导致行为差异。
