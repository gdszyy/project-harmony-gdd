# godot_project/scripts/autoload/resonance_slicing_manager.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 309 | 函数数: 21 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `Phase` | enum | `Phase()` |  |
| `phase_changed` | signal | `phase_changed(new_phase: Phase)` |  |
| `phase_energy_changed` | signal | `phase_energy_changed(current: float, maximum: float)` |  |
| `spectrum_offset_fatigue_changed` | signal | `spectrum_offset_fatigue_changed(value: float)` |  |
| `spectrum_corruption_triggered` | signal | `spectrum_corruption_triggered()` |  |
| `spectrum_corruption_cleared` | signal | `spectrum_corruption_cleared()` |  |
| `phase_switch_requested` | signal | `phase_switch_requested(from_phase: Phase, to_phase: Phase)` |  |
| `_ready` | function | `_ready()` |  |
| `_process` | function | `_process(delta: float)` |  |
| `switch_phase` | function | `switch_phase(target: Phase)` |  |
| `get_current_phase` | function | `get_current_phase()` |  |
| `get_phase_name` | function | `get_phase_name(phase: Phase)` |  |
| `get_phase_color` | function | `get_phase_color(phase: Phase)` |  |
| `get_current_modifiers` | function | `get_current_modifiers()` |  |
| `get_energy_ratio` | function | `get_energy_ratio()` |  |
| `can_switch_to` | function | `can_switch_to(target: Phase)` |  |
| `get_phase_gain_data` | function | `get_phase_gain_data(phase: Phase)` |  |
| `force_fundamental` | function | `force_fundamental()` |  |
| `_update_energy` | function | `_update_energy(delta: float)` |  |
| `_update_sof` | function | `_update_sof(delta: float)` |  |
| `_get_recovery_rate` | function | `_get_recovery_rate()` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/autoload/resonance_slicing_manager.gd
```
