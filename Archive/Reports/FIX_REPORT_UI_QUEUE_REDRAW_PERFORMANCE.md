# UI 重绘性能修复报告

## 任务信息
- **任务 ID**: tsk-836616fd-c34
- **仓库**: gdszyy/project-harmony-gdd
- **PR**: https://github.com/gdszyy/project-harmony-gdd/pull/134
- **分支**: fix/ui-queue-redraw-performance

## 问题描述

多个 UI 脚本在 `_process()` 中无条件调用 `queue_redraw()`，导致每帧重绘，造成性能浪费。

## 修复内容

### 1. 添加 `visible` 检查（12 个脚本）

以下脚本有持续动画（`_time` 驱动的 sin 波动、lerp 插值等），需要每帧重绘，但添加 `visible` 检查后可避免不可见时的无效重绘：

| 脚本 | 修复方式 |
|------|---------|
| `ammo_ring_hud.gd` | 添加 `if not visible: return` |
| `fatigue_meter.gd` | 添加 `if not visible: return` |
| `hp_bar.gd` | 添加 `if not visible: return` |
| `rhythm_indicator.gd` | 添加 `if not visible: return` |
| `phase_energy_bar.gd` | 添加 `if not visible: return` |
| `phase_indicator_ui.gd` | 添加 `if not visible: return` |
| `game_mechanics_panel.gd` | 添加 `if not visible: return` |
| `spectral_fatigue_indicator.gd` | 添加 `if not visible: return` |
| `manual_cast_slot.gd` | 添加 `if not visible: return` |
| `summon_hud.gd` | 添加 `if not visible: return` |
| `skill_node.gd` | 添加 `if not visible: return` |
| `hall_of_harmony.gd` | 添加 `if not visible: return` |

### 2. 改为条件触发重绘（3 个脚本）

| 脚本 | 修复方式 |
|------|---------|
| `dps_overlay.gd` | 仅在采样间隔（`SAMPLE_INTERVAL`）到达时触发 `queue_redraw()` |
| `sequencer_ui.gd` | 仅在 `_beat_flash > 0` 时重绘（节拍闪光衰减期间） |
| `phase_gain_hint.gd` | 仅在 `_is_visible` 或 `_beat_pulse > 0` 时重绘 |

### 3. 移除每帧无条件重绘（1 个脚本）

| 脚本 | 修复方式 |
|------|---------|
| `spellbook_panel_v3.gd` | 删除每帧 `queue_redraw()` 的 `_process` 函数，改为事件驱动 |

### 4. 修复缺失的 `queue_redraw` 调用（1 个脚本）

| 脚本 | 修复方式 |
|------|---------|
| `damage_number.gd` | 在 `_process` 末尾添加 `queue_redraw()` 以正确更新波纹和治疗粒子动画 |

## 已验证无需修改的脚本

以下脚本已有正确的条件保护：
- `chord_alchemy_panel_v3.gd` - 已有 `_craft_flash > 0` 条件
- `info_panel.gd` - 已有 `UPDATE_INTERVAL` 间隔条件
- `note_inventory_ui.gd` - 已有 `needs_redraw` 脏标记
- `run_results_screen.gd` - 已有 `_is_showing` 保护
- `status_notification.gd` - 已有 `_is_active` 保护
- `theory_breakthrough_popup.gd` - 已有 `_is_active` 保护
- `timbre_wheel_ui.gd` - 已有 `visible` 保护
- `circle_of_fifths_upgrade_v3.gd` - 已有 `_is_visible` 保护
- `meta_progression_visualizer.gd` - 已有 `_is_open` 保护
- `mode_selection_screen.gd` - 已有 `_is_open` 保护

## 关于 _draw() 中的 queue_redraw() 问题

经过代码审查，`test_chamber.gd` 和 `chord_alchemy_panel_v3.gd` 的 `_draw()` 函数中**不存在** `queue_redraw()` 调用，该问题已在之前的版本中修复或描述有误。

## 性能影响预估

- **修复前**：26 个 UI 脚本每帧都调用 `queue_redraw()`，即使 UI 不可见
- **修复后**：
  - 不可见的 UI 脚本完全跳过 `_process`，零开销
  - `dps_overlay.gd` 从每帧重绘降低到每 `SAMPLE_INTERVAL` 秒重绘一次
  - `sequencer_ui.gd` 仅在节拍闪光期间重绘
  - `spellbook_panel_v3.gd` 完全事件驱动，静止时零开销
