# godot_project/scripts/entities/enemies/bosses/boss_pythagoras.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 1051 | 函数数: 38 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `_on_boss_ready` | function | `_on_boss_ready()` |  |
| `_define_phases` | function | `_define_phases()` |  |
| `_on_boss_process` | function | `_on_boss_process(delta: float)` |  |
| `take_damage` | function | `take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, is_perfect_beat: bool = false)` |  |
| `_reflect_damage` | function | `_reflect_damage(amount: float)` |  |
| `_spawn_reflect_visual` | function | `_spawn_reflect_visual()` |  |
| `_trigger_phase_two` | function | `_trigger_phase_two()` |  |
| `_play_phase2_transition` | function | `_play_phase2_transition()` |  |
| `_perform_attack` | function | `_perform_attack(attack: Dictionary)` |  |
| `_attack_octave_resonance` | function | `_attack_octave_resonance(attack: Dictionary, damage_mult: float)` |  |
| `_attack_fifth_oscillation` | function | `_attack_fifth_oscillation(attack: Dictionary, damage_mult: float)` |  |
| `_generate_fifth_safe_points` | function | `_generate_fifth_safe_points(shift_index: int)` |  |
| `_refresh_safe_point_visuals` | function | `_refresh_safe_point_visuals()` |  |
| `_attack_beat_trial` | function | `_attack_beat_trial(attack: Dictionary, damage_mult: float)` |  |
| `_update_harmony_shield` | function | `_update_harmony_shield(delta: float)` |  |
| `_attack_fourth_overlay` | function | `_attack_fourth_overlay(attack: Dictionary, damage_mult: float)` |  |
| `_attack_dissonant_pulse` | function | `_attack_dissonant_pulse(attack: Dictionary, damage_mult: float)` |  |
| `_update_irregular_pulse` | function | `_update_irregular_pulse(delta: float)` |  |
| `_activate_finale_chord` | function | `_activate_finale_chord()` |  |
| `_attack_finale_chord` | function | `_attack_finale_chord(attack: Dictionary, damage_mult: float)` |  |
| `record_offbeat_attack` | function | `record_offbeat_attack()` |  |
| `trigger_noise_punishment` | function | `trigger_noise_punishment()` |  |
| `_spawn_blasphemy_visual` | function | `_spawn_blasphemy_visual()` |  |
| `_spawn_chladni_visual` | function | `_spawn_chladni_visual(damage_mult: float)` |  |
| `_update_chladni` | function | `_update_chladni(delta: float)` |  |
| `_deactivate_chladni` | function | `_deactivate_chladni()` |  |
| `_spawn_boss_projectile` | function | `_spawn_boss_projectile(pos: Vector2, angle: float, speed: float, damage: float)` |  |
| `_spawn_shockwave` | function | `_spawn_shockwave(pos: Vector2, radius: float, damage: float)` |  |
| `_clear_all_projectiles` | function | `_clear_all_projectiles()` |  |
| `_on_phase_entered` | function | `_on_phase_entered(phase_index: int, _config: Dictionary)` |  |
| `_on_enrage` | function | `_on_enrage(level: int)` |  |
| `_start_enrage_barrage` | function | `_start_enrage_barrage()` |  |
| `_on_boss_beat` | function | `_on_boss_beat(_beat_index: int)` |  |
| `_calculate_movement_direction` | function | `_calculate_movement_direction()` |  |
| `_get_type_name` | function | `_get_type_name()` |  |
| `_boss_die` | function | `_boss_die()` |  |
| `_unlock_chord_crafting` | function | `_unlock_chord_crafting()` |  |
| `_notification` | function | `_notification(what: int)` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/entities/enemies/bosses/boss_pythagoras.gd
```
