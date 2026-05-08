# godot_project/scripts/systems/enemy_spawner.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 1249 | 函数数: 76 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `wave_started` | signal | `wave_started(wave_number: int, wave_type: String)` |  |
| `wave_completed` | signal | `wave_completed(wave_number: int)` |  |
| `elite_spawned` | signal | `elite_spawned(enemy_type: String, position: Vector2)` |  |
| `spawn_count_changed` | signal | `spawn_count_changed(active: int, total_spawned: int)` |  |
| `scripted_wave_completed` | signal | `scripted_wave_completed(wave_data: Resource)` |  |
| `scripted_wave_started` | signal | `scripted_wave_started(wave_name: String)` |  |
| `WaveType` | enum | `WaveType()` |  |
| `_ready` | function | `_ready()` |  |
| `_process` | function | `_process(delta: float)` |  |
| `_preload_enemy_scenes` | function | `_preload_enemy_scenes()` |  |
| `_preload_chapter_scripts` | function | `_preload_chapter_scripts()` |  |
| `_connect_signals` | function | `_connect_signals()` |  |
| `_register_to_pool` | function | `_register_to_pool(type_name: String, scene: PackedScene)` |  |
| `set_chapter_mode` | function | `set_chapter_mode(chapter_index: int, config: Dictionary)` |  |
| `enter_boss_phase` | function | `enter_boss_phase()` |  |
| `exit_boss_phase` | function | `exit_boss_phase()` |  |
| `play_scripted_wave` | function | `play_scripted_wave(wave_data: Resource)` |  |
| `resume_random_spawning` | function | `resume_random_spawning()` |  |
| `is_scripted_wave_active` | function | `is_scripted_wave_active()` |  |
| `_process_scripted_wave` | function | `_process_scripted_wave(delta: float)` |  |
| `_execute_scripted_event` | function | `_execute_scripted_event(event: Dictionary)` |  |
| `_scripted_spawn` | function | `_scripted_spawn(params: Dictionary)` |  |
| `_scripted_spawn_swarm` | function | `_scripted_spawn_swarm(params: Dictionary)` |  |
| `_scripted_spawn_escort` | function | `_scripted_spawn_escort(params: Dictionary)` |  |
| `_scripted_set_bpm` | function | `_scripted_set_bpm(params: Dictionary)` |  |
| `_scripted_show_hint` | function | `_scripted_show_hint(params: Dictionary)` |  |
| `_scripted_conditional_hint` | function | `_scripted_conditional_hint(params: Dictionary)` |  |
| `_scripted_unlock` | function | `_scripted_unlock(params: Dictionary)` |  |
| `_resolve_spawn_position` | function | `_resolve_spawn_position(position_param)` |  |
| `_apply_scripted_params` | function | `_apply_scripted_params(enemy: Node, params: Dictionary)` |  |
| `_get_formation_offset` | function | `_get_formation_offset(formation: String, index: int, total: int)` |  |
| `_parse_condition_timeout` | function | `_parse_condition_timeout(condition: String)` |  |
| `spawn_minions_for_boss` | function | `spawn_minions_for_boss(count: int, type: String, boss_pos: Vector2)` |  |
| `_update_difficulty` | function | `_update_difficulty()` |  |
| `_get_difficulty_multipliers` | function | `_get_difficulty_multipliers()` |  |
| `_get_hp_scale` | function | `_get_hp_scale()` |  |
| `_get_speed_scale` | function | `_get_speed_scale()` |  |
| `_get_damage_scale` | function | `_get_damage_scale()` |  |
| `_get_wave_enemy_count` | function | `_get_wave_enemy_count()` |  |
| `_start_new_wave` | function | `_start_new_wave()` |  |
| `_determine_chapter_wave_type` | function | `_determine_chapter_wave_type()` |  |
| `_process_wave` | function | `_process_wave(delta: float)` |  |
| `_end_wave` | function | `_end_wave()` |  |
| `_determine_wave_type` | function | `_determine_wave_type()` |  |
| `_get_wave_type_name` | function | `_get_wave_type_name(wave_type: WaveType)` |  |
| `_on_global_beat` | function | `_on_global_beat(_beat_index: int)` |  |
| `_beat_spawn_batch` | function | `_beat_spawn_batch()` |  |
| `_spawn_wave_enemies` | function | `_spawn_wave_enemies()` |  |
| `_get_batch_spawn_count` | function | `_get_batch_spawn_count()` |  |
| `_select_enemy_type` | function | `_select_enemy_type()` |  |
| `_weighted_enemy_select` | function | `_weighted_enemy_select()` |  |
| `_spawn_chapter_elite` | function | `_spawn_chapter_elite()` |  |
| `_spawn_enemy` | function | `_spawn_enemy(player_pos: Vector2, type_name: String)` |  |
| `_spawn_enemy_at` | function | `_spawn_enemy_at(spawn_pos: Vector2, type_name: String)` |  |
| `_instantiate_from_script` | function | `_instantiate_from_script(type_name: String)` |  |
| `_create_enemy_nodes` | function | `_create_enemy_nodes(enemy: Node, type_name: String)` |  |
| `_calculate_spawn_position` | function | `_calculate_spawn_position(player_pos: Vector2)` |  |
| `_apply_difficulty_scaling` | function | `_apply_difficulty_scaling(enemy: CharacterBody2D, type_name: String)` |  |
| `_apply_elite_bonus` | function | `_apply_elite_bonus(enemy: CharacterBody2D, _type_name: String)` |  |
| `_on_enemy_died` | function | `_on_enemy_died(pos: Vector2, xp: int, enemy_type: String)` |  |
| `_cleanup_dead_enemies` | function | `_cleanup_dead_enemies()` |  |
| `_spawn_xp_pickup` | function | `_spawn_xp_pickup(pos: Vector2, value: int, _enemy_type: String)` |  |
| `get_enemy_collision_data` | function | `get_enemy_collision_data()` |  |
| `get_active_enemy_count` | function | `get_active_enemy_count()` |  |
| `get_current_wave` | function | `get_current_wave()` |  |
| `get_chapter_wave` | function | `get_chapter_wave()` |  |
| `get_difficulty_level` | function | `get_difficulty_level()` |  |
| `is_wave_active` | function | `is_wave_active()` |  |
| `is_chapter_mode` | function | `is_chapter_mode()` |  |
| `is_boss_phase` | function | `is_boss_phase()` |  |
| `get_wave_progress` | function | `get_wave_progress()` |  |
| `clear_all_enemies` | function | `clear_all_enemies()` |  |
| `_init_pool_manager` | function | `_init_pool_manager()` |  |
| `_return_dead_enemy_to_pool` | function | `_return_dead_enemy_to_pool(enemy_type: String)` |  |
| `get_pool_stats` | function | `get_pool_stats()` |  |
| `get_pool_hit_rate` | function | `get_pool_hit_rate()` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/systems/enemy_spawner.gd
```
