# godot_project/scripts/ui/hud.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 939 | 函数数: 61 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `hud_ready` | signal | `hud_ready()` |  |
| `hud_visibility_changed` | signal | `hud_visibility_changed(is_visible: bool)` |  |
| `_ready` | function | `_ready()` |  |
| `_process` | function | `_process(delta: float)` |  |
| `_build_modular_hud` | function | `_build_modular_hud()` |  |
| `_load_script_node` | function | `_load_script_node(script_path: String, node_name: String)` |  |
| `_setup_legacy_ui` | function | `_setup_legacy_ui()` |  |
| `_setup_suggestion_label` | function | `_setup_suggestion_label()` |  |
| `_setup_silence_indicators` | function | `_setup_silence_indicators()` |  |
| `_setup_overload_warning` | function | `_setup_overload_warning()` |  |
| `_setup_progression_label` | function | `_setup_progression_label()` |  |
| `_setup_mode_label` | function | `_setup_mode_label()` |  |
| `_setup_crit_label` | function | `_setup_crit_label()` |  |
| `_connect_global_signals` | function | `_connect_global_signals()` |  |
| `_on_hp_changed` | function | `_on_hp_changed(current_hp: float, max_hp: float)` |  |
| `_on_fatigue_updated` | function | `_on_fatigue_updated(result: Dictionary)` |  |
| `_on_recovery_suggestion` | function | `_on_recovery_suggestion(message: String)` |  |
| `_update_suggestion` | function | `_update_suggestion(delta: float)` |  |
| `_on_boss_fight_started` | function | `_on_boss_fight_started(boss_node: Node)` |  |
| `_on_boss_fight_ended` | function | `_on_boss_fight_ended()` |  |
| `_on_damage_dealt` | function | `_on_damage_dealt(data: Dictionary)` |  |
| `_on_player_healed` | function | `_on_player_healed(data: Dictionary)` |  |
| `show_damage_number` | function | `show_damage_number(position: Vector2, damage: float, is_crit: bool = false, is_self_damage: bool = false)` |  |
| `_on_density_overload_signal` | function | `_on_density_overload_signal()` |  |
| `_on_chord_progression_signal` | function | `_on_chord_progression_signal(chord_name: String)` |  |
| `_on_note_silenced_signal` | function | `_on_note_silenced_signal(note_name: String)` |  |
| `_on_accuracy_penalized` | function | `_on_accuracy_penalized(_penalty: float)` |  |
| `_update_overload_warning` | function | `_update_overload_warning(delta: float)` |  |
| `_on_progression_resolved` | function | `_on_progression_resolved(progression: Dictionary)` |  |
| `_update_progression_label` | function | `_update_progression_label(delta: float)` |  |
| `_on_spell_blocked` | function | `_on_spell_blocked(_note: int)` |  |
| `_update_silence_indicators` | function | `_update_silence_indicators()` |  |
| `_on_mode_changed` | function | `_on_mode_changed(_mode_id: String)` |  |
| `_update_mode_display` | function | `_update_mode_display()` |  |
| `_on_crit_updated` | function | `_on_crit_updated(crit_chance: float)` |  |
| `_setup_fatigue_filter` | function | `_setup_fatigue_filter()` |  |
| `_update_fatigue_filter` | function | `_update_fatigue_filter()` |  |
| `_setup_fatigue_filter_controller` | function | `_setup_fatigue_filter_controller()` |  |
| `_setup_recovery_suggestion_ui` | function | `_setup_recovery_suggestion_ui()` |  |
| `_on_beat_tick` | function | `_on_beat_tick(_beat_index: int)` |  |
| `_on_rest_cleanse` | function | `_on_rest_cleanse(rest_count: int)` |  |
| `_setup_xp_bar` | function | `_setup_xp_bar()` |  |
| `_update_xp_bar` | function | `_update_xp_bar(delta: float)` |  |
| `_update_xp_bar_text` | function | `_update_xp_bar_text()` |  |
| `_on_xp_gained` | function | `_on_xp_gained(_amount: int)` |  |
| `_on_level_up` | function | `_on_level_up(_new_level: int)` |  |
| `get_hp_bar` | function | `get_hp_bar()` |  |
| `get_fatigue_meter` | function | `get_fatigue_meter()` |  |
| `get_boss_hp_bar` | function | `get_boss_hp_bar()` |  |
| `get_manual_cast_slots` | function | `get_manual_cast_slots()` |  |
| `get_info_panel` | function | `get_info_panel()` |  |
| `get_summon_hud` | function | `get_summon_hud()` |  |
| `get_damage_number_pool` | function | `get_damage_number_pool()` |  |
| `get_notification_manager` | function | `get_notification_manager()` |  |
| `get_rhythm_indicator` | function | `get_rhythm_indicator()` |  |
| `get_ammo_ring` | function | `get_ammo_ring()` |  |
| `set_hud_visible` | function | `set_hud_visible(is_visible: bool)` |  |
| `enable_dps_overlay` | function | `enable_dps_overlay()` |  |
| `disable_dps_overlay` | function | `disable_dps_overlay()` |  |
| `spawn_damage_number_v2` | function | `spawn_damage_number_v2(damage: float, pos: Vector2, type: int = 0)` |  |
| `show_notification` | function | `show_notification(text: String, type: int = 4, duration: float = 2.0)` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/ui/hud.gd
```
