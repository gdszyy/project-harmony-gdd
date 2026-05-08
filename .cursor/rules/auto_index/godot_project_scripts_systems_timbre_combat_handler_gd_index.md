# godot_project/scripts/systems/timbre_combat_handler.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 741 | 函数数: 40 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `climax_triggered` | signal | `climax_triggered(intensity: float)` |  |
| `organ_layers_changed` | signal | `organ_layers_changed(layers: int)` |  |
| `waveform_changed` | signal | `waveform_changed(new_waveform: int, old_waveform: int)` |  |
| `improvisation_state_changed` | signal | `improvisation_state_changed(is_active: bool)` |  |
| `WaveformType` | enum | `WaveformType()` |  |
| `_ready` | function | `_ready()` |  |
| `_process` | function | `_process(delta: float)` |  |
| `_reset_all_states` | function | `_reset_all_states()` |  |
| `_update_emotional_crescendo` | function | `_update_emotional_crescendo(delta: float)` |  |
| `_update_swing_attack` | function | `_update_swing_attack(delta: float)` |  |
| `_update_waveform_morph` | function | `_update_waveform_morph(delta: float)` |  |
| `_update_harmonic_stacking` | function | `_update_harmonic_stacking(delta: float)` |  |
| `on_player_attack` | function | `on_player_attack(timbre_type: int)` |  |
| `on_player_hurt` | function | `on_player_hurt()` |  |
| `switch_waveform` | function | `switch_waveform(new_waveform: WaveformType)` |  |
| `_trigger_climax` | function | `_trigger_climax()` |  |
| `apply_timbre_mechanics_to_spell` | function | `apply_timbre_mechanics_to_spell(spell_data: Dictionary, timbre_type: int)` |  |
| `_apply_lyre_mechanic` | function | `_apply_lyre_mechanic(spell_data: Dictionary)` |  |
| `_apply_organ_mechanic` | function | `_apply_organ_mechanic(spell_data: Dictionary)` |  |
| `_apply_harpsichord_mechanic` | function | `_apply_harpsichord_mechanic(spell_data: Dictionary)` |  |
| `_apply_fortepiano_mechanic` | function | `_apply_fortepiano_mechanic(spell_data: Dictionary)` |  |
| `_apply_tutti_mechanic` | function | `_apply_tutti_mechanic(spell_data: Dictionary)` |  |
| `_apply_saxophone_mechanic` | function | `_apply_saxophone_mechanic(spell_data: Dictionary)` |  |
| `_apply_synthesizer_mechanic` | function | `_apply_synthesizer_mechanic(spell_data: Dictionary)` |  |
| `_apply_waveform_stats` | function | `_apply_waveform_stats(spell_data: Dictionary, wave: WaveformType, bonus: float, penalty: float, params: Dictionary)` |  |
| `process_projectile_timbre_mechanics` | function | `process_projectile_timbre_mechanics(proj: Dictionary, delta: float, manager: Node)` |  |
| `_process_harpsichord_projectile` | function | `_process_harpsichord_projectile(proj: Dictionary, delta: float, manager: Node)` |  |
| `_process_lyre_projectile` | function | `_process_lyre_projectile(proj: Dictionary, _delta: float, _manager: Node)` |  |
| `process_hit_timbre_mechanics` | function | `process_hit_timbre_mechanics(proj: Dictionary, enemy_pos: Vector2, manager: Node)` |  |
| `_hit_lyre_mechanic` | function | `_hit_lyre_mechanic(proj: Dictionary, enemy_pos: Vector2, manager: Node)` |  |
| `_hit_organ_mechanic` | function | `_hit_organ_mechanic(proj: Dictionary, enemy_pos: Vector2, manager: Node)` |  |
| `_hit_harpsichord_mechanic` | function | `_hit_harpsichord_mechanic(proj: Dictionary, enemy_pos: Vector2, manager: Node)` |  |
| `_hit_fortepiano_mechanic` | function | `_hit_fortepiano_mechanic(proj: Dictionary, enemy_pos: Vector2, manager: Node)` |  |
| `_hit_tutti_mechanic` | function | `_hit_tutti_mechanic(proj: Dictionary, enemy_pos: Vector2, manager: Node)` |  |
| `get_emotional_intensity_normalized` | function | `get_emotional_intensity_normalized()` |  |
| `is_climax_active` | function | `is_climax_active()` |  |
| `is_improvising` | function | `is_improvising()` |  |
| `get_waveform_name` | function | `get_waveform_name()` |  |
| `get_organ_layers` | function | `get_organ_layers()` |  |
| `_get_mechanic_params` | function | `_get_mechanic_params(timbre: int)` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/systems/timbre_combat_handler.gd
```
