# godot_project/scripts/ui/circle_of_fifths_upgrade_v3.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 1601 | 函数数: 49 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `upgrade_chosen` | signal | `upgrade_chosen(upgrade: Dictionary)` |  |
| `Phase` | enum | `Phase()` |  |
| `_load_upgrade_database` | function | `_load_upgrade_database()` |  |
| `_resolve_timbre_enums` | function | `_resolve_timbre_enums(upgrades: Array)` |  |
| `_use_legacy_data` | function | `_use_legacy_data()` | 巨型函数 |
| `_ready` | function | `_ready()` |  |
| `_process` | function | `_process(delta: float)` |  |
| `_gui_input` | function | `_gui_input(event: InputEvent)` |  |
| `_unhandled_key_input` | function | `_unhandled_key_input(event: InputEvent)` |  |
| `_handle_mouse_motion` | function | `_handle_mouse_motion(pos: Vector2)` |  |
| `_handle_left_click` | function | `_handle_left_click(pos: Vector2)` |  |
| `_handle_right_click` | function | `_handle_right_click()` |  |
| `show_upgrade_options` | function | `show_upgrade_options()` |  |
| `hide_panel` | function | `hide_panel()` |  |
| `_setup_direction_select` | function | `_setup_direction_select()` |  |
| `_setup_card_select` | function | `_setup_card_select(direction: String)` |  |
| `_setup_breakthrough` | function | `_setup_breakthrough()` |  |
| `_should_trigger_breakthrough` | function | `_should_trigger_breakthrough()` |  |
| `_is_breakthrough_acquired` | function | `_is_breakthrough_acquired(event_id: String)` |  |
| `_select_direction` | function | `_select_direction(direction: String)` |  |
| `_generate_options_for_direction` | function | `_generate_options_for_direction(direction: String)` |  |
| `_inject_key_context` | function | `_inject_key_context(upgrade: Dictionary)` |  |
| `_create_inscription_option` | function | `_create_inscription_option(inscription: Dictionary)` |  |
| `_select_option` | function | `_select_option(option_index: int)` |  |
| `_select_breakthrough` | function | `_select_breakthrough()` |  |
| `_process_note_acquisition` | function | `_process_note_acquisition(upgrade: Dictionary)` |  |
| `_play_card_confirm_animation` | function | `_play_card_confirm_animation(card_index: int)` |  |
| `_play_breakthrough_confirm_animation` | function | `_play_breakthrough_confirm_animation()` |  |
| `_deactivate_compass` | function | `_deactivate_compass()` |  |
| `_is_meta_unlocked_upgrade` | function | `_is_meta_unlocked_upgrade(upgrade: Dictionary)` |  |
| `_draw` | function | `_draw()` |  |
| `_draw_nebula_core` | function | `_draw_nebula_core(alpha: float)` |  |
| `_draw_connection_web` | function | `_draw_connection_web(alpha: float)` |  |
| `_draw_outer_ring` | function | `_draw_outer_ring(font: Font, alpha: float)` |  |
| `_draw_middle_ring` | function | `_draw_middle_ring(font: Font, alpha: float)` |  |
| `_draw_current_key_highlight` | function | `_draw_current_key_highlight(font: Font, alpha: float)` |  |
| `_draw_title` | function | `_draw_title(font: Font, alpha: float)` |  |
| `_draw_direction_runes` | function | `_draw_direction_runes(font: Font)` |  |
| `_draw_direction_trail` | function | `_draw_direction_trail(direction: String, color: Color, alpha: float)` |  |
| `_draw_upgrade_cards` | function | `_draw_upgrade_cards(font: Font)` |  |
| `_draw_breakthrough_event` | function | `_draw_breakthrough_event(font: Font)` |  |
| `_draw_rounded_rect` | function | `_draw_rounded_rect(rect: Rect2, color: Color, radius: float)` |  |
| `_draw_rounded_rect_outline` | function | `_draw_rounded_rect_outline(rect: Rect2, color: Color, radius: float, width: float)` |  |
| `_wrap_text` | function | `_wrap_text(text: String, font: Font, max_width: float, font_size: int)` |  |
| `_get_category_icon` | function | `_get_category_icon(option: Dictionary)` |  |
| `_key_index_to_angle` | function | `_key_index_to_angle(index: int)` |  |
| `_key_name_to_white_key` | function | `_key_name_to_white_key(key_name: String)` |  |
| `_get_direction_display_name` | function | `_get_direction_display_name(direction: String)` |  |
| `_on_game_state_changed` | function | `_on_game_state_changed(new_state: GameManager.GameState)` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/ui/circle_of_fifths_upgrade_v3.gd
```
