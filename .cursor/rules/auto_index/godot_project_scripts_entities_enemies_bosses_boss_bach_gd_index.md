# godot_project/scripts/entities/enemies/bosses/boss_bach.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 836 | 函数数: 19 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `_on_boss_ready` | function | `_on_boss_ready()` |  |
| `_define_phases` | function | `_define_phases()` |  |
| `_on_boss_process` | function | `_on_boss_process(delta: float)` |  |
| `_perform_attack` | function | `_perform_attack(attack: Dictionary)` |  |
| `_attack_fugue_subject` | function | `_attack_fugue_subject(attack: Dictionary, damage_mult: float, voices: int)` |  |
| `_attack_fugue_four_voices` | function | `_attack_fugue_four_voices(attack: Dictionary, damage_mult: float)` |  |
| `_attack_gear_barrage` | function | `_attack_gear_barrage(attack: Dictionary, damage_mult: float)` |  |
| `_attack_pipe_organ_blast` | function | `_attack_pipe_organ_blast(attack: Dictionary, damage_mult: float)` |  |
| `_attack_chaconne_ground_bass` | function | `_attack_chaconne_ground_bass(attack: Dictionary, damage_mult: float)` |  |
| `_attack_grand_fugue_finale` | function | `_attack_grand_fugue_finale(attack: Dictionary, damage_mult: float)` |  |
| `_spawn_gear_projectile` | function | `_spawn_gear_projectile(pos: Vector2, angle: float, speed: float, damage: float)` |  |
| `_on_phase_entered` | function | `_on_phase_entered(phase_index: int, _config: Dictionary)` |  |
| `_on_enrage` | function | `_on_enrage(level: int)` |  |
| `_on_boss_beat` | function | `_on_boss_beat(_beat_index: int)` |  |
| `_calculate_movement_direction` | function | `_calculate_movement_direction()` |  |
| `register_player_attack_type` | function | `register_player_attack_type(attack_type: String)` |  |
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
grep -n "函数名" godot_project/scripts/entities/enemies/bosses/boss_bach.gd
```
