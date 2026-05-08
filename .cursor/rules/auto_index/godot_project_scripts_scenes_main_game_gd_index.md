# godot_project/scripts/scenes/main_game.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 1557 | 函数数: 87 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `debug_message` | signal | `debug_message(text: String)` |  |
| `_ready` | function | `_ready()` |  |
| `_input` | function | `_input(event: InputEvent)` |  |
| `_process` | function | `_process(delta: float)` |  |
| `_start_normal_game` | function | `_start_normal_game()` |  |
| `_process_normal_game` | function | `_process_normal_game(delta: float)` |  |
| `_enter_test_mode` | function | `_enter_test_mode()` |  |
| `_process_test_mode` | function | `_process_test_mode(delta: float)` |  |
| `_handle_test_mode_input` | function | `_handle_test_mode_input(event: InputEvent)` |  |
| `_draw` | function | `_draw()` |  |
| `_setup_scene` | function | `_setup_scene()` |  |
| `_setup_render_bridge` | function | `_setup_render_bridge()` |  |
| `_sync_projectiles_to_3d` | function | `_sync_projectiles_to_3d()` |  |
| `_on_elite_spawned_3d` | function | `_on_elite_spawned_3d(enemy_type: String, position: Vector2)` |  |
| `_on_enemy_count_changed_3d` | function | `_on_enemy_count_changed_3d(_active: int, _total_spawned: int)` |  |
| `_get_enemy_color` | function | `_get_enemy_color(enemy_type: String)` |  |
| `_connect_system_signals` | function | `_connect_system_signals()` |  |
| `_connect_spell_signals` | function | `_connect_spell_signals()` |  |
| `_on_spellcraft_spell_cast` | function | `_on_spellcraft_spell_cast(spell_data: Dictionary)` |  |
| `_on_spellcraft_chord_cast` | function | `_on_spellcraft_chord_cast(chord_data: Dictionary)` |  |
| `_on_spell_blocked` | function | `_on_spell_blocked(note: int)` |  |
| `_on_rhythm_changed` | function | `_on_rhythm_changed(pattern)` |  |
| `_on_progression_resolved` | function | `_on_progression_resolved(progression: Dictionary)` |  |
| `_on_timbre_changed` | function | `_on_timbre_changed(timbre: int)` |  |
| `_start_chapter_system` | function | `_start_chapter_system()` |  |
| `_on_player_died` | function | `_on_player_died()` |  |
| `_on_game_state_changed` | function | `_on_game_state_changed(new_state: GameManager.GameState)` |  |
| `_on_chapter_started` | function | `_on_chapter_started(_chapter_index: int, _chapter_name: String)` |  |
| `_on_chapter_completed` | function | `_on_chapter_completed(_chapter_index: int)` |  |
| `_on_chapter_boss_triggered` | function | `_on_chapter_boss_triggered(_chapter_index: int, _boss_key: String)` |  |
| `_on_game_completed` | function | `_on_game_completed()` |  |
| `_on_boss_fight_started` | function | `_on_boss_fight_started(_boss_name: String)` |  |
| `_on_boss_fight_ended` | function | `_on_boss_fight_ended(_boss_name: String, _victory: bool)` |  |
| `_on_beat_tick_3d` | function | `_on_beat_tick_3d(beat_index: int)` |  |
| `_on_enemy_killed_vfx` | function | `_on_enemy_killed_vfx(enemy_position: Vector2, enemy_type: String = "static")` |  |
| `_on_alchemy_completed` | function | `_on_alchemy_completed(_chord_spell: Dictionary)` |  |
| `_setup_ground` | function | `_setup_ground()` |  |
| `_setup_event_horizon` | function | `_setup_event_horizon()` |  |
| `_update_event_horizon` | function | `_update_event_horizon()` |  |
| `_check_collisions` | function | `_check_collisions()` |  |
| `_enforce_arena_boundary` | function | `_enforce_arena_boundary()` |  |
| `_update_ground_shader` | function | `_update_ground_shader()` |  |
| `debug_spawn_enemy` | function | `debug_spawn_enemy(enemy_type: String, count: int = 1, position_mode: String = "random")` |  |
| `debug_spawn_wave_preset` | function | `debug_spawn_wave_preset(preset_name: String)` |  |
| `debug_clear_all_enemies` | function | `debug_clear_all_enemies()` |  |
| `get_enemy_count` | function | `get_enemy_count()` |  |
| `set_player_stat` | function | `set_player_stat(stat: String, value: float)` |  |
| `set_bpm` | function | `set_bpm(bpm: float)` |  |
| `set_mode` | function | `set_mode(mode_id: String)` |  |
| `set_player_level` | function | `set_player_level(level: int)` |  |
| `test_cast_note` | function | `test_cast_note(white_key: int)` |  |
| `test_cast_note_with_modifier` | function | `test_cast_note_with_modifier(white_key: int, modifier: int)` |  |
| `test_cast_chord` | function | `test_cast_chord(chord_type: int)` |  |
| `test_set_sequencer_pattern` | function | `test_set_sequencer_pattern(pattern: Array)` |  |
| `test_set_manual_slot` | function | `test_set_manual_slot(slot_index: int, spell_data: Dictionary)` |  |
| `test_trigger_manual_cast` | function | `test_trigger_manual_cast(slot_index: int)` |  |
| `test_set_timbre` | function | `test_set_timbre(timbre: int)` |  |
| `test_set_mode` | function | `test_set_mode(mode_id: String)` |  |
| `preset_full_note_sequencer` | function | `preset_full_note_sequencer()` |  |
| `preset_charged_sequencer` | function | `preset_charged_sequencer()` |  |
| `preset_all_basic_chords` | function | `preset_all_basic_chords()` |  |
| `preset_all_seventh_chords` | function | `preset_all_seventh_chords()` |  |
| `preset_all_modifiers` | function | `preset_all_modifiers()` |  |
| `debug_start_chapter_system` | function | `debug_start_chapter_system()` |  |
| `debug_pause_chapter_system` | function | `debug_pause_chapter_system()` |  |
| `debug_start_enemy_spawner` | function | `debug_start_enemy_spawner()` |  |
| `debug_pause_enemy_spawner` | function | `debug_pause_enemy_spawner()` |  |
| `_cycle_chapter_visual` | function | `_cycle_chapter_visual()` |  |
| `_toggle_3d_layer` | function | `_toggle_3d_layer()` |  |
| `record_damage` | function | `record_damage(damage: float, source: String = "spell")` |  |
| `_update_dps_window` | function | `_update_dps_window()` |  |
| `get_dps_stats` | function | `get_dps_stats()` |  |
| `_reset_dps` | function | `_reset_dps()` |  |
| `get_spell_system_state` | function | `get_spell_system_state()` |  |
| `get_projectile_stats` | function | `get_projectile_stats()` |  |
| `get_stats_summary` | function | `get_stats_summary()` |  |
| `_get_all_enemies` | function | `_get_all_enemies()` |  |
| `_get_debug_spawn_position` | function | `_get_debug_spawn_position(mode: String, index: int, total: int)` |  |
| `_register_debug_enemy_3d` | function | `_register_debug_enemy_3d(enemy: Node2D, enemy_type: String)` |  |
| `_auto_fire_cast` | function | `_auto_fire_cast()` |  |
| `_on_debug_enemy_died` | function | `_on_debug_enemy_died(pos: Vector2, xp_value: int, enemy_type: String)` |  |
| `_draw_hitboxes` | function | `_draw_hitboxes()` |  |
| `_get_white_key_name` | function | `_get_white_key_name(key: int)` |  |
| `_get_modifier_name` | function | `_get_modifier_name(mod: int)` |  |
| `_get_rhythm_name` | function | `_get_rhythm_name(rhythm)` |  |
| `_debug_log` | function | `_debug_log(text: String)` |  |
| `_return_to_menu` | function | `_return_to_menu()` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/scenes/main_game.gd
```
