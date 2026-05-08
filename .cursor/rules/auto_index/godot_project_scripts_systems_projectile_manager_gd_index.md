# godot_project/scripts/systems/projectile_manager.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 2104 | 函数数: 55 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `projectile_hit_enemy` | signal | `projectile_hit_enemy(projectile: Dictionary, enemy_position: Vector2)` |  |
| `_ready` | function | `_ready()` |  |
| `_process` | function | `_process(delta: float)` |  |
| `update_projectiles` | function | `update_projectiles(delta: float)` |  |
| `spawn_from_spell` | function | `spawn_from_spell(spell_data: Dictionary, origin: Vector2, direction: Vector2)` |  |
| `spawn_chord_projectiles` | function | `spawn_chord_projectiles(chord_data: Dictionary, origin: Vector2, direction: Vector2)` |  |
| `_spawn_shield_demo` | function | `_spawn_shield_demo(data: Dictionary, pos: Vector2)` |  |
| `_spawn_summon_demo` | function | `_spawn_summon_demo(data: Dictionary, pos: Vector2)` |  |
| `_setup_multi_mesh` | function | `_setup_multi_mesh()` |  |
| `_on_spell_cast` | function | `_on_spell_cast(spell_data: Dictionary)` |  |
| `_on_chord_cast` | function | `_on_chord_cast(chord_data: Dictionary)` |  |
| `_create_projectile` | function | `_create_projectile(spell_data: Dictionary)` |  |
| `_create_chord_projectile` | function | `_create_chord_projectile(chord_data: Dictionary)` |  |
| `_spawn_enhanced_projectile` | function | `_spawn_enhanced_projectile(data: Dictionary, pos: Vector2, dir: Vector2)` |  |
| `_spawn_dot_projectile` | function | `_spawn_dot_projectile(data: Dictionary, pos: Vector2, dir: Vector2)` |  |
| `_spawn_explosive` | function | `_spawn_explosive(data: Dictionary, pos: Vector2, dir: Vector2)` |  |
| `_spawn_shockwave` | function | `_spawn_shockwave(data: Dictionary, pos: Vector2)` |  |
| `_spawn_field` | function | `_spawn_field(data: Dictionary, pos: Vector2, dir: Vector2)` |  |
| `_spawn_divine_strike` | function | `_spawn_divine_strike(data: Dictionary, _pos: Vector2, dir: Vector2)` |  |
| `_spawn_shield` | function | `_spawn_shield(data: Dictionary, pos: Vector2)` |  |
| `_spawn_summon` | function | `_spawn_summon(data: Dictionary, _pos: Vector2)` |  |
| `_spawn_charged` | function | `_spawn_charged(data: Dictionary, pos: Vector2, dir: Vector2)` |  |
| `_spawn_slow_field` | function | `_spawn_slow_field(data: Dictionary, pos: Vector2)` |  |
| `_spawn_augmented_burst` | function | `_spawn_augmented_burst(data: Dictionary, pos: Vector2, dir: Vector2)` |  |
| `_spawn_extended_spell` | function | `_spawn_extended_spell(data: Dictionary, pos: Vector2, dir: Vector2)` |  |
| `_spawn_storm_field` | function | `_spawn_storm_field(data: Dictionary, pos: Vector2)` |  |
| `_spawn_holy_domain` | function | `_spawn_holy_domain(data: Dictionary, pos: Vector2)` |  |
| `_spawn_annihilation_ray` | function | `_spawn_annihilation_ray(data: Dictionary, pos: Vector2, dir: Vector2)` |  |
| `_spawn_time_rift` | function | `_spawn_time_rift(data: Dictionary, pos: Vector2)` |  |
| `_spawn_symphony_storm` | function | `_spawn_symphony_storm(data: Dictionary, pos: Vector2)` |  |
| `_spawn_finale` | function | `_spawn_finale(data: Dictionary, pos: Vector2)` |  |
| `_base_projectile` | function | `_base_projectile(data: Dictionary, pos: Vector2, dir: Vector2)` |  |
| `_update_projectiles` | function | `_update_projectiles(delta: float)` | 巨型函数 |
| `_process_timbre_inline` | function | `_process_timbre_inline(proj: Dictionary, delta: float)` |  |
| `apply_timbre_hit_mechanics` | function | `apply_timbre_hit_mechanics(proj: Dictionary, enemy_pos: Vector2)` |  |
| `_trigger_explosion` | function | `_trigger_explosion(proj: Dictionary)` |  |
| `_summon_attack` | function | `_summon_attack(summon_proj: Dictionary)` |  |
| `_update_echo_queue` | function | `_update_echo_queue(delta: float)` |  |
| `_create_echo_projectile` | function | `_create_echo_projectile(spell_data: Dictionary)` |  |
| `_apply_modifier` | function | `_apply_modifier(proj: Dictionary, spell_data: Dictionary = {})` |  |
| `_apply_rhythm_to_projectile` | function | `_apply_rhythm_to_projectile(proj: Dictionary, rhythm, _spell_data: Dictionary)` |  |
| `_setup_collision_optimizer` | function | `_setup_collision_optimizer()` |  |
| `check_collisions` | function | `check_collisions(enemies: Array)` |  |
| `_check_collisions_bruteforce` | function | `_check_collisions_bruteforce(enemies: Array)` |  |
| `get_collision_stats` | function | `get_collision_stats()` |  |
| `_split_projectile` | function | `_split_projectile(proj: Dictionary)` |  |
| `_update_render` | function | `_update_render()` |  |
| `_cleanup_expired` | function | `_cleanup_expired()` |  |
| `_exit_tree` | function | `_exit_tree()` |  |
| `clear_all` | function | `clear_all()` |  |
| `_get_player_position` | function | `_get_player_position()` |  |
| `_get_aim_direction` | function | `_get_aim_direction()` |  |
| `_find_nearest_enemy` | function | `_find_nearest_enemy(from_pos: Vector2)` |  |
| `get_active_count` | function | `get_active_count()` |  |
| `get_projectile_render_data` | function | `get_projectile_render_data()` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| `state_and_config` | 信号、常量、渲染句柄与弹体运行时状态 | `grep -n '@section:state_and_config' godot_project/scripts/systems/projectile_manager.gd` |
| `lifecycle_public_spawn` | 初始化、帧更新与外部弹体生成入口 | `grep -n '@section:lifecycle_public_spawn' godot_project/scripts/systems/projectile_manager.gd` |
| `multimesh_render_setup` | 弹体批量渲染 MultiMesh 初始化 | `grep -n '@section:multimesh_render_setup' godot_project/scripts/systems/projectile_manager.gd` |
| `base_projectile_creation` | 法术与和弦基础弹体创建 | `grep -n '@section:base_projectile_creation' godot_project/scripts/systems/projectile_manager.gd` |
| `specialized_spawn_forms` | 单音与和弦派生弹体形态生成 | `grep -n '@section:specialized_spawn_forms' godot_project/scripts/systems/projectile_manager.gd` |
| `cadence_slow_field` | 终止式减速场生成与持续伤害配置 | `grep -n '@section:cadence_slow_field' godot_project/scripts/systems/projectile_manager.gd` |
| `augmented_burst` | 增和弦爆发弹体生成 | `grep -n '@section:augmented_burst' godot_project/scripts/systems/projectile_manager.gd` |
| `extended_spell_forms` | 风暴、圣域、湮灭、时间与终曲等扩展法术形态 | `grep -n '@section:extended_spell_forms' godot_project/scripts/systems/projectile_manager.gd` |
| `projectile_simulation_loop` | 弹体移动、生命周期、追踪、拖尾与持续效果更新 | `grep -n '@section:projectile_simulation_loop' godot_project/scripts/systems/projectile_manager.gd` |
| `timbre_hit_mechanics` | 音色核心机制与命中副效果处理 | `grep -n '@section:timbre_hit_mechanics' godot_project/scripts/systems/projectile_manager.gd` |
| `echo_queue` | 回声延迟队列与复制弹体创建 | `grep -n '@section:echo_queue' godot_project/scripts/systems/projectile_manager.gd` |
| `modifier_rhythm_application` | 修饰符与节奏型属性写入 | `grep -n '@section:modifier_rhythm_application' godot_project/scripts/systems/projectile_manager.gd` |
| `collision_system` | 碰撞优化器、暴力回退与分裂命中 | `grep -n '@section:collision_system' godot_project/scripts/systems/projectile_manager.gd` |
| `render_sync` | MultiMesh 实例同步与可视状态更新 | `grep -n '@section:render_sync' godot_project/scripts/systems/projectile_manager.gd` |
| `cleanup_and_queries` | 过期清理、退出回收与外部查询 | `grep -n '@section:cleanup_and_queries' godot_project/scripts/systems/projectile_manager.gd` |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/systems/projectile_manager.gd
```
