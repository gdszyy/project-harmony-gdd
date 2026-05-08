# godot_project/scripts/entities/enemies/bosses/boss_beethoven.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 1010 | 函数数: 27 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `EmotionState` | enum | `EmotionState()` |  |
| `_on_boss_ready` | function | `_on_boss_ready()` |  |
| `_define_phases` | function | `_define_phases()` |  |
| `_on_boss_process` | function | `_on_boss_process(delta: float)` |  |
| `_update_dynamic_system` | function | `_update_dynamic_system(delta: float)` |  |
| `_update_emotion_visual` | function | `_update_emotion_visual(_delta: float)` |  |
| `_on_phase_entered` | function | `_on_phase_entered(phase_index: int, _config: Dictionary)` |  |
| `_perform_attack` | function | `_perform_attack(attack: Dictionary)` |  |
| `_attack_fate_motif` | function | `_attack_fate_motif(attack: Dictionary, mult: float)` |  |
| `_update_fate_motif` | function | `_update_fate_motif(delta: float)` |  |
| `_fire_fate_knock` | function | `_fire_fate_knock(is_long: bool)` |  |
| `_attack_crescendo_barrage` | function | `_attack_crescendo_barrage(attack: Dictionary, mult: float)` |  |
| `_attack_symphony_shockwave` | function | `_attack_symphony_shockwave(attack: Dictionary, mult: float)` |  |
| `_attack_moonlight_sonata` | function | `_attack_moonlight_sonata(attack: Dictionary, mult: float)` |  |
| `_attack_melancholy_rain` | function | `_attack_melancholy_rain(attack: Dictionary, mult: float)` |  |
| `_attack_eroica_charge` | function | `_attack_eroica_charge(attack: Dictionary, mult: float)` |  |
| `_update_charge` | function | `_update_charge(delta: float)` |  |
| `_spawn_charge_trail` | function | `_spawn_charge_trail()` |  |
| `_attack_ode_to_joy` | function | `_attack_ode_to_joy(attack: Dictionary, mult: float)` |  |
| `_attack_final_symphony` | function | `_attack_final_symphony(attack: Dictionary, mult: float)` |  |
| `_calculate_movement_direction` | function | `_calculate_movement_direction()` |  |
| `_on_boss_beat` | function | `_on_boss_beat(_beat_index: int)` |  |
| `register_player_attack_pattern` | function | `register_player_attack_pattern(pattern: String)` |  |
| `_check_repetition_penalty` | function | `_check_repetition_penalty()` |  |
| `_trigger_repetition_penalty` | function | `_trigger_repetition_penalty()` |  |
| `_on_enrage` | function | `_on_enrage(level: int)` |  |
| `_get_type_name` | function | `_get_type_name()` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/entities/enemies/bosses/boss_beethoven.gd
```
