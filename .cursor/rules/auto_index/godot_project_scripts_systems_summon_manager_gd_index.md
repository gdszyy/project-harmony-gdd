# godot_project/scripts/systems/summon_manager.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 985 | 函数数: 48 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `summon_created` | signal | `summon_created(summon_data: Dictionary)` |  |
| `summon_expired` | signal | `summon_expired(summon_id: int)` |  |
| `summon_attacked` | signal | `summon_attacked(summon_id: int, target_pos: Vector2)` |  |
| `resonance_activated` | signal | `resonance_activated(bonus: float)` |  |
| `summon_limit_reached` | signal | `summon_limit_reached()` |  |
| `SummonType` | enum | `SummonType()` |  |
| `_ready` | function | `_ready()` |  |
| `_process` | function | `_process(delta: float)` |  |
| `_on_chord_cast` | function | `_on_chord_cast(chord_data: Dictionary)` |  |
| `create_summon` | function | `create_summon(chord_data: Dictionary)` |  |
| `_determine_summon_type` | function | `_determine_summon_type(chord_data: Dictionary)` |  |
| `_create_summon_visual` | function | `_create_summon_visual(summon: Dictionary)` |  |
| `_update_summons` | function | `_update_summons(delta: float)` |  |
| `_update_accompaniment` | function | `_update_accompaniment(summon: Dictionary, delta: float)` |  |
| `_summon_auto_attack` | function | `_summon_auto_attack(summon: Dictionary)` |  |
| `_update_resonance` | function | `_update_resonance(summon: Dictionary, delta: float)` |  |
| `_update_interference` | function | `_update_interference(summon: Dictionary, delta: float)` |  |
| `_update_rhythm` | function | `_update_rhythm(summon: Dictionary, delta: float)` |  |
| `_on_beat_tick` | function | `_on_beat_tick(_beat_index: int)` |  |
| `_rhythm_pulse` | function | `_rhythm_pulse(summon: Dictionary)` |  |
| `_update_resonance_bonus` | function | `_update_resonance_bonus()` |  |
| `get_resonance_bonus_at` | function | `get_resonance_bonus_at(pos: Vector2)` |  |
| `_update_summon_visual` | function | `_update_summon_visual(summon: Dictionary, delta: float)` |  |
| `_flash_summon` | function | `_flash_summon(summon: Dictionary)` |  |
| `_beat_pulse_visual` | function | `_beat_pulse_visual(summon: Dictionary)` |  |
| `_remove_summon` | function | `_remove_summon(summon_id: int)` |  |
| `_remove_oldest_summon` | function | `_remove_oldest_summon()` |  |
| `clear_all` | function | `clear_all()` |  |
| `_get_player_position` | function | `_get_player_position()` |  |
| `_find_nearest_enemy` | function | `_find_nearest_enemy(from_pos: Vector2, max_range: float = INF)` |  |
| `get_active_count` | function | `get_active_count()` |  |
| `get_active_summons_info` | function | `get_active_summons_info()` |  |
| `get_resonance_bonus` | function | `get_resonance_bonus()` |  |
| `reset` | function | `reset()` |  |
| `_midi_note_to_root_index` | function | `_midi_note_to_root_index(midi_note: int)` |  |
| `create_construct` | function | `create_construct(root_note_index: int, chord_data: Dictionary)` |  |
| `_calculate_construct_measures` | function | `_calculate_construct_measures(chord_data: Dictionary)` |  |
| `_apply_timbre_modifier_to_construct` | function | `_apply_timbre_modifier_to_construct(construct: Node2D, chord_data: Dictionary)` |  |
| `_update_construct_network` | function | `_update_construct_network()` |  |
| `_remove_oldest_construct` | function | `_remove_oldest_construct()` |  |
| `_on_construct_expired` | function | `_on_construct_expired(construct_id: int)` |  |
| `_on_construct_excited` | function | `_on_construct_excited(construct_id: int)` |  |
| `try_excite_construct` | function | `try_excite_construct(hit_position: Vector2)` |  |
| `clear_all_constructs` | function | `clear_all_constructs()` |  |
| `get_active_construct_count` | function | `get_active_construct_count()` |  |
| `get_active_constructs_info` | function | `get_active_constructs_info()` |  |
| `_setup_resonance_cables` | function | `_setup_resonance_cables()` |  |
| `_draw_resonance_cables` | function | `_draw_resonance_cables()` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/systems/summon_manager.gd
```
