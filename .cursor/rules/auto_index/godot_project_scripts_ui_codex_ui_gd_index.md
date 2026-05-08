# godot_project/scripts/ui/codex_ui.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 3979 | 函数数: 78 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `back_pressed` | signal | `back_pressed()` |  |
| `entry_viewed` | signal | `entry_viewed(entry_id: String)` |  |
| `_ready` | function | `_ready()` |  |
| `_process` | function | `_process(delta: float)` |  |
| `_load_unlock_state` | function | `_load_unlock_state()` |  |
| `_is_entry_unlocked` | function | `_is_entry_unlocked(entry_id: String)` |  |
| `_build_ui` | function | `_build_ui()` |  |
| `_build_header` | function | `_build_header()` |  |
| `_build_left_panel` | function | `_build_left_panel()` |  |
| `_build_right_panel` | function | `_build_right_panel()` |  |
| `_create_decorative_separator` | function | `_create_decorative_separator()` |  |
| `_create_vertical_separator` | function | `_create_vertical_separator()` |  |
| `_build_bg_3d_atmosphere` | function | `_build_bg_3d_atmosphere()` |  |
| `_get_data_dict` | function | `_get_data_dict(data_source: String)` |  |
| `_select_volume` | function | `_select_volume(idx: int)` |  |
| `_rebuild_subcat_bar` | function | `_rebuild_subcat_bar()` |  |
| `_rebuild_entry_list` | function | `_rebuild_entry_list()` |  |
| `_build_entry_row` | function | `_build_entry_row(entry_id: String, entry: Dictionary, is_unlocked: bool)` |  |
| `_show_entry_detail` | function | `_show_entry_detail(entry_id: String)` |  |
| `_show_locked_detail` | function | `_show_locked_detail(entry_id: String, entry: Dictionary)` |  |
| `_build_detail_stats` | function | `_build_detail_stats(entry_id: String, entry: Dictionary)` |  |
| `_add_stat_row` | function | `_add_stat_row(grid: GridContainer, label_text: String, value_text: String)` |  |
| `_is_enemy_entry` | function | `_is_enemy_entry(entry_id: String, entry: Dictionary)` |  |
| `_build_enemy_3d_preview` | function | `_build_enemy_3d_preview(entry_id: String, entry: Dictionary)` |  |
| `_create_enemy_3d_model` | function | `_create_enemy_3d_model(entry_id: String, entry: Dictionary)` |  |
| `_build_static_model` | function | `_build_static_model(root: Node3D)` |  |
| `_build_silence_model` | function | `_build_silence_model(root: Node3D)` |  |
| `_build_screech_model` | function | `_build_screech_model(root: Node3D)` |  |
| `_build_pulse_model` | function | `_build_pulse_model(root: Node3D)` |  |
| `_build_wall_model` | function | `_build_wall_model(root: Node3D)` |  |
| `_build_boss_pythagoras_model` | function | `_build_boss_pythagoras_model(root: Node3D)` |  |
| `_build_boss_guido_model` | function | `_build_boss_guido_model(root: Node3D)` |  |
| `_build_boss_bach_model` | function | `_build_boss_bach_model(root: Node3D)` |  |
| `_build_boss_mozart_model` | function | `_build_boss_mozart_model(root: Node3D)` |  |
| `_build_boss_beethoven_model` | function | `_build_boss_beethoven_model(root: Node3D)` |  |
| `_create_chapter_enemy_model` | function | `_create_chapter_enemy_model(entry_id: String, root: Node3D)` | 巨型函数 |
| `_cleanup_enemy_preview` | function | `_cleanup_enemy_preview()` |  |
| `_build_demo_section_25d` | function | `_build_demo_section_25d(entry_id: String, entry: Dictionary)` |  |
| `_create_demo_grid` | function | `_create_demo_grid()` |  |
| `_on_demo_cast` | function | `_on_demo_cast(entry_id: String)` |  |
| `_demo_cast_note` | function | `_demo_cast_note(config: Dictionary)` |  |
| `_demo_cast_note_modifier` | function | `_demo_cast_note_modifier(config: Dictionary)` |  |
| `_demo_cast_chord` | function | `_demo_cast_chord(config: Dictionary)` |  |
| `_demo_cast_rhythm` | function | `_demo_cast_rhythm(config: Dictionary)` |  |
| `_build_demo_spell_data` | function | `_build_demo_spell_data(white_key: int, modifier: int)` |  |
| `_spawn_demo_3d_projectile` | function | `_spawn_demo_3d_projectile(spell_data: Dictionary)` |  |
| `_spawn_demo_3d_impact` | function | `_spawn_demo_3d_impact(pos: Vector3, color: Color, radius: float)` |  |
| `_spawn_demo_chord_vfx` | function | `_spawn_demo_chord_vfx(chord_type: int)` |  |
| `_demo_chord_enhanced_projectile` | function | `_demo_chord_enhanced_projectile(color: Color)` |  |
| `_demo_chord_dot_projectile` | function | `_demo_chord_dot_projectile(color: Color)` |  |
| `_demo_chord_explosive` | function | `_demo_chord_explosive(color: Color)` |  |
| `_demo_chord_shockwave` | function | `_demo_chord_shockwave(color: Color)` |  |
| `_demo_chord_field` | function | `_demo_chord_field(color: Color)` |  |
| `_demo_chord_divine_strike` | function | `_demo_chord_divine_strike(color: Color)` |  |
| `_demo_chord_shield_heal` | function | `_demo_chord_shield_heal(color: Color)` |  |
| `_demo_chord_summon` | function | `_demo_chord_summon(color: Color)` |  |
| `_demo_chord_charged` | function | `_demo_chord_charged(color: Color)` |  |
| `_demo_chord_storm_field` | function | `_demo_chord_storm_field(color: Color)` |  |
| `_demo_chord_holy_domain` | function | `_demo_chord_holy_domain(color: Color)` |  |
| `_demo_chord_annihilation_ray` | function | `_demo_chord_annihilation_ray(color: Color)` |  |
| `_demo_chord_symphony_storm` | function | `_demo_chord_symphony_storm(color: Color)` |  |
| `_demo_chord_finale` | function | `_demo_chord_finale(color: Color)` |  |
| `_demo_chord_default` | function | `_demo_chord_default(color: Color)` |  |
| `_spawn_demo_modifier_vfx` | function | `_spawn_demo_modifier_vfx(modifier: int, spell_data: Dictionary)` |  |
| `_spawn_demo_rhythm_vfx` | function | `_spawn_demo_rhythm_vfx(rhythm_pattern: String, spell_data: Dictionary)` | 巨型函数 |
| `_clear_demo` | function | `_clear_demo()` |  |
| `_update_demo_status` | function | `_update_demo_status(text: String)` |  |
| `_get_modifier_display_name` | function | `_get_modifier_display_name(modifier: int)` |  |
| `_update_progress` | function | `_update_progress()` |  |
| `_on_volume_selected` | function | `_on_volume_selected(idx: int)` |  |
| `_on_subcat_selected` | function | `_on_subcat_selected(idx: int)` |  |
| `_on_entry_selected` | function | `_on_entry_selected(entry_id: String, _is_unlocked: bool)` |  |
| `_on_search_changed` | function | `_on_search_changed(new_text: String)` |  |
| `_on_back_pressed` | function | `_on_back_pressed()` |  |
| `_unhandled_input` | function | `_unhandled_input(event: InputEvent)` |  |
| `unlock_entry` | function | `unlock_entry(entry_id: String)` |  |
| `navigate_to_entry` | function | `navigate_to_entry(entry_id: String)` |  |
| `get_total_progress` | function | `get_total_progress()` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/ui/codex_ui.gd
```
