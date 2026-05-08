# godot_project/scripts/systems/render_bridge_3d.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 645 | 函数数: 34 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `_ready` | function | `_ready()` |  |
| `_process` | function | `_process(delta: float)` |  |
| `_build_3d_scene` | function | `_build_3d_scene()` |  |
| `_setup_world_environment` | function | `_setup_world_environment()` |  |
| `_setup_chapter_visual_manager` | function | `_setup_chapter_visual_manager()` |  |
| `_setup_projectile_renderer` | function | `_setup_projectile_renderer()` |  |
| `to_3d` | function | `to_3d(pos_2d: Vector2)` |  |
| `to_2d` | function | `to_2d(pos_3d: Vector3)` |  |
| `screen_to_3d` | function | `screen_to_3d(screen_pos: Vector2)` |  |
| `set_follow_target` | function | `set_follow_target(target: Node2D)` |  |
| `_update_camera_follow` | function | `_update_camera_follow(delta: float)` |  |
| `_sync_player_proxy` | function | `_sync_player_proxy()` |  |
| `_sync_enemy_proxies` | function | `_sync_enemy_proxies()` |  |
| `create_player_proxy` | function | `create_player_proxy(player_2d: Node2D)` |  |
| `update_player_light_color` | function | `update_player_light_color(color: Color)` |  |
| `register_enemy_proxy` | function | `register_enemy_proxy(enemy_2d: Node2D, enemy_color: Color = Color.RED, is_elite: bool = false)` |  |
| `unregister_enemy_proxy` | function | `unregister_enemy_proxy(enemy_2d: Node2D)` |  |
| `sync_projectiles` | function | `sync_projectiles(projectile_data: Array)` |  |
| `get_environment` | function | `get_environment()` |  |
| `set_glow_intensity` | function | `set_glow_intensity(intensity: float, duration: float = 0.5)` |  |
| `reset_glow` | function | `reset_glow(duration: float = 1.0)` |  |
| `enter_boss_mode` | function | `enter_boss_mode()` |  |
| `exit_boss_mode` | function | `exit_boss_mode()` |  |
| `on_beat_pulse` | function | `on_beat_pulse(beat_index: int)` |  |
| `get_harmonic_avatar` | function | `get_harmonic_avatar()` |  |
| `spawn_burst_particles` | function | `spawn_burst_particles(pos_2d: Vector2, color: Color, amount: int = 32)` |  |
| `_on_viewport_size_changed` | function | `_on_viewport_size_changed()` |  |
| `is_ready` | function | `is_ready()` |  |
| `get_camera_3d` | function | `get_camera_3d()` |  |
| `get_vfx_layer` | function | `get_vfx_layer()` |  |
| `get_entity_layer` | function | `get_entity_layer()` |  |
| `get_ground_layer` | function | `get_ground_layer()` |  |
| `_setup_enemy_multimesh` | function | `_setup_enemy_multimesh()` |  |
| `_sync_enemy_multimesh` | function | `_sync_enemy_multimesh()` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/systems/render_bridge_3d.gd
```
