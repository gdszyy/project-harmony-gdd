# godot_project/scripts/ui/hall_of_harmony.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 491 | 函数数: 22 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `start_game_pressed` | signal | `start_game_pressed()` |  |
| `back_pressed` | signal | `back_pressed()` |  |
| `module_selected` | signal | `module_selected(module_key: String)` |  |
| `ui_upgrade_selected` | signal | `ui_upgrade_selected(upgrade_id: String, category: String)` |  |
| `_ready` | function | `_ready()` |  |
| `_process` | function | `_process(delta: float)` |  |
| `_load_state` | function | `_load_state()` |  |
| `_generate_stars` | function | `_generate_stars(count: int)` |  |
| `_build_ui_overlay` | function | `_build_ui_overlay()` |  |
| `_draw` | function | `_draw()` |  |
| `_draw_stars` | function | `_draw_stars()` |  |
| `_draw_central_nebula` | function | `_draw_central_nebula(center: Vector2)` |  |
| `_draw_constellations` | function | `_draw_constellations(center: Vector2, vp: Vector2)` |  |
| `_draw_constellation_pattern` | function | `_draw_constellation_pattern(module_key: String, center: Vector2, color: Color, is_hover: bool)` |  |
| `_draw_hover_info` | function | `_draw_hover_info(font: Font, vp: Vector2)` |  |
| `_gui_input` | function | `_gui_input(event: InputEvent)` |  |
| `_open_module` | function | `_open_module(module_key: String)` |  |
| `_on_sub_screen_back` | function | `_on_sub_screen_back()` |  |
| `_update_fragments_display` | function | `_update_fragments_display()` |  |
| `_on_fragments_changed` | function | `_on_fragments_changed(new_total: int)` |  |
| `open_panel` | function | `open_panel()` |  |
| `close_panel` | function | `close_panel()` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/ui/hall_of_harmony.gd
```
