# godot_project/scripts/systems/chapter_manager.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 800 | 函数数: 71 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `chapter_started` | signal | `chapter_started(chapter: int, chapter_name: String)` |  |
| `chapter_completed` | signal | `chapter_completed(chapter: int, rewards: Dictionary)` |  |
| `chapter_transition_started` | signal | `chapter_transition_started(from_chapter: int, to_chapter: int)` |  |
| `chapter_transition_completed` | signal | `chapter_transition_completed(new_chapter: int)` |  |
| `wave_started_in_chapter` | signal | `wave_started_in_chapter(chapter: int, wave: int, wave_type: String)` |  |
| `elite_wave_triggered` | signal | `elite_wave_triggered(chapter: int, elite_type: String)` |  |
| `boss_wave_triggered` | signal | `boss_wave_triggered(chapter: int, boss_key: String)` |  |
| `chapter_timer_updated` | signal | `chapter_timer_updated(elapsed: float, total: float)` |  |
| `bpm_changed` | signal | `bpm_changed(new_bpm: float)` |  |
| `boss_spawned` | signal | `boss_spawned(boss_node: Node)` |  |
| `boss_health_changed` | signal | `boss_health_changed(boss_key: String, current_hp: float, max_hp: float)` |  |
| `boss_phase_changed` | signal | `boss_phase_changed(boss_key: String, phase: int)` |  |
| `transition_progress_updated` | signal | `transition_progress_updated(progress: float)` |  |
| `color_theme_changed` | signal | `color_theme_changed(from_color: Color, to_color: Color, progress: float)` |  |
| `special_mechanic_activated` | signal | `special_mechanic_activated(mechanic_name: String, params: Dictionary)` |  |
| `special_mechanic_deactivated` | signal | `special_mechanic_deactivated(mechanic_name: String)` |  |
| `scripted_wave_injected` | signal | `scripted_wave_injected(wave_name: String)` |  |
| `scripted_wave_finished` | signal | `scripted_wave_finished(wave_name: String)` |  |
| `game_completed` | signal | `game_completed()` |  |
| `endless_mode_started` | signal | `endless_mode_started(loop_count: int)` |  |
| `ChapterState` | enum | `ChapterState()` |  |
| `_ready` | function | `_ready()` |  |
| `_process` | function | `_process(delta: float)` |  |
| `start_game` | function | `start_game()` |  |
| `get_current_chapter` | function | `get_current_chapter()` |  |
| `get_chapter_state` | function | `get_chapter_state()` |  |
| `get_chapter_wave` | function | `get_chapter_wave()` |  |
| `get_current_chapter_config` | function | `get_current_chapter_config()` |  |
| `get_global_difficulty` | function | `get_global_difficulty()` |  |
| `is_boss_fight` | function | `is_boss_fight()` |  |
| `is_transitioning` | function | `is_transitioning()` |  |
| `is_endless_mode` | function | `is_endless_mode()` |  |
| `get_current_boss` | function | `get_current_boss()` |  |
| `on_boss_defeated` | function | `on_boss_defeated()` |  |
| `on_wave_completed` | function | `on_wave_completed(_wave_number: int)` |  |
| `get_active_special_mechanics` | function | `get_active_special_mechanics()` |  |
| `is_mechanic_active` | function | `is_mechanic_active(mechanic_name: String)` |  |
| `_start_chapter` | function | `_start_chapter(chapter_index: int)` |  |
| `_process_chapter` | function | `_process_chapter(delta: float)` |  |
| `_update_chapter_phase` | function | `_update_chapter_phase()` |  |
| `_should_trigger_boss` | function | `_should_trigger_boss()` |  |
| `_start_boss_warning` | function | `_start_boss_warning()` |  |
| `_process_boss_warning` | function | `_process_boss_warning(delta: float)` |  |
| `_trigger_boss` | function | `_trigger_boss()` |  |
| `_spawn_boss` | function | `_spawn_boss(boss_key: String, script_path: String)` |  |
| `_on_boss_defeated_signal` | function | `_on_boss_defeated_signal()` |  |
| `_spawn_elite` | function | `_spawn_elite(elite_type: String)` |  |
| `_process_boss_fight` | function | `_process_boss_fight(_delta: float)` |  |
| `_complete_chapter` | function | `_complete_chapter()` |  |
| `_grant_chapter_rewards` | function | `_grant_chapter_rewards(rewards: Dictionary)` |  |
| `_start_transition` | function | `_start_transition()` |  |
| `_process_transition` | function | `_process_transition(delta: float)` |  |
| `_process_completion` | function | `_process_completion(_delta: float)` |  |
| `_activate_special_mechanics` | function | `_activate_special_mechanics()` |  |
| `_deactivate_special_mechanics` | function | `_deactivate_special_mechanics()` |  |
| `_start_bpm_transition` | function | `_start_bpm_transition(target: float)` |  |
| `_process_bpm_transition` | function | `_process_bpm_transition(delta: float)` |  |
| `force_bpm_change` | function | `force_bpm_change(new_bpm: float, instant: bool = false)` |  |
| `_enter_endless_mode` | function | `_enter_endless_mode()` |  |
| `_notify_spawner_chapter_start` | function | `_notify_spawner_chapter_start()` |  |
| `_notify_spawner_boss_phase` | function | `_notify_spawner_boss_phase()` |  |
| `advance_chapter_wave` | function | `advance_chapter_wave()` |  |
| `_check_scripted_wave_trigger` | function | `_check_scripted_wave_trigger(trigger_type: String, wave_number: int)` |  |
| `_inject_scripted_wave` | function | `_inject_scripted_wave(wave_data: Resource)` |  |
| `_on_scripted_wave_completed` | function | `_on_scripted_wave_completed(wave_data: Resource)` |  |
| `get_difficulty_multiplier` | function | `get_difficulty_multiplier()` |  |
| `get_current_wave_template` | function | `get_current_wave_template()` |  |
| `select_enemy_for_current_chapter` | function | `select_enemy_for_current_chapter()` |  |
| `select_elite_for_current_chapter` | function | `select_elite_for_current_chapter()` |  |
| `get_chapter_progress` | function | `get_chapter_progress()` |  |
| `get_current_color_theme` | function | `get_current_color_theme()` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/systems/chapter_manager.gd
```
