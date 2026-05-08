# godot_project/scripts/autoload/signal_bridge.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 607 | 函数数: 56 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `_ready` | function | `_ready()` |  |
| `_connect_all_signals` | function | `_connect_all_signals()` |  |
| `_connect_combat_signals` | function | `_connect_combat_signals()` |  |
| `_on_player_damaged` | function | `_on_player_damaged(amount: float, source_position: Vector2)` |  |
| `_on_player_died` | function | `_on_player_died()` |  |
| `_connect_upgrade_signals` | function | `_connect_upgrade_signals()` |  |
| `_on_upgrade_selected` | function | `_on_upgrade_selected(upgrade: Dictionary)` |  |
| `_on_upgrade_chosen_v3` | function | `_on_upgrade_chosen_v3(upgrade: Dictionary)` |  |
| `_on_inscription_acquired` | function | `_on_inscription_acquired(inscription: Dictionary)` |  |
| `_on_easter_egg_triggered` | function | `_on_easter_egg_triggered(egg: Dictionary)` |  |
| `_connect_resource_signals` | function | `_connect_resource_signals()` |  |
| `_on_insufficient_notes` | function | `_on_insufficient_notes(note_key: int)` |  |
| `_on_chord_spell_crafted` | function | `_on_chord_spell_crafted(chord_spell: Dictionary)` |  |
| `_on_inventory_changed` | function | `_on_inventory_changed(note_key: int, new_count: int)` |  |
| `_connect_chapter_signals` | function | `_connect_chapter_signals()` |  |
| `_deferred_connect_chapter_signals` | function | `_deferred_connect_chapter_signals()` |  |
| `_on_wave_completed` | function | `_on_wave_completed(wave_number: int)` |  |
| `_on_wave_started` | function | `_on_wave_started(wave_number: int, wave_type: String)` |  |
| `_on_chapter_timer_updated` | function | `_on_chapter_timer_updated(elapsed: float, total: float)` |  |
| `_on_bpm_changed` | function | `_on_bpm_changed(new_bpm: float)` |  |
| `_on_wave_started_in_chapter` | function | `_on_wave_started_in_chapter(chapter: int, wave: int, wave_type: String)` |  |
| `_on_elite_wave_triggered` | function | `_on_elite_wave_triggered(chapter: int, elite_type: String)` |  |
| `_on_endless_mode_started` | function | `_on_endless_mode_started(loop_count: int)` |  |
| `_on_boss_health_changed` | function | `_on_boss_health_changed(boss_key: String, current_hp: float, max_hp: float)` |  |
| `_connect_boss_signals` | function | `_connect_boss_signals()` |  |
| `_deferred_connect_boss_signals` | function | `_deferred_connect_boss_signals()` |  |
| `_connect_arena_decorator_signals` | function | `_connect_arena_decorator_signals(decorator: Node)` |  |
| `_on_boss_spawned` | function | `_on_boss_spawned(boss_node: Node)` |  |
| `_on_boss_vulnerability_started` | function | `_on_boss_vulnerability_started(duration: float)` |  |
| `_on_boss_vulnerability_ended` | function | `_on_boss_vulnerability_ended()` |  |
| `_on_boss_phase_changed` | function | `_on_boss_phase_changed(phase_index: int, phase_name: String)` |  |
| `_on_chapter_boss_phase_changed` | function | `_on_chapter_boss_phase_changed(boss_key: String, phase: int)` |  |
| `_on_boss_enraged` | function | `_on_boss_enraged(enrage_level: int)` |  |
| `_on_boss_defeated` | function | `_on_boss_defeated()` |  |
| `_on_boss_summon_minions` | function | `_on_boss_summon_minions(count: int, type: String)` |  |
| `_on_boss_attack_started` | function | `_on_boss_attack_started(attack_name: String)` |  |
| `_on_boss_attack_ended` | function | `_on_boss_attack_ended(attack_name: String)` |  |
| `_on_arena_activated` | function | `_on_arena_activated(boss_key: String)` |  |
| `_on_arena_deactivated` | function | `_on_arena_deactivated()` |  |
| `_on_arena_phase_changed` | function | `_on_arena_phase_changed(phase_index: int)` |  |
| `_connect_audio_signals` | function | `_connect_audio_signals()` |  |
| `_on_bgm_intensity_changed` | function | `_on_bgm_intensity_changed(new_intensity: float)` |  |
| `_on_bgm_layer_toggled` | function | `_on_bgm_layer_toggled(layer_name: String, enabled: bool)` |  |
| `_on_tonality_changed` | function | `_on_tonality_changed(chapter_id: int, mode_name: String, scale_notes: Array)` |  |
| `_on_progression_triggered` | function | `_on_progression_triggered(effect_type: String, bonus_multiplier: float)` |  |
| `_on_transpose_changed` | function | `_on_transpose_changed(semitone_offset: int)` |  |
| `_connect_meta_progression_signals` | function | `_connect_meta_progression_signals()` |  |
| `_on_mode_unlocked` | function | `_on_mode_unlocked(mode_name: String)` |  |
| `_on_mode_selected` | function | `_on_mode_selected(mode_name: String)` |  |
| `_on_theory_unlocked` | function | `_on_theory_unlocked(theory_id: String)` |  |
| `_on_resonance_changed` | function | `_on_resonance_changed(amount: int)` |  |
| `_get_audio_manager` | function | `_get_audio_manager()` |  |
| `_get_bgm_manager` | function | `_get_bgm_manager()` |  |
| `_get_chapter_manager` | function | `_get_chapter_manager()` |  |
| `_find_node_in_tree` | function | `_find_node_in_tree(node_name: String)` |  |
| `_search_children` | function | `_search_children(node: Node, target_name: String)` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/autoload/signal_bridge.gd
```
