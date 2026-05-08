# godot_project/scripts/entities/enemy_base.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 642 | 函数数: 42 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `enemy_died` | signal | `enemy_died(position: Vector2, xp_value: int, enemy_type: String)` |  |
| `enemy_damaged` | signal | `enemy_damaged(current_hp: float, max_hp: float, damage_amount: float)` |  |
| `enemy_stunned` | signal | `enemy_stunned(duration: float)` |  |
| `EnemyType` | enum | `EnemyType()` |  |
| `_ready` | function | `_ready()` |  |
| `_on_enemy_ready` | function | `_on_enemy_ready()` |  |
| `initialize_scripted` | function | `initialize_scripted(params: Dictionary)` |  |
| `_physics_process` | function | `_physics_process(delta: float)` |  |
| `_on_enemy_process` | function | `_on_enemy_process(_delta: float)` |  |
| `_connect_beat_signals` | function | `_connect_beat_signals()` |  |
| `_on_beat_tick` | function | `_on_beat_tick(_beat_index: int)` |  |
| `_on_half_beat_tick` | function | `_on_half_beat_tick(_half_beat_index: int)` |  |
| `_on_beat` | function | `_on_beat(_beat_index: int)` |  |
| `_on_half_beat` | function | `_on_half_beat(_half_beat_index: int)` |  |
| `_get_beat_interval` | function | `_get_beat_interval()` |  |
| `_register_audio_signals` | function | `_register_audio_signals()` |  |
| `_quantized_movement` | function | `_quantized_movement(delta: float)` |  |
| `_play_quantized_step_sound` | function | `_play_quantized_step_sound()` |  |
| `_calculate_movement_direction` | function | `_calculate_movement_direction()` |  |
| `_update_visual` | function | `_update_visual(delta: float)` |  |
| `_apply_beat_pulse` | function | `_apply_beat_pulse()` |  |
| `take_damage` | function | `take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, is_perfect_beat: bool = false)` |  |
| `_trigger_perfect_beat_glitch` | function | `_trigger_perfect_beat_glitch()` |  |
| `set_frozen` | function | `set_frozen(frozen: bool)` |  |
| `apply_stun` | function | `apply_stun(duration: float)` |  |
| `_die` | function | `_die()` |  |
| `_on_death_effect` | function | `_on_death_effect()` |  |
| `_play_death_animation` | function | `_play_death_animation()` |  |
| `_update_contact_damage` | function | `_update_contact_damage(delta: float)` |  |
| `_on_contact_with_player` | function | `_on_contact_with_player()` |  |
| `_find_player` | function | `_find_player()` |  |
| `_update_target` | function | `_update_target()` |  |
| `get_target` | function | `get_target()` |  |
| `get_collision_data` | function | `get_collision_data()` |  |
| `_get_type_name` | function | `_get_type_name()` |  |
| `get_hp_ratio` | function | `get_hp_ratio()` |  |
| `is_alive` | function | `is_alive()` |  |
| `get_glitch_intensity` | function | `get_glitch_intensity()` |  |
| `_setup_visual_enhancer` | function | `_setup_visual_enhancer()` |  |
| `_setup_spatial_audio` | function | `_setup_spatial_audio()` |  |
| `get_spatial_audio_controller` | function | `get_spatial_audio_controller()` |  |
| `_setup_audio_controller` | function | `_setup_audio_controller()` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/entities/enemy_base.gd
```
