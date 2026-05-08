# godot_project/scripts/ui/meta_progression_visualizer.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 966 | 函数数: 40 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `node_unlocked` | signal | `node_unlocked(node_id: String, category: String)` |  |
| `back_pressed` | signal | `back_pressed()` |  |
| `start_game_pressed` | signal | `start_game_pressed()` |  |
| `_load_skill_trees` | function | `_load_skill_trees()` |  |
| `_ready` | function | `_ready()` |  |
| `_process` | function | `_process(delta: float)` |  |
| `open_module` | function | `open_module(module_key: String)` |  |
| `open_panel` | function | `open_panel()` |  |
| `close_panel` | function | `close_panel()` |  |
| `_refresh_data` | function | `_refresh_data()` |  |
| `_update_node_states` | function | `_update_node_states()` |  |
| `_is_node_unlocked` | function | `_is_node_unlocked(node_id: String)` |  |
| `_get_node_level` | function | `_get_node_level(node_id: String)` |  |
| `_get_node_max_level` | function | `_get_node_max_level(node: Dictionary)` |  |
| `_get_node_cost` | function | `_get_node_cost(node_id: String)` |  |
| `_can_unlock_node` | function | `_can_unlock_node(node: Dictionary)` |  |
| `_calculate_positions` | function | `_calculate_positions()` |  |
| `_calc_vertical_layout` | function | `_calc_vertical_layout(nodes: Array, center: Vector2, vp: Vector2)` |  |
| `_calc_radial_layout` | function | `_calc_radial_layout(nodes: Array, center: Vector2)` |  |
| `_calc_constellation_layout` | function | `_calc_constellation_layout(nodes: Array, center: Vector2)` |  |
| `_calc_ring_layout` | function | `_calc_ring_layout(nodes: Array, center: Vector2)` |  |
| `_generate_bg_stars` | function | `_generate_bg_stars(count: int)` |  |
| `_draw` | function | `_draw()` |  |
| `_draw_layout_decoration` | function | `_draw_layout_decoration(center: Vector2, color: Color)` |  |
| `_draw_links` | function | `_draw_links(module_color: Color)` |  |
| `_draw_dashed_line` | function | `_draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float, dash_len: float)` |  |
| `_draw_nodes` | function | `_draw_nodes(font: Font, module_color: Color)` |  |
| `_draw_locked_node` | function | `_draw_locked_node(pos: Vector2, radius: float, node: Dictionary, font: Font, is_hover: bool)` |  |
| `_draw_unlockable_node` | function | `_draw_unlockable_node(pos: Vector2, radius: float, node: Dictionary, font: Font, module_color: Color, is_hover: bool)` |  |
| `_draw_unlocked_node` | function | `_draw_unlocked_node(pos: Vector2, radius: float, node: Dictionary, font: Font, module_color: Color, is_hover: bool)` |  |
| `_draw_unlock_animations` | function | `_draw_unlock_animations(module_color: Color)` |  |
| `_draw_hover_tooltip` | function | `_draw_hover_tooltip(font: Font, vp: Vector2)` |  |
| `_draw_nav_buttons` | function | `_draw_nav_buttons(font: Font, vp: Vector2)` |  |
| `_gui_input` | function | `_gui_input(event: InputEvent)` |  |
| `_try_unlock_node` | function | `_try_unlock_node(node_id: String)` |  |
| `_find_node` | function | `_find_node(node_id: String)` |  |
| `is_upgrade_meta_unlocked` | function | `is_upgrade_meta_unlocked(upgrade_id: String)` |  |
| `get_meta_bonus_for_stat` | function | `get_meta_bonus_for_stat(stat: String)` |  |
| `get_fatigue_resistance` | function | `get_fatigue_resistance(fatigue_type: String)` |  |
| `get_unlocked_modes` | function | `get_unlocked_modes()` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/ui/meta_progression_visualizer.gd
```
