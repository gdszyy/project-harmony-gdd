# godot_project/scripts/systems/pool_manager.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 625 | 函数数: 33 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `_ready` | function | `_ready()` |  |
| `_process` | function | `_process(delta: float)` |  |
| `_preload_scenes` | function | `_preload_scenes()` |  |
| `_preload_chapter_scenes` | function | `_preload_chapter_scenes(chapter_index: int)` |  |
| `_init_all_pools` | function | `_init_all_pools()` |  |
| `_init_enemy_pool` | function | `_init_enemy_pool(pool_name: String)` |  |
| `_init_xp_pool` | function | `_init_xp_pool()` |  |
| `_init_damage_number_pool` | function | `_init_damage_number_pool()` |  |
| `_init_death_fragment_pool` | function | `_init_death_fragment_pool()` |  |
| `warmup_chapter` | function | `warmup_chapter(chapter_index: int)` |  |
| `register_enemy_pool` | function | `register_enemy_pool(type_name: String, scene: PackedScene)` |  |
| `has_enemy_pool` | function | `has_enemy_pool(type_name: String)` |  |
| `_precompile_shaders` | function | `_precompile_shaders()` |  |
| `acquire` | function | `acquire(pool_name: String)` |  |
| `acquire_enemy` | function | `acquire_enemy(type_name: String)` |  |
| `acquire_xp_pickup` | function | `acquire_xp_pickup()` |  |
| `acquire_damage_number` | function | `acquire_damage_number()` |  |
| `acquire_death_fragment` | function | `acquire_death_fragment()` |  |
| `release` | function | `release(pool_name: String, obj: Node)` |  |
| `release_enemy` | function | `release_enemy(type_name: String, obj: Node)` |  |
| `release_xp_pickup` | function | `release_xp_pickup(obj: Node)` |  |
| `release_damage_number` | function | `release_damage_number(obj: Node)` |  |
| `release_death_fragment` | function | `release_death_fragment(obj: Node)` |  |
| `_reset_enemy` | function | `_reset_enemy(enemy: Node)` |  |
| `_reset_xp_pickup` | function | `_reset_xp_pickup(pickup: Node)` |  |
| `_emit_stats` | function | `_emit_stats()` |  |
| `get_all_stats` | function | `get_all_stats()` |  |
| `get_pool_stats` | function | `get_pool_stats(pool_name: String)` |  |
| `get_performance_summary` | function | `get_performance_summary()` |  |
| `get_enemy_pool_summary` | function | `get_enemy_pool_summary()` |  |
| `release_all_pools` | function | `release_all_pools()` |  |
| `destroy_all_pools` | function | `destroy_all_pools()` |  |
| `release_chapter_pools` | function | `release_chapter_pools(chapter_index: int)` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/systems/pool_manager.gd
```
