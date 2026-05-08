# godot_project/scripts/ui/boss_dialogue.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 712 | 函数数: 24 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `BossDialogue` | class_name | `BossDialogue()` |  |
| `dialogue_started` | signal | `dialogue_started(boss_key: String, dialogue_type: String)` |  |
| `dialogue_line_shown` | signal | `dialogue_line_shown(line_index: int, total_lines: int)` |  |
| `dialogue_completed` | signal | `dialogue_completed(boss_key: String, dialogue_type: String)` |  |
| `dialogue_skipped` | signal | `dialogue_skipped(boss_key: String)` |  |
| `_load_boss_dialogues` | function | `_load_boss_dialogues()` | 巨型函数 |
| `_ready` | function | `_ready()` |  |
| `_build_ui` | function | `_build_ui()` |  |
| `show_intro_dialogue` | function | `show_intro_dialogue(boss_key: String)` |  |
| `show_victory_dialogue` | function | `show_victory_dialogue(boss_key: String)` |  |
| `has_dialogue` | function | `has_dialogue(boss_key: String, dialogue_type: String = "intro")` |  |
| `is_dialogue_active` | function | `is_dialogue_active()` |  |
| `_start_dialogue` | function | `_start_dialogue(boss_key: String, dialogue_type: String)` |  |
| `_display_current_line` | function | `_display_current_line()` |  |
| `_end_dialogue` | function | `_end_dialogue()` |  |
| `_skip_dialogue` | function | `_skip_dialogue()` |  |
| `_process` | function | `_process(delta: float)` |  |
| `_input` | function | `_input(event: InputEvent)` |  |
| `_show_dialogue_animated` | function | `_show_dialogue_animated(on_complete: Callable)` |  |
| `_hide_dialogue_animated` | function | `_hide_dialogue_animated(on_complete: Callable)` |  |
| `_hide_dialogue` | function | `_hide_dialogue()` |  |
| `_get_boss_title_for_key` | function | `_get_boss_title_for_key(boss_key: String)` |  |
| `_update_portrait_color` | function | `_update_portrait_color(emotion: String)` |  |
| `_pause_game` | function | `_pause_game(paused: bool)` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/ui/boss_dialogue.gd
```
