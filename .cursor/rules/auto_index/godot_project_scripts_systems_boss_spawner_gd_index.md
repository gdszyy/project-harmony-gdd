# godot_project/scripts/systems/boss_spawner.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 550 | 函数数: 31 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `boss_fight_started` | signal | `boss_fight_started(boss_name: String)` |  |
| `boss_fight_ended` | signal | `boss_fight_ended(boss_name: String, victory: bool)` |  |
| `boss_spawned` | signal | `boss_spawned(boss: Node)` |  |
| `boss_intro_started` | signal | `boss_intro_started(boss_name: String)` |  |
| `boss_intro_completed` | signal | `boss_intro_completed(boss_name: String)` |  |
| `_ready` | function | `_ready()` |  |
| `_preload_boss_scenes` | function | `_preload_boss_scenes()` |  |
| `_init_boss_experience_systems` | function | `_init_boss_experience_systems()` |  |
| `is_boss_wave` | function | `is_boss_wave(wave_number: int)` |  |
| `is_boss_fight_active` | function | `is_boss_fight_active()` |  |
| `get_current_boss` | function | `get_current_boss()` |  |
| `spawn_boss` | function | `spawn_boss(player_pos: Vector2)` |  |
| `spawn_chapter_boss` | function | `spawn_chapter_boss(chapter_index: int, boss_config: Dictionary)` |  |
| `spawn_timed_boss` | function | `spawn_timed_boss(boss_key: String, player_pos: Vector2, difficulty_bonus: float = 0.0)` |  |
| `_start_boss_intro_sequence` | function | `_start_boss_intro_sequence(boss_key: String, on_complete: Callable)` |  |
| `_start_boss_victory_sequence` | function | `_start_boss_victory_sequence(boss_key: String, on_complete: Callable)` |  |
| `_play_boss_warning` | function | `_play_boss_warning(boss_key: String, on_complete: Callable)` |  |
| `_on_chapter_boss_triggered` | function | `_on_chapter_boss_triggered(chapter_index: int, boss_config: Dictionary)` |  |
| `_spawn_chapter_boss_instance` | function | `_spawn_chapter_boss_instance(boss_key: String, script_path: String, player_pos: Vector2)` |  |
| `_setup_boss` | function | `_setup_boss(boss: Node, player_pos: Vector2, boss_key: String)` |  |
| `_setup_timed_boss` | function | `_setup_timed_boss(boss: Node, player_pos: Vector2, boss_key: String, difficulty_bonus: float)` |  |
| `_spawn_boss_from_code` | function | `_spawn_boss_from_code(boss_key: String, player_pos: Vector2)` |  |
| `_spawn_boss_from_code_fallback` | function | `_spawn_boss_from_code_fallback(boss_key: String, _player_pos: Vector2)` |  |
| `_create_boss_nodes` | function | `_create_boss_nodes(boss: Node)` |  |
| `_play_boss_intro` | function | `_play_boss_intro(boss: Node)` |  |
| `_on_boss_defeated` | function | `_on_boss_defeated()` |  |
| `_on_boss_died` | function | `_on_boss_died(_pos: Vector2, _xp: int, _type: String)` |  |
| `_on_boss_phase_changed` | function | `_on_boss_phase_changed(phase_index: int, phase_name: String)` |  |
| `_on_boss_summon_minions` | function | `_on_boss_summon_minions(count: int, type: String)` |  |
| `_end_boss_fight` | function | `_end_boss_fight(victory: bool)` |  |
| `_grant_boss_rewards` | function | `_grant_boss_rewards()` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/systems/boss_spawner.gd
```
