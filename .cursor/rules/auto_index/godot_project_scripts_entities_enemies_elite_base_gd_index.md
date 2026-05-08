# godot_project/scripts/entities/enemies/elite_base.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 461 | 函数数: 24 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `elite_defeated` | signal | `elite_defeated(position: Vector2, elite_type: String)` |  |
| `elite_ability_used` | signal | `elite_ability_used(ability_name: String)` |  |
| `elite_enraged` | signal | `elite_enraged()` |  |
| `_on_enemy_ready` | function | `_on_enemy_ready()` |  |
| `_on_elite_ready` | function | `_on_elite_ready()` |  |
| `_define_elite_attacks` | function | `_define_elite_attacks()` |  |
| `_on_enemy_process` | function | `_on_enemy_process(delta: float)` |  |
| `_on_elite_process` | function | `_on_elite_process(_delta: float)` |  |
| `_update_elite_attacks` | function | `_update_elite_attacks(delta: float)` |  |
| `_execute_elite_attack` | function | `_execute_elite_attack()` |  |
| `_select_elite_attack` | function | `_select_elite_attack()` |  |
| `_perform_elite_attack` | function | `_perform_elite_attack(_attack: Dictionary)` |  |
| `_check_elite_enrage` | function | `_check_elite_enrage()` |  |
| `_on_elite_enrage` | function | `_on_elite_enrage()` |  |
| `_update_elite_aura` | function | `_update_elite_aura(_delta: float)` |  |
| `_apply_aura_effect` | function | `_apply_aura_effect(_target_node: Node2D, _distance: float)` |  |
| `_update_elite_visual` | function | `_update_elite_visual(_delta: float)` |  |
| `take_damage` | function | `take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, is_perfect_beat: bool = false)` |  |
| `_elite_die` | function | `_elite_die()` |  |
| `_on_elite_death_effect` | function | `_on_elite_death_effect()` |  |
| `_play_elite_death_animation` | function | `_play_elite_death_animation()` |  |
| `_spawn_elite_projectile` | function | `_spawn_elite_projectile(pos: Vector2, angle: float, speed: float, damage: float, color: Color = Color.WHITE)` |  |
| `get_elite_bar_data` | function | `get_elite_bar_data()` |  |
| `_notification` | function | `_notification(what: int)` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/entities/enemies/elite_base.gd
```
