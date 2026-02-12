# PERF-01: 不必要的持续重绘性能分析报告

**作者**: Manus AI
**日期**: 2026-02-12
**仓库**: `gdszyy/project-harmony-gdd`

## 1. 问题概述

验收报告指出，项目内存在【PERF-01】性能问题：多个UI组件在 `_process` 函数中无条件调用 `queue_redraw()`，导致了不必要的每帧重绘，增加了CPU和GPU的负担，尤其是在静态或无动画状态下。本报告旨在对该问题进行全面分析，并提供具体的优化方案。

## 2. 分析过程

### 2.1. 扫描 `queue_redraw()` 调用

首先，我们克隆了 `gdszyy/project-harmony-gdd` 仓库，并对所有 `.gd` 脚本文件进行了扫描，以定位 `queue_redraw()` 的调用位置。

- **总调用次数**: 88次
- **涉及文件总数**: 36个
- **排除 `archive` 目录后**: 30个活跃UI文件

### 2.2. 定位 `_process` 中的无条件调用

通过对脚本的深入分析，我们识别出在 `_process` 函数中直接或间接进行无条件 `queue_redraw()` 调用的文件。这些是性能问题的主要来源。分析发现，许多UI组件为了实现动态效果（如呼吸灯、粒子、平滑插值）而采取了每帧重绘的策略。

## 3. 调用点分类与分析

我们将存在问题的UI组件分为两类：**持续动画类** 和 **事件驱动/条件动画类**。

### 3.1. 类别A：持续动画组件

这类组件包含在可见时需要持续播放的动画效果，例如背景星云、呼吸灯、节拍指示器等。对于这类组件，每帧重绘是实现其设计效果所必需的。然而，关键的优化点在于确保它们**仅在可见时**才进行重绘。

| 文件名                             | _process 中的动画逻辑                                                              | 优化建议                                                                 |
| ---------------------------------- | ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| `hall_of_harmony.gd`               | 背景星空、星云旋转、星座闪烁 (`_time`驱动)                                           | 已经有子屏幕激活判断，但缺少根节点可见性判断。应添加 `is_visible_in_tree()` 守卫。 |
| `circle_of_fifths_upgrade_v3.gd`   | 指针旋转、卡片出现、符文脉冲、星云旋转等多种复杂动画                                 | 已有 `_is_visible` 守卫，符合最佳实践。                                    |
| `spectral_fatigue_indicator.gd`    | 抖动、破碎、数值平滑插值 (`lerp`)                                                    | 无可见性守卫。应添加 `is_visible_in_tree()` 守卫。                         |
| `summon_hud.gd`                    | 卡片进入/离开的平滑动画 (`lerp`)                                                     | 动画状态机驱动，但应在 `_process` 开头添加 `is_visible_in_tree()` 守卫。   |
| `rhythm_indicator.gd`              | 节拍进度、闪烁、冲击波扩散                                                         | 无可见性守卫。应添加 `is_visible_in_tree()` 守卫。                         |
| `phase_indicator_ui.gd`            | 扇区进度/缩放插值、光弧动画                                                        | 无可见性守卫。应添加 `is_visible_in_tree()` 守卫。                         |
| `hp_bar.gd` / `fatigue_meter.gd`   | 数值平滑插值 (`lerp`)、节拍脉冲衰减                                                  | 无可见性守卫。应添加 `is_visible_in_tree()` 守卫。                         |
| `phase_energy_bar.gd`              | 数值平滑插值、粒子效果                                                             | 无可见性守卫。应添加 `is_visible_in_tree()` 守卫。                         |
| `ammo_ring_hud.gd`                 | 依赖 `GameManager` 的节拍进度实时更新                                                | 无可见性守卫。应添加 `is_visible_in_tree()` 守卫。                         |

### 3.2. 类别B：事件驱动/条件动画组件

这类组件的重绘需求是**间歇性**的，仅在特定事件（如鼠标悬停、数据更新）发生或短暂动画（如闪烁、淡入淡出）播放时才需要。对它们使用每帧无条件重绘是极大的浪费。**脏标记（Dirty Flag）机制**是解决此类问题的理想方案。

| 文件名                      | _process 中的调用逻辑                               | 优化建议                                                                                             |
| --------------------------- | --------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `sequencer_ui.gd`           | `_beat_flash` 闪烁衰减                              | 引入脏标记。仅在 `_beat_flash > 0` 时重绘。                                                          |
| `skill_node.gd`             | `_unlock_progress` 动画, `_error_flash` 闪烁衰减    | 引入脏标记。仅在动画或闪烁激活时重绘。                                                               |
| `spellbook_panel_v3.gd`     | 仅在可见时调用                                      | 逻辑正确，但仍可优化。引入脏标记，仅在内容变化（如悬停、拖拽）时重绘，而不是可见就一直重绘。         |
| `timbre_wheel_ui.gd`        | `_open_progress` 开合动画, `_wind_flash_timer` 闪烁 | 引入脏标记。仅在 `_open_progress` 处于 (0, 1) 区间或 `_wind_flash_timer > 0` 时重绘。                |
| `info_panel.gd`             | 定时器 `UPDATE_INTERVAL` 触发                       | 逻辑正确，已经是条件调用，无需修改。                                                                   |
| `dps_overlay.gd`            | 定时器 `SAMPLE_INTERVAL` 触发                       | 逻辑正确，已经是条件调用，无需修改。                                                                   |
| `note_inventory_ui.gd`      | `_flash_timers` 闪烁衰减                            | 已实现 `needs_redraw` 脏标记，是项目中的优秀实践案例，可作为其他组件改造的参考。                 |
| `chord_alchemy_panel_v3.gd` | `_craft_flash` 闪烁衰减                             | 引入脏标记。仅在 `_craft_flash > 0` 时重绘。其他由事件触发的调用（如悬停）也应设置脏标记。         |

