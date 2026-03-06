# Bug-5 修复报告：UI 脚本常量表达式错误、缺失标识符及类型推断问题

**修复分支**: `bugfix/bug-5-ui-scripts`  
**修复日期**: 2026-03-06  
**修复文件数**: 24 个文件  
**Commit**: af4c637

---

## 修复摘要

本次修复解决了 Godot 项目 Project Harmony 中约 30 个 UI 脚本文件的三类错误。

---

## A 类修复：const 非常量表达式（14 个文件）

**问题**: Godot 4.x 要求 `const` 的值必须是编译期常量，而 `UIColors.with_alpha()` 是运行时函数调用，不能用于 `const` 初始化。

**修复方案**: 将 `const X := UIColors.with_alpha(...)` 改为 `static var X := UIColors.with_alpha(...)`

| 文件 | 修复内容 |
|------|---------|
| ammo_ring_hud.gd | const COLOR_* → static var COLOR_* |
| chord_alchemy_panel_v3.gd | const SLOT_FILLED_BG 等 → static var |
| codex_ui.gd | const COL_DEMO_BORDER 等 → static var |
| dps_overlay.gd | const GRAPH_BG → static var |
| game_mechanics_panel.gd | const 颜色变量 → static var |
| integrated_composer.gd | const 颜色变量 → static var |
| manual_slot_config_v3.gd | const SLOT_FILLED_BG 等 → static var |
| meta_progression_visualizer.gd | const 颜色变量 → static var |
| note_inventory_ui.gd | const 颜色变量 → static var |
| pause_menu.gd | const COLOR_OVERLAY → static var |
| sequencer_ui.gd | const CELL_FILLED_BG 等 → static var |
| settings_menu.gd | const 颜色变量 → static var |
| spellbook_panel_v3.gd | const CARD_BG 等 → static var |
| summon_hud.gd | const 颜色变量 → static var |

---

## B 类修复：缺失标识符/常量定义（8 个文件）

| 文件 | 添加的定义 |
|------|-----------|
| chord_alchemy_panel_v3.gd | `SPELL_FORM_COLORS`, `BLACK_KEY_COLORS`, `MIN_NOTES_FOR_CHORD` |
| circle_of_fifths_upgrade_v3.gd | `COMPASS_CORE_RADIUS`, `RUNE_RADIUS` 常量别名 |
| game_mechanics_panel.gd | `PANEL_WIDTH`, `LABEL_WIDTH`, `BAR_WIDTH`, `BAR_HEIGHT`, `BAR_GAP` |
| manual_slot_config_v3.gd | `SPELL_FORM_COLORS` |
| spellbook_panel_v3.gd | `SPELL_FORM_COLORS` |
| sequencer_ui.gd | 修复 `IntegratedComposer` 引用（改用 `UIColors.get_note_color_by_int`） |
| upgrade_card.gd | `CARD_CORNER_RADIUS`, `TOP_BAR_HEIGHT` 常量别名 |
| integrated_composer.gd | 添加 `class_name IntegratedComposer` 声明 |

---

## C 类修复：类型推断/API 错误（10 个文件）

| 文件 | 修复内容 |
|------|---------|
| hud.gd | `MusicData.get("WHITE_KEY_STATS")` → 直接访问 `MusicData.WHITE_KEY_STATS` |
| codex_unlock_popup.gd | `Array.get(volume, "?")` → `array[volume] if ... else "?"` |
| spectral_fatigue_indicator.gd | `step(0.9, x)` → `(1.0 if x >= 0.9 else 0.0)` |
| tooltip_system.gd | `func hide()` → `func hide_tooltip()` 避免覆盖原生方法 |
| damage_number.gd | `var X := UIColors.Y` → `var X: Color = UIColors.Y` |
| fatigue_meter.gd | `var X := UIColors.Y` → `var X: Color = UIColors.Y` |
| hp_bar.gd | `var X := UIColors.Y` → `var X: Color = UIColors.Y` |
| rhythm_indicator.gd | `var X := UIColors.Y` → `var X: Color = UIColors.Y` |
| circle_of_fifths_upgrade_v3.gd | `var BG_OVERLAY := ...` → `var BG_OVERLAY: Color = ...` |
| meta_progression_visualizer.gd | 类级别颜色变量添加 `: Color` 类型注解 |

---

## 验证

所有修复均遵循 Godot 4.x GDScript 规范：
- `static var` 用于需要运行时初始化的类级别变量
- `const` 仅用于编译期常量（字面量或其他 const 的引用）
- 显式类型注解消除类型推断歧义
- API 调用符合 Godot 4.x 标准（`Array` 不支持带默认值的 `.get()`）
