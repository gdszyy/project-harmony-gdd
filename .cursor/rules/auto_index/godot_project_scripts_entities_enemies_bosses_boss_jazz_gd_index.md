# godot_project/scripts/entities/enemies/bosses/boss_jazz.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 1228 | 函数数: 38 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `_on_boss_ready` | function | `_on_boss_ready()` |  |
| `_update_swing_intervals` | function | `_update_swing_intervals()` |  |
| `_define_phases` | function | `_define_phases()` |  |
| `_on_boss_process` | function | `_on_boss_process(delta: float)` |  |
| `_update_swing_rhythm` | function | `_update_swing_rhythm(delta: float)` |  |
| `_update_movement` | function | `_update_movement(delta: float)` |  |
| `_update_smoke_clouds` | function | `_update_smoke_clouds(delta: float)` |  |
| `_perform_attack` | function | `_perform_attack(attack: Dictionary)` |  |
| `_attack_sax_wave` | function | `_attack_sax_wave(attack: Dictionary, damage_mult: float)` |  |
| `_attack_swing_burst` | function | `_attack_swing_burst(attack: Dictionary, damage_mult: float)` |  |
| `_attack_call_and_response` | function | `_attack_call_and_response(attack: Dictionary, damage_mult: float)` |  |
| `register_response_success` | function | `register_response_success()` |  |
| `_attack_walking_bass_line` | function | `_attack_walking_bass_line(attack: Dictionary, damage_mult: float)` |  |
| `_spawn_bass_zone` | function | `_spawn_bass_zone(pos: Vector2, damage: float)` |  |
| `_attack_blue_note_scale` | function | `_attack_blue_note_scale(attack: Dictionary, damage_mult: float)` |  |
| `_attack_syncopation_teleport` | function | `_attack_syncopation_teleport(attack: Dictionary, damage_mult: float)` |  |
| `_spawn_afterimage` | function | `_spawn_afterimage(pos: Vector2)` |  |
| `_attack_smoke_cloud_barrage` | function | `_attack_smoke_cloud_barrage(attack: Dictionary, damage_mult: float)` |  |
| `_spawn_smoke_cloud` | function | `_spawn_smoke_cloud(pos: Vector2, damage: float)` |  |
| `_attack_free_improv` | function | `_attack_free_improv(attack: Dictionary, damage_mult: float)` |  |
| `check_downbeat_punishment` | function | `check_downbeat_punishment(attack_beat_position: float)` |  |
| `_trigger_downbeat_punishment` | function | `_trigger_downbeat_punishment()` |  |
| `_spawn_chord_bomb` | function | `_spawn_chord_bomb(target_pos: Vector2)` |  |
| `take_damage` | function | `take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, is_perfect_beat: bool = false)` |  |
| `_spawn_spotlights` | function | `_spawn_spotlights()` |  |
| `_update_spotlights` | function | `_update_spotlights(delta: float)` |  |
| `_spawn_sax_projectile` | function | `_spawn_sax_projectile(pos: Vector2, angle: float, speed: float, damage: float)` |  |
| `_spawn_swing_projectile` | function | `_spawn_swing_projectile(pos: Vector2, angle: float, speed: float, damage: float)` |  |
| `_spawn_call_projectile` | function | `_spawn_call_projectile(pos: Vector2, angle: float, speed: float, damage: float)` |  |
| `_add_projectile_to_container` | function | `_add_projectile_to_container(proj: Area2D)` |  |
| `_spawn_shockwave` | function | `_spawn_shockwave(pos: Vector2, radius: float, damage: float)` |  |
| `_on_phase_entered` | function | `_on_phase_entered(phase_index: int, _config: Dictionary)` |  |
| `_on_enrage` | function | `_on_enrage(level: int)` |  |
| `_start_enrage_jazz` | function | `_start_enrage_jazz()` |  |
| `_on_boss_beat` | function | `_on_boss_beat(_beat_index: int)` |  |
| `_calculate_movement_direction` | function | `_calculate_movement_direction()` |  |
| `_get_type_name` | function | `_get_type_name()` |  |
| `_notification` | function | `_notification(what: int)` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/entities/enemies/bosses/boss_jazz.gd
```
