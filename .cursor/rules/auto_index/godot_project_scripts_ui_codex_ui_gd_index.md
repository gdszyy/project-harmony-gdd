# godot_project/scripts/ui/codex_ui.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 4004 | 函数数: 78 | 语言: gdscript
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
| `signals_and_theme_config` | 信号、配色、卷册配置、数据源和节点状态 | `grep -n '@section:signals_and_theme_config' godot_project/scripts/ui/codex_ui.gd` |
| `lifecycle_unlock_state` | 初始化、演示计时与图鉴解锁状态读取 | `grep -n '@section:lifecycle_unlock_state' godot_project/scripts/ui/codex_ui.gd` |
| `main_layout_building` | 图鉴主布局容器、左右面板与背景构建 | `grep -n '@section:main_layout_building' godot_project/scripts/ui/codex_ui.gd` |
| `header_navigation_ui` | 标题栏、返回按钮、进度与搜索输入构建 | `grep -n '@section:header_navigation_ui' godot_project/scripts/ui/codex_ui.gd` |
| `volume_navigation_ui` | 左侧卷册、子分类与条目导航构建 | `grep -n '@section:volume_navigation_ui' godot_project/scripts/ui/codex_ui.gd` |
| `detail_shell_ui` | 右侧详情面板骨架与装饰组件构建 | `grep -n '@section:detail_shell_ui' godot_project/scripts/ui/codex_ui.gd` |
| `background_atmosphere` | 3D 背景氛围层构建 | `grep -n '@section:background_atmosphere' godot_project/scripts/ui/codex_ui.gd` |
| `data_access` | 图鉴数据源解析与字典访问 | `grep -n '@section:data_access' godot_project/scripts/ui/codex_ui.gd` |
| `volume_subcategory_selection` | 卷册选择、子分类重建与搜索过滤 | `grep -n '@section:volume_subcategory_selection' godot_project/scripts/ui/codex_ui.gd` |
| `entry_list_rendering` | 条目列表刷新、锁定态与点击行构建 | `grep -n '@section:entry_list_rendering' godot_project/scripts/ui/codex_ui.gd` |
| `entry_detail_rendering` | 条目详情、锁定页与基础内容渲染 | `grep -n '@section:entry_detail_rendering' godot_project/scripts/ui/codex_ui.gd` |
| `detail_stats_table` | 详情统计卡片与属性表构建 | `grep -n '@section:detail_stats_table' godot_project/scripts/ui/codex_ui.gd` |
| `enemy_preview_models` | 敌人识别、3D 预览与章节/首领模型生成 | `grep -n '@section:enemy_preview_models' godot_project/scripts/ui/codex_ui.gd` |
| `enemy_preview_cleanup` | 敌人预览资源清理 | `grep -n '@section:enemy_preview_cleanup' godot_project/scripts/ui/codex_ui.gd` |
| `spell_demo_section` | 2.5D 法术演示面板、按钮与状态区域 | `grep -n '@section:spell_demo_section' godot_project/scripts/ui/codex_ui.gd` |
| `spell_demo_scene_helpers` | 演示网格、施法分发与基础法术数据构造 | `grep -n '@section:spell_demo_scene_helpers' godot_project/scripts/ui/codex_ui.gd` |
| `demo_projectile_impact` | 3D 演示弹体飞行与命中特效 | `grep -n '@section:demo_projectile_impact' godot_project/scripts/ui/codex_ui.gd` |
| `demo_chord_vfx_dispatch` | 和弦类型到演示 VFX 的分发 | `grep -n '@section:demo_chord_vfx_dispatch' godot_project/scripts/ui/codex_ui.gd` |
| `demo_chord_basic_forms` | 强化、持续、爆炸、冲击、场域、圣击、护盾、召唤与蓄力演示 | `grep -n '@section:demo_chord_basic_forms' godot_project/scripts/ui/codex_ui.gd` |
| `demo_chord_extended_forms` | 风暴、圣域、湮灭、交响风暴、终曲与默认演示 | `grep -n '@section:demo_chord_extended_forms' godot_project/scripts/ui/codex_ui.gd` |
| `demo_modifier_vfx` | 演示修饰符视觉反馈 | `grep -n '@section:demo_modifier_vfx' godot_project/scripts/ui/codex_ui.gd` |
| `demo_rhythm_vfx` | 演示节奏型视觉反馈 | `grep -n '@section:demo_rhythm_vfx' godot_project/scripts/ui/codex_ui.gd` |
| `progress_display` | 图鉴总进度统计与显示刷新 | `grep -n '@section:progress_display' godot_project/scripts/ui/codex_ui.gd` |
| `ui_callbacks` | 卷册、子分类、条目、搜索、返回与输入回调 | `grep -n '@section:ui_callbacks' godot_project/scripts/ui/codex_ui.gd` |
| `public_api` | 外部解锁、跳转与进度查询接口 | `grep -n '@section:public_api' godot_project/scripts/ui/codex_ui.gd` |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/ui/codex_ui.gd
```