## 4. 优化方案：引入脏标记机制

脏标记机制是优化UI重绘性能的核心策略。其基本思想是：

1.  在脚本中增加一个布尔成员变量，例如 `var _is_dirty := false`。
2.  将所有直接调用 `queue_redraw()` 的地方，替换为 `_is_dirty = true`。
3.  在 `_process(delta)` 函数的末尾，加入以下逻辑：

    ```gdscript
    if _is_dirty:
        queue_redraw()
        _is_dirty = false
    ```

### 4.1. 状态变化与重绘触发器

以下状态和事件应该触发重绘（即设置 `_is_dirty = true`）：

- **数据更新**: 当UI依赖的数据发生变化时，例如 `refresh()` 函数被调用，或从 `GameManager` 收到信号后更新了内部状态。
- **用户交互**: 
  - `_gui_input` 中处理了点击、按压等事件。
  - `_update_hover` 检测到鼠标悬停在不同元素上。
  - `_get_drag_data`, `_can_drop_data`, `_drop_data` 等拖放操作的不同阶段。
- **动画生命周期**: 
  - 动画开始时（例如，一个闪烁效果被触发，`_flash_timer = 1.0`）。
  - 在 `_process` 中，如果一个持续的动画正在进行（例如 `_open_progress > 0 and _open_progress < 1.0`），则每一帧都应设置为 `true`。
  - 动画结束时，确保最后一次重绘以展示最终状态。
- **可见性变更**: 在 `show()` 或 `open()` 方法中设置脏标记，以确保UI显示时是最新状态。

### 4.2. 具体实施方案

#### 步骤1：实现一个可复用的 `DirtyNotifier` 节点 (可选，但推荐)

为了避免在每个文件中重复实现脏标记逻辑，可以创建一个 `DirtyNotifier.gd` 脚本，并将其附加到一个 `Node` 上。这个节点可以通过信号将其父节点标记为“脏”。

```gdscript
# DirtyNotifier.gd
class_name DirtyNotifier
extends Node

signal dirty

func notify() -> void:
    dirty.emit()
```

在父UI组件中：

```gdscript
# parent_ui.gd
func _ready() -> void:
    $DirtyNotifier.dirty.connect(func(): _is_dirty = true)

func some_state_change() -> void:
    # ... 改变状态 ...
    $DirtyNotifier.notify()
```

#### 步骤2：改造目标脚本

以 `sequencer_ui.gd` 为例：

**修改前:**
```gdscript
func _process(delta: float) -> void:
    _beat_flash = max(0.0, _beat_flash - delta * 4.0)
    queue_redraw()
```

**修改后:**
```gdscript
var _is_dirty := false

func _ready() -> void:
    # ...
    # 将所有 queue_redraw() 的地方改为 _is_dirty = true

func _process(delta: float) -> void:
    if _beat_flash > 0:
        _beat_flash = max(0.0, _beat_flash - delta * 4.0)
        _is_dirty = true # 仅在动画进行时标记

    if _is_dirty:
        queue_redraw()
        _is_dirty = false

# 在其他函数中，如 _update_hover, _drop_data 等
func _update_hover(pos: Vector2) -> void:
    # ... 逻辑 ...
    _is_dirty = true
```

#### 步骤3：全面应用

对所有在 **3.2. 类别B** 中列出的文件，以及部分 **类别A** 中可以进一步优化的文件（如 `spellbook_panel_v3.gd`），应用脏标记机制。

对于纯粹的持续动画组件（如 `hall_of_harmony.gd`），主要任务是添加严格的 `is_visible_in_tree()` 检查，这是最简单有效的优化。

## 5. 结论与建议

`PERF-01` 问题普遍存在于项目的UI模块中，但通过系统性的分析和重构，可以显著降低不必要的渲染开销。

- **核心策略**: 区分**持续动画**和**事件驱动**的UI，分别采用**可见性守卫**和**脏标记**机制进行优化。
- **推荐实践**: `note_inventory_ui.gd` 中已有的 `needs_redraw` 变量是脏标记的一个优秀实现，可以作为全项目重构的参考标准。
- **后续步骤**: 建议开发团队根据本报告提供的分析和方案，对相关UI组件进行逐一修改和测试，以验证性能提升效果。
