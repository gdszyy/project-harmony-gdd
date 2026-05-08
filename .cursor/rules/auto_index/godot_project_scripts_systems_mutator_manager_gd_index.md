# godot_project/scripts/systems/mutator_manager.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 519 | 函数数: 33 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `mutators_selected` | signal | `mutators_selected(mutator_ids: Array)` |  |
| `mutator_activated` | signal | `mutator_activated(mutator_id: String)` |  |
| `mutator_deactivated` | signal | `mutator_deactivated(mutator_id: String)` |  |
| `all_mutators_cleared` | signal | `all_mutators_cleared()` |  |
| `MutatorType` | enum | `MutatorType()` | 巨型函数 |
| `_ready` | function | `_ready()` |  |
| `_process` | function | `_process(delta: float)` |  |
| `roll_mutators` | function | `roll_mutators()` |  |
| `activate_mutator` | function | `activate_mutator(mutator_id: String)` |  |
| `deactivate_mutator` | function | `deactivate_mutator(mutator_id: String)` |  |
| `clear_all_mutators` | function | `clear_all_mutators()` |  |
| `get_active_mutators` | function | `get_active_mutators()` |  |
| `get_active_mutator_ids` | function | `get_active_mutator_ids()` |  |
| `get_mutator_info` | function | `get_mutator_info(mutator_id: String)` |  |
| `is_mutator_active` | function | `is_mutator_active(mutator_id: String)` |  |
| `get_enemy_hp_multiplier` | function | `get_enemy_hp_multiplier()` |  |
| `get_enemy_speed_multiplier` | function | `get_enemy_speed_multiplier()` |  |
| `get_enemy_damage_multiplier` | function | `get_enemy_damage_multiplier()` |  |
| `get_spawn_rate_multiplier` | function | `get_spawn_rate_multiplier()` |  |
| `get_wave_interval_multiplier` | function | `get_wave_interval_multiplier()` |  |
| `get_note_drop_multiplier` | function | `get_note_drop_multiplier()` |  |
| `get_xp_gain_multiplier` | function | `get_xp_gain_multiplier()` |  |
| `get_fatigue_rate_multiplier` | function | `get_fatigue_rate_multiplier()` |  |
| `get_fatigue_decay_multiplier` | function | `get_fatigue_decay_multiplier()` |  |
| `enemies_have_shield` | function | `enemies_have_shield()` |  |
| `get_dissonance_damage_multiplier` | function | `get_dissonance_damage_multiplier()` |  |
| `get_consonance_damage_multiplier` | function | `get_consonance_damage_multiplier()` |  |
| `get_player_damage_scaling_per_min` | function | `get_player_damage_scaling_per_min()` |  |
| `get_enemy_hp_scaling_per_min` | function | `get_enemy_hp_scaling_per_min()` |  |
| `_process_active_mutators` | function | `_process_active_mutators(delta: float)` |  |
| `_process_bpm_fluctuation` | function | `_process_bpm_fluctuation(delta: float)` |  |
| `_has_effect` | function | `_has_effect(effect_key: String)` |  |
| `_weighted_random_select` | function | `_weighted_random_select(available_ids: Array)` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/systems/mutator_manager.gd
```
