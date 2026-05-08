# godot_project/scripts/ui/timbre_wheel_ui.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 621 | 函数数: 21 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `timbre_selected` | signal | `timbre_selected(timbre: int)` |  |
| `electronic_variant_toggled` | signal | `electronic_variant_toggled(is_electronic: bool)` |  |
| `wheel_opened` | signal | `wheel_opened()` |  |
| `wheel_closed` | signal | `wheel_closed()` |  |
| `_ready` | function | `_ready()` |  |
| `_process` | function | `_process(delta: float)` |  |
| `_unhandled_input` | function | `_unhandled_input(event: InputEvent)` |  |
| `_open_wheel` | function | `_open_wheel()` |  |
| `_close_wheel` | function | `_close_wheel()` |  |
| `_toggle_electronic_variant` | function | `_toggle_electronic_variant()` |  |
| `_update_selection` | function | `_update_selection(mouse_pos: Vector2)` |  |
| `_angle_diff` | function | `_angle_diff(a: float, b: float)` |  |
| `_draw` | function | `_draw()` |  |
| `_draw_gain_badge` | function | `_draw_gain_badge(pos: Vector2, text: String, color: Color, alpha: float)` |  |
| `_draw_detail_panel` | function | `_draw_detail_panel(font: Font, alpha: float)` |  |
| `_on_chapter_timbre_changed` | function | `_on_chapter_timbre_changed(new_timbre: int)` |  |
| `_on_phase_changed` | function | `_on_phase_changed(new_phase: int)` |  |
| `get_current_timbre` | function | `get_current_timbre()` |  |
| `is_electronic_variant` | function | `is_electronic_variant()` |  |
| `update_gain_highlights` | function | `update_gain_highlights()` |  |
| `get_timbre_list` | function | `get_timbre_list()` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/ui/timbre_wheel_ui.gd
```
