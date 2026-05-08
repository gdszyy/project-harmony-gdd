# godot_project/scripts/ui/game_mechanics_panel.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 1063 | 函数数: 46 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `help_panel_closed` | signal | `help_panel_closed()` |  |
| `tutorial_completed` | signal | `tutorial_completed()` |  |
| `tutorial_step_advanced` | signal | `tutorial_step_advanced(step: int)` |  |
| `HelpTab` | enum | `HelpTab()` |  |
| `_ready` | function | `_ready()` |  |
| `_process` | function | `_process(delta: float)` |  |
| `_gui_input` | function | `_gui_input(event: InputEvent)` |  |
| `_unhandled_input` | function | `_unhandled_input(event: InputEvent)` |  |
| `_draw` | function | `_draw()` |  |
| `_get_dissonance_color` | function | `_get_dissonance_color(value: float)` |  |
| `_calculate_content_height` | function | `_calculate_content_height()` |  |
| `_update_density_from_manager` | function | `_update_density_from_manager()` |  |
| `_update_shield` | function | `_update_shield()` |  |
| `_on_fatigue_updated` | function | `_on_fatigue_updated(result: Dictionary)` |  |
| `_on_fatigue_level_changed` | function | `_on_fatigue_level_changed(level: MusicData.FatigueLevel)` |  |
| `_on_density_overload_changed` | function | `_on_density_overload_changed(is_overloaded: bool, accuracy_penalty: float)` |  |
| `_on_note_silenced` | function | `_on_note_silenced(_note: MusicData.WhiteKey, _duration: float)` |  |
| `_on_note_unsilenced` | function | `_on_note_unsilenced(_note: MusicData.WhiteKey)` |  |
| `_on_hp_changed` | function | `_on_hp_changed(_current_hp: float, _max_hp: float)` |  |
| `_on_chord_cast` | function | `_on_chord_cast(chord_data: Dictionary)` |  |
| `_on_mode_changed` | function | `_on_mode_changed(_mode_id: String)` |  |
| `_on_crit_updated` | function | `_on_crit_updated(crit_chance: float)` |  |
| `show_help_panel` | function | `show_help_panel()` |  |
| `hide_help_panel` | function | `hide_help_panel()` |  |
| `toggle_help_panel` | function | `toggle_help_panel()` |  |
| `start_tutorial` | function | `start_tutorial()` |  |
| `end_tutorial` | function | `end_tutorial()` |  |
| `_build_help_panel` | function | `_build_help_panel()` |  |
| `_fill_help_tab_content` | function | `_fill_help_tab_content(tab_idx: int)` |  |
| `_fill_circle_of_fifths_content` | function | `_fill_circle_of_fifths_content()` |  |
| `_fill_three_directions_content` | function | `_fill_three_directions_content()` |  |
| `_fill_gold_badge_content` | function | `_fill_gold_badge_content()` |  |
| `_fill_theory_breakthrough_content` | function | `_fill_theory_breakthrough_content()` |  |
| `_add_help_section_title` | function | `_add_help_section_title(text: String)` |  |
| `_add_help_paragraph` | function | `_add_help_paragraph(text: String)` |  |
| `_add_help_kv_block` | function | `_add_help_kv_block(items: Array)` |  |
| `_add_help_direction_block` | function | `_add_help_direction_block(title: String, color: Color, points: Array)` |  |
| `_on_help_tab_selected` | function | `_on_help_tab_selected(idx: int)` |  |
| `_play_help_show_animation` | function | `_play_help_show_animation()` |  |
| `_play_help_hide_animation` | function | `_play_help_hide_animation()` |  |
| `_on_help_overlay_clicked` | function | `_on_help_overlay_clicked(event: InputEvent)` |  |
| `_build_tutorial_ui` | function | `_build_tutorial_ui()` |  |
| `_show_tutorial_step` | function | `_show_tutorial_step(step: int)` |  |
| `_advance_tutorial` | function | `_advance_tutorial()` |  |
| `_end_tutorial` | function | `_end_tutorial()` |  |
| `create_help_button` | static_func | `create_help_button(callback: Callable)` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/ui/game_mechanics_panel.gd
```
