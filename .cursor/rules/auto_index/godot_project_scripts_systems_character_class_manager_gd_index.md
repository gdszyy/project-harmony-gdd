# godot_project/scripts/systems/character_class_manager.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 270 | 函数数: 22 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `class_applied` | signal | `class_applied(class_id: String, applied_class_name: String)` |  |
| `passive_triggered` | signal | `passive_triggered(passive_id: String, effect: Dictionary)` |  |
| `auto_cleanse_triggered` | signal | `auto_cleanse_triggered()` |  |
| `_ready` | function | `_ready()` |  |
| `_process` | function | `_process(delta: float)` |  |
| `apply_class` | function | `apply_class(class_id: String = "")` |  |
| `reset` | function | `reset()` |  |
| `_apply_stats` | function | `_apply_stats()` |  |
| `get_damage_multiplier` | function | `get_damage_multiplier()` |  |
| `get_cooldown_multiplier` | function | `get_cooldown_multiplier()` |  |
| `get_xp_multiplier` | function | `get_xp_multiplier()` |  |
| `_setup_initial_sequencer` | function | `_setup_initial_sequencer()` |  |
| `_apply_visual_style` | function | `_apply_visual_style()` |  |
| `_init_passive` | function | `_init_passive()` |  |
| `_update_passive` | function | `_update_passive(delta: float)` |  |
| `get_current_class_info` | function | `get_current_class_info()` |  |
| `get_current_class_name` | function | `get_current_class_name()` |  |
| `get_current_class_title` | function | `get_current_class_title()` |  |
| `get_current_class_description` | function | `get_current_class_description()` |  |
| `get_passive_description` | function | `get_passive_description()` |  |
| `get_lore` | function | `get_lore()` |  |
| `get_all_classes_summary` | function | `get_all_classes_summary()` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/systems/character_class_manager.gd
```
