# godot_project/scripts/entities/enemies/bosses/boss_guido.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 855 | 函数数: 30 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `_on_boss_ready` | function | `_on_boss_ready()` |  |
| `_define_phases` | function | `_define_phases()` |  |
| `_setup_staff_lines` | function | `_setup_staff_lines()` |  |
| `_on_boss_process` | function | `_on_boss_process(delta: float)` |  |
| `_update_sacred_shield` | function | `_update_sacred_shield(delta: float)` |  |
| `_update_isolation_tracking` | function | `_update_isolation_tracking(delta: float)` |  |
| `_trigger_isolation_debuff` | function | `_trigger_isolation_debuff()` |  |
| `_check_chant_acceleration` | function | `_check_chant_acceleration()` |  |
| `_perform_attack` | function | `_perform_attack(attack: Dictionary)` |  |
| `_attack_staff_notation` | function | `_attack_staff_notation(attack: Dictionary, damage_mult: float)` |  |
| `_attack_chant_wall` | function | `_attack_chant_wall(attack: Dictionary, damage_mult: float)` |  |
| `_attack_neume_scatter` | function | `_attack_neume_scatter(attack: Dictionary, damage_mult: float)` |  |
| `_attack_solmization_barrage` | function | `_attack_solmization_barrage(attack: Dictionary, damage_mult: float)` |  |
| `_attack_voice_isolation` | function | `_attack_voice_isolation(attack: Dictionary, _damage_mult: float)` |  |
| `_attack_dual_chant_wall` | function | `_attack_dual_chant_wall(attack: Dictionary, damage_mult: float)` |  |
| `_attack_ascension_beams` | function | `_attack_ascension_beams(attack: Dictionary, damage_mult: float)` |  |
| `_attack_divine_chorus` | function | `_attack_divine_chorus(attack: Dictionary, damage_mult: float)` |  |
| `_spawn_note_projectile` | function | `_spawn_note_projectile(pos: Vector2, angle: float, speed: float, damage: float)` |  |
| `_spawn_wall_segment` | function | `_spawn_wall_segment(pos: Vector2, dir: Vector2, speed: float, damage: float, width: float)` |  |
| `_spawn_ascension_beam` | function | `_spawn_ascension_beam(target_pos: Vector2, damage: float)` |  |
| `_on_phase_entered` | function | `_on_phase_entered(phase_index: int, _config: Dictionary)` |  |
| `_on_enrage` | function | `_on_enrage(level: int)` |  |
| `_on_boss_beat` | function | `_on_boss_beat(_beat_index: int)` |  |
| `_calculate_movement_direction` | function | `_calculate_movement_direction()` |  |
| `register_player_timbre` | function | `register_player_timbre(timbre: String)` |  |
| `register_player_chord_use` | function | `register_player_chord_use()` |  |
| `_trigger_isolation_immunity` | function | `_trigger_isolation_immunity(timbre: String)` |  |
| `take_damage` | function | `take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, is_perfect_beat: bool = false)` |  |
| `_get_type_name` | function | `_get_type_name()` |  |
| `_notification` | function | `_notification(what: int)` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/entities/enemies/bosses/boss_guido.gd
```
