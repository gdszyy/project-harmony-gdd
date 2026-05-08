# godot_project/scripts/ui/tutorial_hint_manager.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 909 | 函数数: 45 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `hint_shown` | signal | `hint_shown(text: String)` |  |
| `hint_dismissed` | signal | `hint_dismissed()` |  |
| `unlock_shown` | signal | `unlock_shown(unlock_type: String, unlock_name: String)` |  |
| `condition_met` | signal | `condition_met(condition_id: String)` |  |
| `step_indicator_updated` | signal | `step_indicator_updated(current: int, total: int)` |  |
| `highlight_started` | signal | `highlight_started(target_name: String)` |  |
| `highlight_ended` | signal | `highlight_ended(target_name: String)` |  |
| `_ready` | function | `_ready()` |  |
| `_process` | function | `_process(delta: float)` |  |
| `show_step_indicator` | function | `show_step_indicator(current_step: int, total_steps: int, title: String = "")` |  |
| `update_step_progress` | function | `update_step_progress(current_step: int, title: String = "")` |  |
| `hide_step_indicator` | function | `hide_step_indicator()` |  |
| `highlight_element` | function | `highlight_element(element_name: String, show_arrow: bool = true, bubble_text: String = "")` |  |
| `clear_highlight` | function | `clear_highlight()` |  |
| `show_hint` | function | `show_hint(text: String, duration: float = -1.0, highlight_ui: String = "")` |  |
| `show_unlock` | function | `show_unlock(unlock_type: String, unlock_name: String, message: String)` |  |
| `show_skip_button` | function | `show_skip_button(callback: Callable)` |  |
| `hide_skip_button` | function | `hide_skip_button()` |  |
| `register_conditional_hint` | function | `register_conditional_hint(condition_id: String, text: String, highlight_ui: String = "")` |  |
| `trigger_condition` | function | `trigger_condition(condition_id: String)` |  |
| `start_condition_tracker` | function | `start_condition_tracker(condition_id: String, timeout: float)` |  |
| `reset_condition_tracker` | function | `reset_condition_tracker(condition_id: String)` |  |
| `is_feature_unlocked` | function | `is_feature_unlocked(feature_name: String)` |  |
| `clear_all` | function | `clear_all()` |  |
| `_update_condition_trackers` | function | `_update_condition_trackers(delta: float)` |  |
| `_create_all_ui` | function | `_create_all_ui()` |  |
| `_create_step_indicator` | function | `_create_step_indicator()` |  |
| `_create_mask_overlay` | function | `_create_mask_overlay()` |  |
| `_create_mask_rect` | function | `_create_mask_rect(rect_name: String)` |  |
| `_create_arrow_indicator` | function | `_create_arrow_indicator()` |  |
| `_create_bubble_panel` | function | `_create_bubble_panel()` |  |
| `_create_hint_panel` | function | `_create_hint_panel()` |  |
| `_create_unlock_panel` | function | `_create_unlock_panel()` |  |
| `_create_skip_button` | function | `_create_skip_button()` |  |
| `_position_mask_around` | function | `_position_mask_around(target: Control)` |  |
| `_update_highlight_position` | function | `_update_highlight_position()` |  |
| `_get_global_rect` | function | `_get_global_rect(control: Control)` |  |
| `_show_arrow_at` | function | `_show_arrow_at(target: Control)` |  |
| `_hide_arrow` | function | `_hide_arrow()` |  |
| `_show_bubble` | function | `_show_bubble(target: Control, text: String)` |  |
| `_hide_bubble` | function | `_hide_bubble()` |  |
| `_highlight_ui_element_light` | function | `_highlight_ui_element_light(element_name: String, duration: float)` |  |
| `_find_ui_element` | function | `_find_ui_element(element_name: String)` |  |
| `_kill_tween` | function | `_kill_tween(tween: Tween)` |  |
| `_on_skip_pressed` | function | `_on_skip_pressed()` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/ui/tutorial_hint_manager.gd
```
