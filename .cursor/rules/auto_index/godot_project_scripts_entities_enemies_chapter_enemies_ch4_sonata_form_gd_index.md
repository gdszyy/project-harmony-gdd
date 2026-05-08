# godot_project/scripts/entities/enemies/chapter_enemies/ch4_sonata_form.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 515 | 函数数: 21 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `SonataPhase` | enum | `SonataPhase()` |  |
| `_on_enemy_ready` | function | `_on_enemy_ready()` |  |
| `_on_enemy_process` | function | `_on_enemy_process(delta: float)` |  |
| `_check_phase_transition` | function | `_check_phase_transition()` |  |
| `_advance_phase` | function | `_advance_phase()` |  |
| `_execute_phase_attack` | function | `_execute_phase_attack()` |  |
| `_attack_exposition` | function | `_attack_exposition()` |  |
| `_attack_development` | function | `_attack_development()` |  |
| `_attack_recapitulation` | function | `_attack_recapitulation()` |  |
| `_execute_theme_a_dash` | function | `_execute_theme_a_dash()` |  |
| `_execute_theme_b_projectile` | function | `_execute_theme_b_projectile()` |  |
| `_fire_spread_projectiles` | function | `_fire_spread_projectiles()` |  |
| `_fire_single_projectile` | function | `_fire_single_projectile(dir: Vector2, damage: float, speed: float)` |  |
| `_calculate_movement_direction` | function | `_calculate_movement_direction()` |  |
| `_update_phase_visuals` | function | `_update_phase_visuals(delta: float)` |  |
| `_on_beat` | function | `_on_beat(_beat_index: int)` |  |
| `take_damage` | function | `take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, is_perfect_beat: bool = false)` |  |
| `_on_death_effect` | function | `_on_death_effect()` |  |
| `_fire_death_cadence` | function | `_fire_death_cadence()` |  |
| `get_current_phase_name` | function | `get_current_phase_name()` |  |
| `get_phase_progress` | function | `get_phase_progress()` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/entities/enemies/chapter_enemies/ch4_sonata_form.gd
```
