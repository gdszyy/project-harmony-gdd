# godot_project/scripts/ui/tooltip_system.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 406 | 函数数: 25 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `tooltip_shown` | signal | `tooltip_shown(tooltip_id: String)` |  |
| `tooltip_hidden` | signal | `tooltip_hidden()` |  |
| `_ready` | function | `_ready()` |  |
| `_process` | function | `_process(delta: float)` |  |
| `_input` | function | `_input(event: InputEvent)` |  |
| `register_tooltip` | function | `register_tooltip(tooltip_id: String, data: Dictionary)` |  |
| `unregister_tooltip` | function | `unregister_tooltip(tooltip_id: String)` |  |
| `request_show` | function | `request_show(tooltip_id: String)` |  |
| `request_show_custom` | function | `request_show_custom(data: Dictionary)` |  |
| `request_show_text` | function | `request_show_text(text: String)` |  |
| `request_hide` | function | `request_hide()` |  |
| `show_immediate` | function | `show_immediate(tooltip_id: String)` |  |
| `show_immediate_custom` | function | `show_immediate_custom(data: Dictionary)` |  |
| `hide_tooltip` | function | `hide_tooltip()` |  |
| `bind_tooltip` | function | `bind_tooltip(control: Control, tooltip_id: String)` |  |
| `bind_text_tooltip` | function | `bind_text_tooltip(control: Control, text: String)` |  |
| `clear_all` | function | `clear_all()` |  |
| `_display_tooltip` | function | `_display_tooltip()` |  |
| `_hide_tooltip` | function | `_hide_tooltip()` |  |
| `_update_content` | function | `_update_content(data: Dictionary)` |  |
| `_create_stat_row` | function | `_create_stat_row(stat: Dictionary)` |  |
| `_update_position` | function | `_update_position()` |  |
| `_get_rarity_text` | function | `_get_rarity_text(rarity: String)` |  |
| `_get_rarity_color` | function | `_get_rarity_color(rarity: String)` |  |
| `_build_ui` | function | `_build_ui()` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/ui/tooltip_system.gd
```
