# godot_project/scripts/ui/sequencer_ui.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 550 | 函数数: 28 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `note_placed` | signal | `note_placed(cell_idx: int, note: int)` |  |
| `cell_cleared` | signal | `cell_cleared(cell_idx: int)` |  |
| `info_hover` | signal | `info_hover(title: String, desc: String, color: Color)` |  |
| `_ready` | function | `_ready()` |  |
| `_process` | function | `_process(delta: float)` |  |
| `_draw` | function | `_draw()` |  |
| `_draw_cell_content` | function | `_draw_cell_content(rect: Rect2, slot: Dictionary, font: Font)` |  |
| `_draw_playhead` | function | `_draw_playhead()` |  |
| `_gui_input` | function | `_gui_input(event: InputEvent)` |  |
| `_update_hover` | function | `_update_hover(pos: Vector2)` |  |
| `_get_cell_at` | function | `_get_cell_at(pos: Vector2)` |  |
| `_emit_cell_info` | function | `_emit_cell_info(idx: int)` |  |
| `_get_drag_data` | function | `_get_drag_data(at_position: Vector2)` |  |
| `_can_drop_data` | function | `_can_drop_data(at_position: Vector2, data)` |  |
| `_drop_data` | function | `_drop_data(at_position: Vector2, data)` |  |
| `_place_note` | function | `_place_note(idx: int, note_key: int)` |  |
| `_place_chord` | function | `_place_chord(idx: int, spell_id: String)` |  |
| `_clear_cell` | function | `_clear_cell(idx: int)` |  |
| `_swap_cells` | function | `_swap_cells(from_idx: int, to_idx: int)` |  |
| `_apply_modifier` | function | `_apply_modifier(idx: int, black_key_idx: int)` |  |
| `_push_undo` | function | `_push_undo()` |  |
| `undo` | function | `undo()` |  |
| `redo` | function | `redo()` |  |
| `_restore_state` | function | `_restore_state(state: Array)` |  |
| `refresh` | function | `refresh()` |  |
| `on_beat_tick` | function | `on_beat_tick(_beat_index: int)` |  |
| `_create_drag_preview` | function | `_create_drag_preview(text: String, color: Color)` |  |
| `_get_note_color_fallback` | function | `_get_note_color_fallback(note_key: int)` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/ui/sequencer_ui.gd
```
