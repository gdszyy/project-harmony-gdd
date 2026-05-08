# godot_project/scripts/systems/obstacle_spawner.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 434 | 函数数: 26 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `obstacle_spawned` | signal | `obstacle_spawned(obstacle: Node, position: Vector2)` |  |
| `obstacle_destroyed` | signal | `obstacle_destroyed(position: Vector2)` |  |
| `obstacles_cleared` | signal | `obstacles_cleared()` |  |
| `_ready` | function | `_ready()` |  |
| `_preload_resources` | function | `_preload_resources()` |  |
| `_connect_signals` | function | `_connect_signals()` |  |
| `_on_chapter_started` | function | `_on_chapter_started(chapter_index: int, _chapter_name: String = "")` |  |
| `_on_chapter_completed` | function | `_on_chapter_completed(_chapter_index: int, _rewards: Dictionary = {})` |  |
| `_generate_chapter_obstacles` | function | `_generate_chapter_obstacles(chapter_index: int)` |  |
| `spawn_wave_obstacles` | function | `spawn_wave_obstacles(count: int, near_position: Vector2 = Vector2.ZERO)` |  |
| `_spawn_obstacle_at` | function | `_spawn_obstacle_at(pos: Vector2, can_crystallize: bool, hp: int)` |  |
| `_generate_positions` | function | `_generate_positions(count: int, pattern: String)` |  |
| `_pattern_symmetric` | function | `_pattern_symmetric(count: int)` |  |
| `_pattern_lines` | function | `_pattern_lines(count: int)` |  |
| `_pattern_maze` | function | `_pattern_maze(count: int)` |  |
| `_pattern_elegant` | function | `_pattern_elegant(count: int)` |  |
| `_pattern_fortress` | function | `_pattern_fortress(count: int)` |  |
| `_pattern_scattered` | function | `_pattern_scattered(count: int)` |  |
| `_pattern_chaotic` | function | `_pattern_chaotic(count: int)` |  |
| `_is_valid_spawn_position` | function | `_is_valid_spawn_position(pos: Vector2)` |  |
| `_clamp_to_arena` | function | `_clamp_to_arena(pos: Vector2)` |  |
| `damage_obstacle` | function | `damage_obstacle(obstacle: Node, amount: float)` |  |
| `_destroy_obstacle` | function | `_destroy_obstacle(obstacle: Node)` |  |
| `clear_all_obstacles` | function | `clear_all_obstacles()` |  |
| `get_active_count` | function | `get_active_count()` |  |
| `get_obstacle_positions` | function | `get_obstacle_positions()` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/systems/obstacle_spawner.gd
```
