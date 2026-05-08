# godot_project/scripts/systems/tutorial_manager.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 378 | 函数数: 22 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `tutorial_started` | signal | `tutorial_started()` |  |
| `tutorial_step_completed` | signal | `tutorial_step_completed(step_id: String)` |  |
| `tutorial_completed` | signal | `tutorial_completed()` |  |
| `tutorial_skipped` | signal | `tutorial_skipped()` |  |
| `TutorialStep` | enum | `TutorialStep()` |  |
| `_ready` | function | `_ready()` |  |
| `_process` | function | `_process(delta: float)` |  |
| `start_tutorial` | function | `start_tutorial()` |  |
| `skip_tutorial` | function | `skip_tutorial()` |  |
| `is_tutorial_active` | function | `is_tutorial_active()` |  |
| `is_tutorial_completed` | function | `is_tutorial_completed()` |  |
| `get_current_step` | function | `get_current_step()` |  |
| `should_show_tutorial` | function | `should_show_tutorial()` |  |
| `mark_tutorial_completed` | function | `mark_tutorial_completed()` |  |
| `_advance_to_next_step` | function | `_advance_to_next_step()` |  |
| `_complete_tutorial` | function | `_complete_tutorial()` |  |
| `_check_step_completion` | function | `_check_step_completion()` |  |
| `_on_step_condition_met` | function | `_on_step_condition_met()` |  |
| `_connect_game_signals` | function | `_connect_game_signals()` |  |
| `_on_enemy_killed` | function | `_on_enemy_killed(_pos: Vector2, _type: String)` |  |
| `_on_spell_cast` | function | `_on_spell_cast(spell_data: Dictionary)` |  |
| `_on_chord_resolved` | function | `_on_chord_resolved(_chord_data: Dictionary)` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/systems/tutorial_manager.gd
```
