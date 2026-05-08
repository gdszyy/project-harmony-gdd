# godot_project/scripts/ui/run_results_screen.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 529 | 函数数: 26 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `retry_pressed` | signal | `retry_pressed()` |  |
| `go_to_hall_pressed` | signal | `go_to_hall_pressed()` |  |
| `main_menu_pressed` | signal | `main_menu_pressed()` |  |
| `Phase` | enum | `Phase()` |  |
| `_ready` | function | `_ready()` |  |
| `show_results` | function | `show_results(run_data: Dictionary)` |  |
| `hide_results` | function | `hide_results()` |  |
| `_build_canvas` | function | `_build_canvas()` |  |
| `_ResultsCanvas` | class | `_ResultsCanvas()` |  |
| `_process` | function | `_process(delta: float)` |  |
| `_draw` | function | `_draw()` |  |
| `_gui_input` | function | `_gui_input(event: InputEvent)` |  |
| `_prepare_stat_items` | function | `_prepare_stat_items()` |  |
| `_calculate_evaluation` | function | `_calculate_evaluation()` |  |
| `_calculate_fallback_result` | function | `_calculate_fallback_result(run_data: Dictionary)` |  |
| `_update_stats_phase` | function | `_update_stats_phase(delta: float)` |  |
| `_update_fragments_phase` | function | `_update_fragments_phase(delta: float)` |  |
| `_advance_phase` | function | `_advance_phase()` |  |
| `_generate_stars` | function | `_generate_stars(count: int)` |  |
| `_do_draw` | function | `_do_draw(canvas: Control)` |  |
| `_draw_stats_phase` | function | `_draw_stats_phase(canvas: Control, center: Vector2, font: Font, vp: Vector2)` |  |
| `_draw_fragments_phase` | function | `_draw_fragments_phase(canvas: Control, center: Vector2, font: Font, vp: Vector2)` |  |
| `_draw_actions_phase` | function | `_draw_actions_phase(canvas: Control, center: Vector2, font: Font, vp: Vector2)` |  |
| `_draw_phase_indicator` | function | `_draw_phase_indicator(canvas: Control, font: Font, vp: Vector2)` |  |
| `_handle_input` | function | `_handle_input(event: InputEvent)` |  |
| `_format_time` | function | `_format_time(seconds: float)` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/ui/run_results_screen.gd
```
