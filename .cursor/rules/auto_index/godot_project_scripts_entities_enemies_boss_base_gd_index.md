# godot_project/scripts/entities/enemies/boss_base.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 741 | 函数数: 43 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `boss_phase_changed` | signal | `boss_phase_changed(phase_index: int, phase_name: String)` |  |
| `boss_enraged` | signal | `boss_enraged(enrage_level: int)` |  |
| `boss_vulnerability_started` | signal | `boss_vulnerability_started(duration: float)` |  |
| `boss_vulnerability_ended` | signal | `boss_vulnerability_ended()` |  |
| `boss_defeated` | signal | `boss_defeated()` |  |
| `boss_attack_started` | signal | `boss_attack_started(attack_name: String)` |  |
| `boss_attack_ended` | signal | `boss_attack_ended(attack_name: String)` |  |
| `boss_summon_minions` | signal | `boss_summon_minions(count: int, type: String)` |  |
| `_on_enemy_ready` | function | `_on_enemy_ready()` |  |
| `_on_boss_ready` | function | `_on_boss_ready()` |  |
| `_setup_boss_visual_enhancer` | function | `_setup_boss_visual_enhancer()` |  |
| `_define_phases` | function | `_define_phases()` |  |
| `_on_enemy_process` | function | `_on_enemy_process(delta: float)` |  |
| `_on_boss_process` | function | `_on_boss_process(_delta: float)` |  |
| `_check_phase_transition` | function | `_check_phase_transition()` |  |
| `_start_phase_transition` | function | `_start_phase_transition(new_phase: int)` |  |
| `_enter_phase` | function | `_enter_phase(phase_index: int)` |  |
| `_on_phase_entered` | function | `_on_phase_entered(_phase_index: int, _config: Dictionary)` |  |
| `_play_phase_transition_animation` | function | `_play_phase_transition_animation(new_phase: int)` |  |
| `_update_attacks` | function | `_update_attacks(delta: float)` |  |
| `_execute_next_attack` | function | `_execute_next_attack()` |  |
| `_select_attack` | function | `_select_attack()` |  |
| `_weighted_attack_select` | function | `_weighted_attack_select()` |  |
| `_adaptive_attack_select` | function | `_adaptive_attack_select()` |  |
| `_perform_attack` | function | `_perform_attack(_attack: Dictionary)` |  |
| `take_damage` | function | `take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, is_perfect_beat: bool = false)` |  |
| `_on_shield_broken` | function | `_on_shield_broken()` |  |
| `_start_vulnerability` | function | `_start_vulnerability(duration: float)` |  |
| `_update_vulnerability` | function | `_update_vulnerability(delta: float)` |  |
| `_update_shield` | function | `_update_shield(delta: float)` |  |
| `_update_enrage` | function | `_update_enrage(delta: float)` |  |
| `_on_enrage` | function | `_on_enrage(_level: int)` |  |
| `_update_summon` | function | `_update_summon(delta: float)` |  |
| `_spawn_minions` | function | `_spawn_minions()` |  |
| `_on_beat` | function | `_on_beat(_beat_index: int)` |  |
| `_on_boss_beat` | function | `_on_boss_beat(_beat_index: int)` |  |
| `_boss_die` | function | `_boss_die()` |  |
| `_drop_resonance_fragments` | function | `_drop_resonance_fragments()` |  |
| `_play_boss_death_animation` | function | `_play_boss_death_animation()` |  |
| `_update_boss_visual` | function | `_update_boss_visual(delta: float)` |  |
| `_notify_music_change` | function | `_notify_music_change(layer_name: String)` |  |
| `get_collision_data` | function | `get_collision_data()` |  |
| `get_boss_bar_data` | function | `get_boss_bar_data()` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/entities/enemies/boss_base.gd
```
