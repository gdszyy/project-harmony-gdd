# godot_project/scripts/ui/chord_alchemy_panel_v3.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 640 | 函数数: 23 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `alchemy_completed` | signal | `alchemy_completed(chord_spell: Dictionary)` |  |
| `info_hover` | signal | `info_hover(title: String, desc: String, color: Color)` |  |
| `_load_chord_patterns` | function | `_load_chord_patterns()` |  |
| `note_index_to_semitone` | static_func | `note_index_to_semitone(note_idx: int)` |  |
| `get_note_display_name` | static_func | `get_note_display_name(note_idx: int)` |  |
| `get_note_color` | static_func | `get_note_color(note_idx: int)` |  |
| `_ready` | function | `_ready()` |  |
| `_process` | function | `_process(delta: float)` |  |
| `_draw` | function | `_draw()` |  |
| `_gui_input` | function | `_gui_input(event: InputEvent)` |  |
| `_update_hover` | function | `_update_hover(pos: Vector2)` |  |
| `_emit_slot_info` | function | `_emit_slot_info(idx: int)` |  |
| `_get_drag_data` | function | `_get_drag_data(at_position: Vector2)` |  |
| `_can_drop_data` | function | `_can_drop_data(at_position: Vector2, data)` |  |
| `_drop_data` | function | `_drop_data(at_position: Vector2, data)` |  |
| `_place_in_slot` | function | `_place_in_slot(slot_idx: int, note_key: int)` |  |
| `_remove_from_slot` | function | `_remove_from_slot(slot_idx: int)` |  |
| `_update_preview` | function | `_update_preview()` |  |
| `_execute_alchemy` | function | `_execute_alchemy()` |  |
| `return_unused_notes` | function | `return_unused_notes()` |  |
| `_get_filled_count` | function | `_get_filled_count()` |  |
| `refresh` | function | `refresh()` |  |
| `_create_drag_preview` | function | `_create_drag_preview(text: String, color: Color)` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/ui/chord_alchemy_panel_v3.gd
```
