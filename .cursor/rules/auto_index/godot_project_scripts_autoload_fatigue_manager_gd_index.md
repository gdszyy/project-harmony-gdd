# godot_project/scripts/autoload/fatigue_manager.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 1015 | 函数数: 55 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `fatigue_updated` | signal | `fatigue_updated(result: Dictionary)` |  |
| `fatigue_level_changed` | signal | `fatigue_level_changed(level: MusicData.FatigueLevel)` |  |
| `recovery_suggestion` | signal | `recovery_suggestion(message: String)` |  |
| `note_silenced` | signal | `note_silenced(note: MusicData.WhiteKey, duration: float)` |  |
| `note_unsilenced` | signal | `note_unsilenced(note: MusicData.WhiteKey)` |  |
| `density_overload_changed` | signal | `density_overload_changed(is_overloaded: bool, accuracy_penalty: float)` |  |
| `afi_changed` | signal | `afi_changed(afi_value: float, fatigue_tier: int)` |  |
| `dissonance_corrosion_applied` | signal | `dissonance_corrosion_applied(dissonance: float, damage: float)` |  |
| `PenaltyMode` | enum | `PenaltyMode()` |  |
| `_ready` | function | `_ready()` |  |
| `_on_game_reset` | function | `_on_game_reset(_payload: Variant = null)` |  |
| `_on_game_started` | function | `_on_game_started(_payload: Variant = null)` |  |
| `_process` | function | `_process(delta: float)` |  |
| `record_spell` | function | `record_spell(event: Dictionary)` |  |
| `query_fatigue` | function | `query_fatigue()` |  |
| `get_note_fatigue_map` | function | `get_note_fatigue_map()` |  |
| `_record_note_use` | function | `_record_note_use(note: int, current_time: float)` |  |
| `_silence_note` | function | `_silence_note(white_key: int, duration: float)` |  |
| `_update_silenced_notes` | function | `_update_silenced_notes()` |  |
| `is_note_silenced` | function | `is_note_silenced(note)` |  |
| `get_silenced_notes` | function | `get_silenced_notes()` |  |
| `reduce_monotony_from_dissonance` | function | `reduce_monotony_from_dissonance(dissonance: float)` |  |
| `_update_density_overload` | function | `_update_density_overload()` |  |
| `_calculate_afi` | function | `_calculate_afi(current_time: float)` |  |
| `_calc_pitch_fatigue` | function | `_calc_pitch_fatigue(events: Array)` |  |
| `_calc_transition_fatigue` | function | `_calc_transition_fatigue(events: Array)` |  |
| `_calc_rhythm_fatigue` | function | `_calc_rhythm_fatigue(events: Array)` |  |
| `_calc_chord_fatigue` | function | `_calc_chord_fatigue(events: Array)` |  |
| `_calc_ngram_fatigue` | function | `_calc_ngram_fatigue(events: Array)` |  |
| `_calc_density_fatigue` | function | `_calc_density_fatigue(events: Array, current_time: float)` |  |
| `_calc_rest_deficit` | function | `_calc_rest_deficit(events: Array, _current_time: float)` |  |
| `_calc_sustained_pressure` | function | `_calc_sustained_pressure(current_time: float)` |  |
| `_calculate_penalty` | function | `_calculate_penalty()` |  |
| `_determine_level` | function | `_determine_level(afi: float)` |  |
| `_generate_suggestions` | function | `_generate_suggestions()` |  |
| `apply_resistance_upgrade` | function | `apply_resistance_upgrade(upgrade: Dictionary)` |  |
| `_cleanup_old_events` | function | `_cleanup_old_events(current_time: float)` |  |
| `_get_weighted_events` | function | `_get_weighted_events(current_time: float)` |  |
| `_time_weight` | function | `_time_weight(current_time: float, event_time: float)` |  |
| `_sum_values` | function | `_sum_values(dict: Dictionary)` |  |
| `_note_int_to_white_key` | function | `_note_int_to_white_key(note: int)` |  |
| `add_external_fatigue` | function | `add_external_fatigue(amount: float)` |  |
| `rest_cleanse_triggered` | signal | `rest_cleanse_triggered(rest_count: int)` |  |
| `record_rest` | function | `record_rest()` |  |
| `reset_rest_counter` | function | `reset_rest_counter()` |  |
| `_apply_rest_cleanse` | function | `_apply_rest_cleanse()` |  |
| `get_note_silence_damage_multiplier` | function | `get_note_silence_damage_multiplier(note)` |  |
| `get_density_damage_multiplier` | function | `get_density_damage_multiplier()` |  |
| `get_current_fatigue` | function | `get_current_fatigue()` |  |
| `reduce_fatigue` | function | `reduce_fatigue(amount: float)` |  |
| `reset` | function | `reset()` |  |
| `_get_fatigue_tier` | function | `_get_fatigue_tier(afi: float)` |  |
| `get_fatigue_tier` | function | `get_fatigue_tier()` |  |
| `apply_dissonance_corrosion` | function | `apply_dissonance_corrosion(raw_dissonance: float, mode_multiplier: float = 1.0)` |  |
| `get_recovery_suggestions` | function | `get_recovery_suggestions()` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/autoload/fatigue_manager.gd
```
