# godot_project/scripts/ui/dialog_system.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 446 | 函数数: 21 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `dialog_opened` | signal | `dialog_opened(dialog_id: String)` |  |
| `dialog_closed` | signal | `dialog_closed(dialog_id: String, result: String)` |  |
| `confirm_pressed` | signal | `confirm_pressed(dialog_id: String)` |  |
| `cancel_pressed` | signal | `cancel_pressed(dialog_id: String)` |  |
| `DialogType` | enum | `DialogType()` |  |
| `_ready` | function | `_ready()` |  |
| `_unhandled_input` | function | `_unhandled_input(event: InputEvent)` |  |
| `show_custom` | function | `show_custom(title: String, message: String, buttons: Array[Dictionary], dialog_id: String = "")` |  |
| `close_current` | function | `close_current()` |  |
| `is_showing` | function | `is_showing()` |  |
| `get_current_dialog_id` | function | `get_current_dialog_id()` |  |
| `_enqueue_dialog` | function | `_enqueue_dialog(data: Dictionary)` |  |
| `_show_next_in_queue` | function | `_show_next_in_queue()` |  |
| `_show_dialog` | function | `_show_dialog(data: Dictionary)` |  |
| `_close_dialog` | function | `_close_dialog(result: String)` |  |
| `_hide_immediate` | function | `_hide_immediate()` |  |
| `_build_buttons` | function | `_build_buttons(data: Dictionary)` |  |
| `_create_dialog_button` | function | `_create_dialog_button(text: String, accent: Color)` |  |
| `_on_confirm` | function | `_on_confirm()` |  |
| `_on_cancel` | function | `_on_cancel()` |  |
| `_build_ui` | function | `_build_ui()` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/ui/dialog_system.gd
```
