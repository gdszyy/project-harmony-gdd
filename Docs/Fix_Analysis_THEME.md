# Project Harmony: UI 主题与颜色系统深度分析及重构方案

**作者**: Manus AI
**日期**: 2026-02-12
**版本**: 1.0

---

## 1. 问题概述 (Executive Summary)

本次分析旨在解决 Project Harmony 验收报告中指出的两个 **Critical** 级别问题：【THEME-01】UI主题管理灾难 和 【THEME-02】核心颜色定义不一致。当前项目中存在三种独立的颜色和主题管理方案（`GlobalTheme.tres`、`UIColors` Autoload 单例、脚本内硬编码），三者严重割裂，导致了维护性、一致性和扩展性的灾难。据统计，超过 **95%** 的UI脚本直接使用硬编码颜色值，而核心的游戏逻辑颜色（如 `NOTE_COLORS`）在多个文件中存在不一致的重复定义。

本报告将深度剖析这三个系统的现状，量化其影响范围，并提出一个以 **`UIColors` 为动态颜色中心、`GlobalTheme.tres` 为静态样式基础** 的统一化重构方案。该方案旨在根除硬编码，统一颜色定义，并建立清晰、可维护的 UI 主题架构。

## 2. 深度分析

### 2.1. 【THEME-01】UI 主题管理灾难：三种方案的割裂

项目当前存在三种主题方案，但它们之间缺乏协作，形成了信息孤岛。

#### 方案 A: `GlobalTheme.tres` (静态主题资源)

- **文件路径**: `godot_project/themes/GlobalTheme.tres`
- **内容**: 定义了 Godot 基础控件（如 `Button`, `Panel`, `Label` 等）的静态样式（`StyleBoxFlat`），包括背景色、边框、圆角、阴影等。
- **问题**: **应用范围极小**。在项目全部 **87** 个 `.tscn` 场景文件中，仅有 **3** 个文件 (`main_menu.tscn`, `pause_menu.tscn`, `settings_menu.tscn`) 应用了此主题。这意味着其余 **96.5%** 的场景未使用任何统一的静态主题，其控件外观完全依赖于默认样式或局部覆盖。

#### 方案 B: `UIColors.gd` (Autoload 全局颜色单例)

- **文件路径**: `godot_project/scripts/autoload/ui_colors.gd`
- **内容**: 定义了全局的、语义化的颜色常量，如 `PRIMARY_BG`, `ACCENT`, `TEXT_PRIMARY`, `RARITY_EPIC` 等，意图作为项目中所有颜色的“单一事实来源”。
- **问题**: **几乎未被使用**。在 `godot_project/scripts/ui/` 目录下 **57** 个UI脚本中，仅有 **1** 个文件 (`tutorial_hint_manager.gd`) 引用了 `UIColors`。这直接导致了方案 C 的泛滥。

#### 方案 C: 硬编码颜色 (Widespread Hardcoding)

- **表现**: 在 GDScript 脚本中大量直接使用 `Color("#RRGGBB")` 或 `Color(r, g, b)` 的形式定义颜色。
- **问题**: **失控且泛滥**。这是当前最主要的颜色定义方式，构成了技术债务的核心。
  - **统计**: 在 `scripts/ui/` 目录中，共发现 **1009** 处硬编码的 `Color()` 调用。
  - **重复定义**: 许多与 `UIColors.gd` 中完全相同的颜色值被反复定义。例如：
    - `#9D6FFF` (ACCENT) 在脚本中硬编码出现了 **53** 次。
    - `#EAE6FF` (TEXT_PRIMARY) 出现了 **33** 次。
    - `#141026` (PANEL_BG) 出现了 **24** 次。
  - **维护噩梦**: 任何设计上的颜色调整都需要在数十个文件中进行搜索和替换，极易出错和遗漏。

下表展示了硬编码颜色问题最严重的文件：

| 文件名                        | 硬编码 `Color()` 数量 |
| ----------------------------- | ----------------------- |
| `game_mechanics_panel.gd`     | 62                      |
| `meta_progression_visualizer.gd`| 55                      |
| `run_results_screen.gd`       | 42                      |
| `mode_selection_screen.gd`    | 42                      |
| `chord_alchemy_panel_v3.gd`   | 42                      |
| `boss_dialogue.gd`            | 37                      |
| `codex_ui.gd`                 | 34                      |
| `note_inventory_ui.gd`        | 33                      |
| `manual_slot_config_v3.gd`    | 33                      |
| `hall_of_harmony.gd`          | 33                      |

### 2.2. 【THEME-02】核心颜色定义不一致: `NOTE_COLORS` 的混乱

`NOTE_COLORS` 是游戏核心机制“音符”的视觉标识，其一致性至关重要。然而，分析发现它在多个文件中存在 **4** 个不同版本的定义，颜色值和键类型（`String` vs `int`）均不相同。

| 文件路径                                | 键类型 | C/0 (红色/青色) | D/1 (橙色/蓝色) | E/2 (黄色/绿色) | G/4 (青色/红色) |
| --------------------------------------- | ------ | --------------- | --------------- | --------------- | --------------- |
| `autoload/ui_colors.gd`                 | String | `#FF6B6B` (红)   | `#FF8C42` (橙)   | `#FFD700` (黄)   | `#4DFFF3` (青)   |
| `ui/ammo_ring_hud.gd`                   | String | `#00FFD4` (青)   | `#3380FF` (蓝)   | `#66FFB2` (绿)   | `#FFD700` (金)   |
| `ui/note_inventory_ui.gd`               | int    | `#00FFD4` (青)   | `#0088FF` (蓝)   | `#66FF66` (绿)   | `#FF4444` (红)   |
| `ui/chord_alchemy_panel_v3.gd`          | int    | `#00FFD4` (青)   | `#0088FF` (蓝)   | `#66FF66` (绿)   | `#FF4444` (红)   |
| `ui/spellbook_panel_v3.gd`              | int    | `#00FFD4` (青)   | `#0088FF` (蓝)   | `#66FF66` (绿)   | `#FF4444` (红)   |

- **`ui_colors.gd`**: 使用音名（"C", "D"...）作为键，颜色遵循彩虹光谱（红橙黄绿青蓝紫），符合直觉。
- **`ammo_ring_hud.gd`**: 同样使用音名，但颜色值完全不同，例如 C 是青色而非红色。
- **其他 UI 文件**: 使用整数索引（0-6）作为键，颜色值又是一套体系（青、蓝、绿、紫、红、橙、粉），且这套体系在多个文件中重复定义。

这种不一致性不仅造成了视觉上的混乱，也使得依赖这些颜色的游戏逻辑变得脆弱和难以理解。

## 3. 统一化重构方案

**核心原则**: 建立清晰的职责边界，实现“关注点分离”。

1.  **`GlobalTheme.tres`**: **负责所有标准 UI 控件的静态基础样式**。所有 `.tscn` 文件都应应用此主题，作为视觉风格的基石。
2.  **`UIColors.gd`**: **负责所有动态的、通过脚本控制的颜色**。所有 GDScript 代码中出现的颜色都必须引用自 `UIColors` 的常量或方法。
3.  **硬编码**: **必须被彻底根除**。

### 3.1. 步骤一: 统一 `NOTE_COLORS` 定义

1.  **确立标准**: 以 `autoload/ui_colors.gd` 中的定义为唯一标准。它使用字符串键，语义清晰，且遵循彩虹色谱，便于记忆和扩展。
2.  **修改 `UIColors.gd`**: 确保 `NOTE_COLORS` 的键为大写音名（"C", "D", "E", "F", "G", "A", "B"），并提供一个辅助函数 `get_note_color_by_int(note_index: int)` 以兼容旧的整数索引逻辑，减少对其他脚本的侵入式修改。

    ```gdscript
    # In ui_colors.gd
    const NOTE_NAMES = ["C", "D", "E", "F", "G", "A", "B"]

    const NOTE_COLORS: Dictionary = {
        "C": Color("#FF6B6B"), # 红
        "D": Color("#FF8C42"), # 橙
        "E": Color("#FFD700"), # 黄
        "F": Color("#4DFF80"), # 绿
        "G": Color("#4DFFF3"), # 青
        "A": Color("#4D8BFF"), # 蓝
        "B": Color("#9D6FFF"), # 紫
    }

    static func get_note_color(note_name: String) -> Color:
        return NOTE_COLORS.get(note_name.to_upper(), TEXT_PRIMARY)

    static func get_note_color_by_int(note_index: int) -> Color:
        if note_index >= 0 and note_index < NOTE_NAMES.size():
            return get_note_color(NOTE_NAMES[note_index])
        return TEXT_PRIMARY
    ```

3.  **移除冗余定义**: 删除 `ammo_ring_hud.gd`, `chord_alchemy_panel_v3.gd`, `note_inventory_ui.gd`, `spellbook_panel_v3.gd` 等文件中的 `NOTE_COLORS` 常量定义。
4.  **替换调用点**: 将所有旧的 `NOTE_COLORS.get(...)` 调用替换为 `UIColors.get_note_color_by_int(...)` 或 `UIColors.get_note_color(...)`。

### 3.2. 步骤二: 全面消除硬编码颜色

这是本次重构的核心工作。对于 `scripts/ui/` 目录下的每一个 `.gd` 文件，执行以下操作：

1.  **识别硬编码**: 找出所有 `const ... := Color(...)` 和直接使用的 `Color(...)`。
2.  **匹配或创建常量**: 
    - 如果颜色值已在 `UIColors` 中定义，直接替换为 `UIColors.CONSTANT_NAME`。
    - 如果是 `UIColors` 中颜色的变体（如不同透明度），使用 `UIColors.with_alpha(UIColors.CONSTANT_NAME, 0.5)`。
    - 如果是全新的、具有特定语义的颜色，在 `UIColors.gd` 中为其添加一个新的语义化常量（例如 `const BUTTON_DISABLED_BORDER := Color("...")`）。
3.  **修改代码**: 将硬编码颜色替换为对 `UIColors` 的引用。

以下是针对 `ammo_ring_hud.gd` 文件的部分修改示例：

**File**: `godot_project/scripts/ui/ammo_ring_hud.gd`

| Line | Original Code                                     | Refactored Code                                      |
| :--- | :------------------------------------------------ | :--------------------------------------------------- |
| 22   | `const NOTE_COLORS: Dictionary = { ... }`         | *(删除整个常量定义)*                                 |
| 32   | `const COLOR_INACTIVE := Color(0.2, 0.2, 0.3, 0.4)` | `const COLOR_INACTIVE := UIColors.with_alpha(UIColors.TEXT_DIM, 0.4)` |
| 33   | `const COLOR_DEPLETED := Color(0.3, 0.3, 0.3, 0.5)` | `const COLOR_DEPLETED := UIColors.with_alpha(UIColors.TEXT_LOCKED, 0.5)` |
| 34   | `const COLOR_CURSOR   := Color(0.918, 0.902, 1.0, 1.0)` | `const COLOR_CURSOR   := UIColors.TEXT_PRIMARY` |
| 86   | `"color": NOTE_COLORS["C"]`                      | `"color": UIColors.get_note_color("C")`             |
| 119  | `... else (Color(0.0, 0.8, 1.0, 0.8) if ...`       | `... else (UIColors.with_alpha(UIColors.ACCENT_2, 0.8) if ...` |
| 147  | `_draw_arc_segment(..., Color(color, 0.15))`        | `_draw_arc_segment(..., UIColors.with_alpha(color, 0.15))` |

*(完整的逐行修改清单见附录)*

### 3.3. 步骤三: 推广 `GlobalTheme.tres`

1.  **检查并完善 `GlobalTheme.tres`**: 确保其定义的控件样式（`Button`, `Panel`, `ProgressBar` 等）符合最新的 UI 设计规范。将其中硬编码的颜色值替换为对 `UIColors` 常量的引用（虽然 `.tres` 文件本身不支持直接引用 `.gd` 文件，但在逻辑上应保持一致，建议在 `.tres` 文件头部注释中明确其颜色值来源自 `UIColors` 的哪个常量）。
2.  **全局应用**: 在 Godot 编辑器的“项目设置” -> “GUI” -> “主题”中，将 `custom` 属性设置为 `res://themes/GlobalTheme.tres`。这将使其成为所有 UI 节点的默认主题。
3.  **移除局部主题**: 检查所有 `.tscn` 文件，移除其中单独设置的 `theme` 属性，除非确实需要特殊的局部覆盖。

## 4. 预期收益

- **单一事实来源**: 所有颜色定义集中于 `UIColors.gd`，所有静态样式集中于 `GlobalTheme.tres`，彻底消除混乱。
- **提高维护效率**: 调整UI颜色或样式只需修改一到两个文件，变更可立即全局生效。
- **保证视觉一致性**: 所有 UI 元素将遵循统一的视觉规范，提升产品专业度。
- **提升代码质量**: 消除硬编码，代码更具可读性、语义化和健壮性。

---

## 附录 A: 完整硬编码颜色清单

*(此部分将包含从 `/tmp/all_colors.txt` 和 `/tmp/const_colors.txt` 整理的完整清单)*

## 附录 B: 逐文件详细修改指南

*(此部分将为每个需要修改的文件提供详细的行号、旧代码和新代码对照表)*


## 附录 B: 逐文件详细修改指南

本附录为部分关键文件提供了详细的修改建议。未列出的文件可参照此模式进行修改。

### 文件: `godot_project/scripts/ui/game_mechanics_panel.gd`

| 行号 | 原始代码 | 建议重构代码 |
|:---|:---|:---:|
| 46 | `const BG_COLOR := Color(0.04, 0.03, 0.08, 0.85)` | `UIColors.with_alpha(UIColors.PRIMARY_BG, 0.85)` |
| 47 | `const BORDER_COLOR := Color(0.25, 0.22, 0.38, 0.6)` | `*(手动分析)*` |
| 48 | `const TITLE_COLOR := Color(0.55, 0.5, 0.7, 0.9)` | `*(手动分析)*` |
| 49 | `const LABEL_COLOR := Color(0.5, 0.48, 0.6, 0.8)` | `*(手动分析)*` |
| 50 | `const VALUE_COLOR := Color(0.75, 0.72, 0.88, 0.9)` | `*(手动分析)*` |
| 53 | `const DISSONANCE_LOW_COLOR := Color(0.2, 0.7, 0.4)` | `*(手动分析)*` |
| 54 | `const DISSONANCE_MID_COLOR := Color(1.0, 0.8, 0.0)` | `*(手动分析)*` |
| 55 | `const DISSONANCE_HIGH_COLOR := Color(1.0, 0.2, 0.1)` | `*(手动分析)*` |
| 59 | `0: Color(0.0, 0.8, 0.4),` | `*(手动分析)*` |
| 60 | `1: Color(0.7, 0.8, 0.0),` | `*(手动分析)*` |
| 61 | `2: Color(1.0, 0.6, 0.0),` | `*(手动分析)*` |
| 62 | `3: Color(1.0, 0.2, 0.0),` | `*(手动分析)*` |
| 63 | `4: Color(0.8, 0.0, 0.2),` | `*(手动分析)*` |
| 67 | `const DENSITY_SAFE_COLOR := Color(0.3, 0.6, 1.0)` | `*(手动分析)*` |
| 68 | `const DENSITY_WARN_COLOR := Color(1.0, 0.6, 0.0)` | `*(手动分析)*` |
| 69 | `const DENSITY_OVERLOAD_COLOR := Color(1.0, 0.15, 0.1)` | `*(手动分析)*` |
| 72 | `const SHIELD_COLOR := Color(0.3, 0.7, 1.0, 0.8)` | `*(手动分析)*` |
| 73 | `const CRIT_COLOR := Color(1.0, 0.6, 0.2)` | `*(手动分析)*` |
| 76 | `const COL_HELP_BG := Color("#0A0814F2")` | `UIColors.with_alpha(UIColors.PRIMARY_BG, 0.95)` |
| 77 | `const COL_HELP_PANEL := Color("#141026")` | `UIColors.PANEL_BG` |
| 78 | `const COL_ACCENT := Color("#9D6FFF")` | `UIColors.ACCENT` |
| 79 | `const COL_GOLD := Color("#FFD700")` | `UIColors.GOLD` |
| 80 | `const COL_OFFENSE := Color("#FF4444")` | `*(手动分析)*` |
| 81 | `const COL_DEFENSE := Color("#4488FF")` | `*(手动分析)*` |
| 82 | `const COL_CORE := Color("#9D6FFF")` | `UIColors.ACCENT` |
| 83 | `const COL_TEXT_PRIMARY := Color("#EAE6FF")` | `UIColors.TEXT_PRIMARY` |
| 84 | `const COL_TEXT_SECONDARY := Color("#A098C8")` | `UIColors.TEXT_SECONDARY` |
| 85 | `const COL_TEXT_DIM := Color("#6B668A")` | `UIColors.TEXT_DIM` |
| 276 | `draw_rect(flash_rect, Color(1.0, 0.3, 0.1, _dissonance_flash * 0.3))` | `*(手动分析)*` |
| 288 | `draw_rect(flash_rect, Color(1.0, 0.0, 0.0, flash_alpha * content_alpha))` | `*(手动分析)*` |
| 292 | `HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1.0, 0.4, 0.2, 0.8 * content_alpha))` | `*(手动分析)*` |
| 308 | `draw_rect(flash_rect, Color(1.0, 0.15, 0.1, _overload_flash * 0.4 * content_alpha))` | `*(手动分析)*` |
| 312 | `HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1.0, 0.3, 0.1, 0.8 * content_alpha))` | `*(手动分析)*` |
| 332 | `Color(LABEL_COLOR.r, LABEL_COLOR.g, LABEL_COLOR.b, content_alpha))` | `*(手动分析)*` |
| 341 | `Color(1.0, 0.2, 0.2, note_alpha * content_alpha))` | `*(手动分析)*` |
| 344 | `Color(1.0, 0.3, 0.3, 0.6 * content_alpha))` | `*(手动分析)*` |
| 354 | `Color(LABEL_COLOR.r, LABEL_COLOR.g, LABEL_COLOR.b, alpha))` | `*(手动分析)*` |
| 358 | `Color(0.08, 0.06, 0.12, 0.5 * alpha))` | `*(手动分析)*` |
| 363 | `Color(bar_color.r, bar_color.g, bar_color.b, bar_color.a * alpha))` | `*(手动分析)*` |
| 367 | `Color(bar_color.r, bar_color.g, bar_color.b, 0.3 * alpha))` | `*(手动分析)*` |
| 375 | `Color(1, 1, 1, 0.2 * alpha), 1.0)` | `*(手动分析)*` |
| 379 | `Color(VALUE_COLOR.r, VALUE_COLOR.g, VALUE_COLOR.b, alpha))` | `*(手动分析)*` |
| 551 | `panel_style.shadow_color = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.15)` | `*(手动分析)*` |
| 574 | `close_style.bg_color = Color(0.3, 0.1, 0.1, 0.3)` | `*(手动分析)*` |
| 589 | `sep.color = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.4)` | `*(手动分析)*` |
| 605 | `btn_style.bg_color = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.1)` | `*(手动分析)*` |
| 606 | `btn_style.border_color = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.3)` | `*(手动分析)*` |
| 615 | `btn_active.bg_color = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.25)` | `*(手动分析)*` |
| 776 | `style.bg_color = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.08)` | `*(手动分析)*` |
| 777 | `style.border_color = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.2)` | `*(手动分析)*` |
| 792 | `style.bg_color = Color(color.r, color.g, color.b, 0.08)` | `*(手动分析)*` |
| 793 | `style.border_color = Color(color.r, color.g, color.b, 0.4)` | `*(手动分析)*` |
| 889 | `_tutorial_overlay.color = Color(0, 0, 0, 0.7)` | `*(手动分析)*` |
| 906 | `panel_style.bg_color = Color(COL_HELP_PANEL.r, COL_HELP_PANEL.g, COL_HELP_PANEL.b, 0.95)` | `*(手动分析)*` |
| 953 | `skip_style.bg_color = Color(0.1, 0.08, 0.15, 0.5)` | `*(手动分析)*` |
| 970 | `next_style.bg_color = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.3)` | `*(手动分析)*` |
| 1047 | `style.bg_color = Color(0.08, 0.06, 0.15, 0.8)` | `UIColors.with_alpha(UIColors.PANEL_BG, 0.8)` |
| 1048 | `style.border_color = Color("#9D6FFF")` | `UIColors.ACCENT` |
| 1060 | `hover_style.bg_color = Color(0.15, 0.1, 0.25, 0.9)` | `*(手动分析)*` |
| 1061 | `hover_style.border_color = Color("#FFD700")` | `UIColors.GOLD` |
| 1064 | `btn.add_theme_color_override("font_color", Color("#A098C8"))` | `UIColors.TEXT_SECONDARY` |
| 1065 | `btn.add_theme_color_override("font_hover_color", Color("#FFD700"))` | `UIColors.GOLD` |


### 文件: `godot_project/scripts/ui/meta_progression_visualizer.gd`

| 行号 | 原始代码 | 建议重构代码 |
|:---|:---|:---:|
| 25 | `const BG_COLOR := Color(0.03, 0.02, 0.06, 0.97)` | `*(手动分析)*` |
| 26 | `const ACCENT := Color("#9D6FFF")` | `UIColors.ACCENT` |
| 27 | `const GOLD := Color("#FFD700")` | `UIColors.GOLD` |
| 28 | `const CYAN := Color("#00E5FF")` | `*(手动分析)*` |
| 29 | `const TEXT_COLOR := Color("#EAE6FF")` | `UIColors.TEXT_PRIMARY` |
| 30 | `const DIM_TEXT := Color("#A098C8")` | `UIColors.TEXT_SECONDARY` |
| 31 | `const SUCCESS := Color("#4DFF80")` | `UIColors.SUCCESS` |
| 32 | `const DANGER := Color("#FF4D4D")` | `UIColors.DANGER` |
| 33 | `const FRAGMENT_COLOR := Color(0.6, 0.4, 1.0)` | `*(手动分析)*` |
| 36 | `const NODE_LOCKED_BG := Color(0.1, 0.08, 0.16, 0.4)` | `UIColors.with_alpha(UIColors.PANEL_LIGHT, 0.4)` |
| 37 | `const NODE_LOCKED_BORDER := Color(0.3, 0.25, 0.4, 0.3)` | `*(手动分析)*` |
| 38 | `const NODE_UNLOCKABLE_BORDER := Color(0.6, 0.4, 1.0, 0.7)` | `*(手动分析)*` |
| 39 | `const NODE_UNLOCKED_BG := Color(0.0, 0.9, 1.0, 0.15)` | `*(手动分析)*` |
| 40 | `const NODE_UNLOCKED_BORDER := Color(0.0, 0.9, 1.0, 0.8)` | `*(手动分析)*` |
| 43 | `const LINK_LOCKED := Color(0.2, 0.18, 0.3, 0.2)` | `*(手动分析)*` |
| 44 | `const LINK_ACTIVE := Color(0.6, 0.4, 1.0, 0.5)` | `*(手动分析)*` |
| 45 | `const LINK_UNLOCKED := Color(0.0, 0.9, 1.0, 0.4)` | `*(手动分析)*` |
| 49 | `"instrument": Color(0.2, 0.8, 1.0),` | `*(手动分析)*` |
| 50 | `"theory": Color(0.8, 0.4, 1.0),` | `*(手动分析)*` |
| 51 | `"modes": Color(1.0, 0.6, 0.2),` | `*(手动分析)*` |
| 52 | `"denoise": Color(0.3, 1.0, 0.5),` | `UIColors.SUCCESS` |
| 428 | `Color(0.6, 0.6, 0.8, star["brightness"] * flicker * 0.5))` | `*(手动分析)*` |
| 447 | `Color(0.15, 0.12, 0.22, 0.6))` | `*(手动分析)*` |
| 449 | `Color(module_color.r, module_color.g, module_color.b, 0.7))` | `*(手动分析)*` |
| 482 | `Color(color.r, color.g, color.b, 0.15), 2.0)` | `*(手动分析)*` |
| 492 | `Color(0.2, 0.18, 0.3, 0.3), 4.0)` | `*(手动分析)*` |
| 498 | `Color(color.r, color.g, color.b, 0.4), 4.0)` | `*(手动分析)*` |
| 509 | `draw_circle(pt, 1.0, Color(color.r, color.g, color.b, alpha))` | `*(手动分析)*` |
| 522 | `Color(color.r, color.g, color.b, alpha), 1.0)` | `*(手动分析)*` |
| 552 | `Color(module_color.r, module_color.g, module_color.b, 0.5 * (1.0 - pulse)))` | `*(手动分析)*` |
| 610 | `border_color = Color(NODE_LOCKED_BORDER.r, NODE_LOCKED_BORDER.g, NODE_LOCKED_BORDER.b, 0.6)` | `*(手动分析)*` |
| 617 | `var text_color := Color(0.4, 0.35, 0.5, 0.4)` | `*(手动分析)*` |
| 619 | `text_color = Color(0.5, 0.45, 0.6, 0.7)` | `*(手动分析)*` |
| 621 | `draw_arc(pos, radius, 0, TAU, 48, Color(0.4, 0.35, 0.55, 0.5), 1.5)` | `*(手动分析)*` |
| 644 | `Color(module_color.r, module_color.g, module_color.b, alpha), 2.0)` | `*(手动分析)*` |
| 650 | `draw_circle(pos, radius * 0.9, Color(module_color.r, module_color.g, module_color.b, 0.08))` | `*(手动分析)*` |
| 658 | `Color(TEXT_COLOR.r, TEXT_COLOR.g, TEXT_COLOR.b, 0.8))` | `*(手动分析)*` |
| 672 | `draw_circle(pt, 2.0, Color(module_color.r, module_color.g, module_color.b, 0.4))` | `*(手动分析)*` |
| 682 | `fill_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.2)` | `*(手动分析)*` |
| 684 | `fill_color = Color(CYAN.r, CYAN.g, CYAN.b, 0.15)` | `*(手动分析)*` |
| 688 | `var border_color := Color(GOLD.r, GOLD.g, GOLD.b, 0.8) if is_maxed else NODE_UNLOCKED_BORDER` | `*(手动分析)*` |
| 696 | `Color(border_color.r, border_color.g, border_color.b, glow_alpha), 3.0)` | `*(手动分析)*` |
| 713 | `Color(GOLD.r, GOLD.g, GOLD.b, 0.7) if is_maxed else Color(CYAN.r, CYAN.g, CYAN.b, 0.7))` | `*(手动分析)*` |
| 722 | `FRAGMENT_COLOR if can_afford else Color(DANGER.r, DANGER.g, DANGER.b, 0.6))` | `*(手动分析)*` |
| 736 | `Color(CYAN.r, CYAN.g, CYAN.b, ring_alpha), 2.5)` | `*(手动分析)*` |
| 745 | `Color(GOLD.r, GOLD.g, GOLD.b, pt_alpha))` | `*(手动分析)*` |
| 761 | `draw_rect(tooltip_rect, Color(0.06, 0.04, 0.12, 0.92))` | `UIColors.with_alpha(UIColors.PANEL_DARK, 0.92)` |
| 762 | `draw_rect(tooltip_rect, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.3), false, 1.0)` | `*(手动分析)*` |
| 792 | `status_color = Color(0.5, 0.4, 0.6)` | `*(手动分析)*` |
| 803 | `draw_rect(_back_btn_rect, Color(0.1, 0.08, 0.18, 0.85))` | `UIColors.with_alpha(UIColors.PANEL_LIGHT, 0.85)` |
| 804 | `draw_rect(_back_btn_rect, Color(0.4, 0.35, 0.55, 0.5), false, 1.0)` | `*(手动分析)*` |
| 806 | `"← 返回", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.65, 0.85))` | `*(手动分析)*` |
| 810 | `draw_rect(_start_btn_rect, Color(0.05, 0.15, 0.1, 0.85))` | `*(手动分析)*` |
| 811 | `draw_rect(_start_btn_rect, Color(0.3, 0.8, 0.5, 0.5), false, 1.0)` | `*(手动分析)*` |
| 813 | `"开始演奏 ▶", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.3, 0.9, 0.5))` | `*(手动分析)*` |


### 文件: `godot_project/scripts/ui/chord_alchemy_panel_v3.gd`

| 行号 | 原始代码 | 建议重构代码 |
|:---|:---|:---:|
| 33 | `const SLOT_EMPTY_BG := Color("141026A0")` | `*(手动分析)*` |
| 34 | `const SLOT_FILLED_BG := Color("1A1433D0")` | `*(手动分析)*` |
| 35 | `const SLOT_HOVER_BG := Color("9D6FFF30")` | `*(手动分析)*` |
| 36 | `const SLOT_DROP_HIGHLIGHT := Color("00FFD466")` | `*(手动分析)*` |
| 37 | `const SLOT_BORDER := Color("9D6FFF40")` | `*(手动分析)*` |
| 38 | `const SLOT_REQUIRED_MARK := Color("FF444460")` | `*(手动分析)*` |
| 40 | `const SYNTH_BTN_VALID := Color("00FFD4CC")` | `*(手动分析)*` |
| 41 | `const SYNTH_BTN_INVALID := Color("9D6FFF40")` | `*(手动分析)*` |
| 42 | `const SYNTH_BTN_HOVER := Color("00FFD4FF")` | `*(手动分析)*` |
| 43 | `const SYNTH_BTN_TEXT_VALID := Color("FFFFFF")` | `*(手动分析)*` |
| 44 | `const SYNTH_BTN_TEXT_INVALID := Color("9D8FBF80")` | `*(手动分析)*` |
| 46 | `const PREVIEW_VALID_COLOR := Color("00FFD4")` | `*(手动分析)*` |
| 47 | `const PREVIEW_INVALID_COLOR := Color("FF4444")` | `*(手动分析)*` |
| 48 | `const SECTION_TITLE_COLOR := Color("9D8FBF")` | `*(手动分析)*` |
| 52 | `0: Color("00FFD4"), 1: Color("0088FF"), 2: Color("66FF66"),` | `*(手动分析)*` |
| 53 | `3: Color("8844FF"), 4: Color("FF4444"), 5: Color("FF8800"),` | `*(手动分析)*` |
| 54 | `6: Color("FF44AA"),` | `*(手动分析)*` |
| 74 | `"enhanced_projectile": Color("FFD94D"),` | `*(手动分析)*` |
| 75 | `"dot_projectile": Color("3366CC"),` | `*(手动分析)*` |
| 76 | `"explosive_projectile": Color("FF6633"),` | `*(手动分析)*` |
| 77 | `"shockwave": Color("8822BB"),` | `*(手动分析)*` |
| 78 | `"magic_circle": Color("FFCC00"),` | `*(手动分析)*` |
| 79 | `"celestial_strike": Color("CC1111"),` | `*(手动分析)*` |
| 80 | `"shield_heal": Color("33E666"),` | `*(手动分析)*` |
| 81 | `"summon_construct": Color("2233BB"),` | `*(手动分析)*` |
| 82 | `"charged_projectile": Color("D9D9F2"),` | `*(手动分析)*` |
| 83 | `"slow_field": Color("4D4DBB"),` | `*(手动分析)*` |
| 84 | `"generic_blast": Color("808080"),` | `*(手动分析)*` |
| 160 | `desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(form_color.r, form_color.g, form_color.b, 0.7))` | `*(手动分析)*` |
| 167 | `"还需 %d 个音符..." % needed, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("9D8FBF80"))` | `*(手动分析)*` |
| 192 | `bg = bg.lerp(Color("00FFD440"), _craft_flash)` | `*(手动分析)*` |
| 194 | `bg = bg.lerp(Color("FF444440"), _craft_flash)` | `*(手动分析)*` |
| 201 | `var note_color: Color = NOTE_COLORS.get(_slots[i], Color(0.5, 0.5, 0.5))` | `*(手动分析)*` |
| 202 | `border = Color(note_color.r, note_color.g, note_color.b, 0.7)` | `*(手动分析)*` |
| 204 | `border = Color("00FFD4CC")` | `*(手动分析)*` |
| 210 | `var note_color: Color = NOTE_COLORS.get(note_key, Color(0.5, 0.5, 0.5))` | `*(手动分析)*` |
| 212 | `draw_rect(rect.grow(-3), Color(note_color.r, note_color.g, note_color.b, 0.25))` | `*(手动分析)*` |
| 279 | `info_hover.emit("炼成", "需要至少 %d 个音符且组合有效" % MIN_NOTES_FOR_CHORD, Color("9D8FBF"))` | `*(手动分析)*` |
| 298 | `Color("9D8FBF")` | `*(手动分析)*` |
| 311 | `var color: Color = NOTE_COLORS.get(note_key, Color(0.5, 0.5, 0.5))` | `*(手动分析)*` |
| 528 | `style.bg_color = Color(color.r, color.g, color.b, 0.5)` | `*(手动分析)*` |
| 532 | `style.shadow_color = Color(color.r, color.g, color.b, 0.6)` | `*(手动分析)*` |


### 文件: `godot_project/scripts/ui/mode_selection_screen.gd`

| 行号 | 原始代码 | 建议重构代码 |
|:---|:---|:---:|
| 20 | `const BG_COLOR := Color(0.03, 0.02, 0.06, 0.97)` | `*(手动分析)*` |
| 21 | `const ACCENT := Color("#9D6FFF")` | `UIColors.ACCENT` |
| 22 | `const GOLD := Color("#FFD700")` | `UIColors.GOLD` |
| 23 | `const CYAN := Color("#00E5FF")` | `*(手动分析)*` |
| 24 | `const TEXT_COLOR := Color("#EAE6FF")` | `UIColors.TEXT_PRIMARY` |
| 25 | `const DIM_TEXT := Color("#A098C8")` | `UIColors.TEXT_SECONDARY` |
| 26 | `const SUCCESS := Color("#4DFF80")` | `UIColors.SUCCESS` |
| 27 | `const DANGER := Color("#FF4D4D")` | `UIColors.DANGER` |
| 28 | `const FRAGMENT_COLOR := Color(0.6, 0.4, 1.0)` | `*(手动分析)*` |
| 29 | `const WARM_ORANGE := Color(1.0, 0.6, 0.2)` | `*(手动分析)*` |
| 41 | `"color": Color(0.4, 0.6, 1.0),` | `*(手动分析)*` |
| 51 | `"color": Color(0.3, 0.8, 0.6),` | `*(手动分析)*` |
| 61 | `"color": Color(1.0, 0.3, 0.3),` | `UIColors.DANGER` |
| 71 | `"color": Color(0.8, 0.5, 1.0),` | `*(手动分析)*` |
| 179 | `Color(0.5, 0.5, 0.7, star["brightness"] * flicker * 0.4))` | `*(手动分析)*` |
| 212 | `Color(0.15, 0.12, 0.22, 0.3), 1.0)` | `*(手动分析)*` |
| 220 | `draw_line(center, pos, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.1), 1.0)` | `*(手动分析)*` |
| 244 | `draw_line(p1, p2, Color(0.3, 0.25, 0.4, 0.3), 1.5)` | `*(手动分析)*` |
| 246 | `HORIZONTAL_ALIGNMENT_CENTER, 16, 14, Color(0.4, 0.35, 0.5, 0.4))` | `*(手动分析)*` |
| 252 | `Color(DANGER.r, DANGER.g, DANGER.b, 0.5))` | `*(手动分析)*` |
| 262 | `Color(GOLD.r, GOLD.g, GOLD.b, alpha + 0.05 * sin(_time * 2.0)), 2.0)` | `*(手动分析)*` |
| 263 | `draw_circle(pos, radius, Color(mode_color.r, mode_color.g, mode_color.b, 0.2))` | `*(手动分析)*` |
| 264 | `draw_arc(pos, radius, 0, TAU, 48, Color(GOLD.r, GOLD.g, GOLD.b, 0.8), 2.5)` | `*(手动分析)*` |
| 266 | `draw_circle(pos, radius, Color(mode_color.r, mode_color.g, mode_color.b, 0.12))` | `*(手动分析)*` |
| 268 | `Color(mode_color.r, mode_color.g, mode_color.b, 0.6), 2.0)` | `*(手动分析)*` |
| 270 | `draw_circle(pos, radius, Color(mode_color.r, mode_color.g, mode_color.b, 0.08))` | `*(手动分析)*` |
| 272 | `Color(mode_color.r, mode_color.g, mode_color.b, 0.35), 1.5)` | `*(手动分析)*` |
| 284 | `Color(DIM_TEXT.r, DIM_TEXT.g, DIM_TEXT.b, 0.7))` | `*(手动分析)*` |
| 294 | `draw_rect(panel_rect, Color(0.06, 0.04, 0.1, 0.7))` | `*(手动分析)*` |
| 295 | `draw_rect(panel_rect, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.15), false, 1.0)` | `*(手动分析)*` |
| 314 | `Color(GOLD.r, GOLD.g, GOLD.b, 0.7))` | `*(手动分析)*` |
| 319 | `Color(0.2, 0.18, 0.3, 0.4), 1.0)` | `*(手动分析)*` |
| 329 | `"音阶:", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 0.45, 0.6))` | `*(手动分析)*` |
| 336 | `"被动:", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 0.45, 0.6))` | `*(手动分析)*` |
| 350 | `Color(CYAN.r, CYAN.g, CYAN.b, 0.7))` | `*(手动分析)*` |
| 355 | `Color(DANGER.r, DANGER.g, DANGER.b, 0.7))` | `*(手动分析)*` |
| 363 | `draw_rect(_back_btn_rect, Color(0.1, 0.08, 0.18, 0.85))` | `UIColors.with_alpha(UIColors.PANEL_LIGHT, 0.85)` |
| 364 | `draw_rect(_back_btn_rect, Color(0.4, 0.35, 0.55, 0.5), false, 1.0)` | `*(手动分析)*` |
| 366 | `"← 返回", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.65, 0.85))` | `*(手动分析)*` |
| 370 | `draw_rect(_confirm_btn_rect, Color(0.05, 0.15, 0.1, 0.85))` | `*(手动分析)*` |
| 371 | `draw_rect(_confirm_btn_rect, Color(0.3, 0.8, 0.5, 0.5), false, 1.0)` | `*(手动分析)*` |
| 373 | `"确认选择 ✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.3, 0.9, 0.5))` | `*(手动分析)*` |


### 文件: `godot_project/scripts/ui/run_results_screen.gd`

| 行号 | 原始代码 | 建议重构代码 |
|:---|:---|:---:|
| 22 | `const BG_COLOR := Color(0.02, 0.01, 0.03, 0.97)` | `*(手动分析)*` |
| 23 | `const ACCENT := Color("#9D6FFF")` | `UIColors.ACCENT` |
| 24 | `const GOLD := Color("#FFD700")` | `UIColors.GOLD` |
| 25 | `const CYAN := Color("#00E5FF")` | `*(手动分析)*` |
| 26 | `const TEXT_COLOR := Color("#EAE6FF")` | `UIColors.TEXT_PRIMARY` |
| 27 | `const DIM_TEXT := Color("#A098C8")` | `UIColors.TEXT_SECONDARY` |
| 28 | `const SUCCESS := Color("#4DFF80")` | `UIColors.SUCCESS` |
| 29 | `const DANGER := Color("#FF4D4D")` | `UIColors.DANGER` |
| 30 | `const FRAGMENT_COLOR := Color(0.6, 0.4, 1.0)` | `*(手动分析)*` |
| 36 | `"S": {"name": "HARMONIC MASTER", "color": Color("#FFD700"), "threshold": 2000},` | `UIColors.GOLD` |
| 37 | `"A": {"name": "RESONANCE", "color": Color("#00E5FF"), "threshold": 1200},` | `*(手动分析)*` |
| 38 | `"B": {"name": "MELODY", "color": Color("#9D6FFF"), "threshold": 600},` | `UIColors.ACCENT` |
| 39 | `"C": {"name": "RHYTHM", "color": Color("#4DFF80"), "threshold": 300},` | `UIColors.SUCCESS` |
| 40 | `"D": {"name": "NOISE", "color": Color("#A098C8"), "threshold": 0},` | `UIColors.TEXT_SECONDARY` |
| 297 | `Color(0.5, 0.5, 0.7, star["brightness"] * flicker * 0.4))` | `*(手动分析)*` |
| 312 | `Color(GOLD.r, GOLD.g, GOLD.b, 0.9))` | `*(手动分析)*` |
| 316 | `Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.2), 1.0)` | `*(手动分析)*` |
| 327 | `Color(ACCENT.r, ACCENT.g, ACCENT.b, alpha * 0.7))` | `*(手动分析)*` |
| 330 | `Color(DIM_TEXT.r, DIM_TEXT.g, DIM_TEXT.b, alpha))` | `*(手动分析)*` |
| 333 | `Color(TEXT_COLOR.r, TEXT_COLOR.g, TEXT_COLOR.b, alpha))` | `*(手动分析)*` |
| 335 | `Color(0.2, 0.18, 0.3, alpha * 0.3), 1.0)` | `*(手动分析)*` |
| 343 | `canvas.draw_rect(eval_rect, Color(_eval_color.r, _eval_color.g, _eval_color.b, 0.08 * scale))` | `*(手动分析)*` |
| 344 | `canvas.draw_rect(eval_rect, Color(_eval_color.r, _eval_color.g, _eval_color.b, 0.3 * scale), false, 2.0)` | `*(手动分析)*` |
| 347 | `Color(_eval_color.r, _eval_color.g, _eval_color.b, scale))` | `*(手动分析)*` |
| 350 | `Color(_eval_color.r, _eval_color.g, _eval_color.b, scale * 0.8))` | `*(手动分析)*` |
| 356 | `Color(DIM_TEXT.r, DIM_TEXT.g, DIM_TEXT.b, hint_alpha))` | `*(手动分析)*` |
| 361 | `Color(FRAGMENT_COLOR.r, FRAGMENT_COLOR.g, FRAGMENT_COLOR.b, 0.9))` | `*(手动分析)*` |
| 366 | `Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.8))` | `*(手动分析)*` |
| 370 | `Color(FRAGMENT_COLOR.r, FRAGMENT_COLOR.g, FRAGMENT_COLOR.b, 1.0))` | `*(手动分析)*` |
| 380 | `Color(ACCENT.r, ACCENT.g, ACCENT.b, alpha * 0.6))` | `*(手动分析)*` |
| 385 | `Color(DIM_TEXT.r, DIM_TEXT.g, DIM_TEXT.b, hint_alpha))` | `*(手动分析)*` |
| 390 | `Color(TEXT_COLOR.r, TEXT_COLOR.g, TEXT_COLOR.b, 0.9))` | `*(手动分析)*` |
| 419 | `canvas.draw_rect(rect, Color(btn_color.r, btn_color.g, btn_color.b, bg_alpha))` | `*(手动分析)*` |
| 421 | `canvas.draw_rect(rect, Color(btn_color.r, btn_color.g, btn_color.b, border_alpha), false, 1.5)` | `*(手动分析)*` |
| 424 | `canvas.draw_rect(glow_rect, Color(btn_color.r, btn_color.g, btn_color.b, 0.06), false, 3.0)` | `*(手动分析)*` |
| 427 | `Color(btn_color.r, btn_color.g, btn_color.b, 0.8 if is_hover else 0.5))` | `*(手动分析)*` |
| 430 | `Color(TEXT_COLOR.r, TEXT_COLOR.g, TEXT_COLOR.b, 1.0 if is_hover else 0.7))` | `*(手动分析)*` |
| 433 | `Color(DIM_TEXT.r, DIM_TEXT.g, DIM_TEXT.b, 0.7 if is_hover else 0.4))` | `*(手动分析)*` |
| 448 | `color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.4)` | `*(手动分析)*` |
| 450 | `color = Color(0.3, 0.25, 0.4, 0.3)` | `*(手动分析)*` |
| 453 | `var line_color := Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.2)` | `*(手动分析)*` |
| 455 | `line_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.4)` | `*(手动分析)*` |


### 文件: `godot_project/scripts/ui/boss_dialogue.gd`

| 行号 | 原始代码 | 建议重构代码 |
|:---|:---|:---:|
| 338 | `_background_dim.color = Color(0.0, 0.0, 0.0, 0.6)` | `*(手动分析)*` |
| 358 | `style.bg_color = Color(0.05, 0.03, 0.08, 0.92)` | `UIColors.with_alpha(UIColors.PRIMARY_BG, 0.92)` |
| 359 | `style.border_color = Color(0.6, 0.3, 0.9, 0.8)` | `*(手动分析)*` |
| 409 | `_name_label.add_theme_color_override("font_color", Color(0.9, 0.7, 1.0))` | `*(手动分析)*` |
| 415 | `_title_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.7))` | `*(手动分析)*` |
| 426 | `_text_label.add_theme_color_override("default_color", Color(0.9, 0.9, 0.95))` | `*(手动分析)*` |
| 439 | `_advance_indicator.add_theme_color_override("font_color", Color(0.5, 0.4, 0.6, 0.8))` | `*(手动分析)*` |
| 446 | `_skip_hint.add_theme_color_override("font_color", Color(0.4, 0.3, 0.5, 0.6))` | `*(手动分析)*` |
| 673 | `"solemn": Color(0.8, 0.75, 0.5),` | `*(手动分析)*` |
| 674 | `"commanding": Color(0.9, 0.8, 0.4),` | `*(手动分析)*` |
| 675 | `"challenge": Color(1.0, 0.4, 0.3),` | `*(手动分析)*` |
| 676 | `"surprised": Color(0.5, 0.8, 1.0),` | `*(手动分析)*` |
| 677 | `"accepting": Color(0.6, 0.9, 0.7),` | `*(手动分析)*` |
| 678 | `"reverent": Color(0.7, 0.6, 1.0),` | `*(手动分析)*` |
| 679 | `"stern": Color(0.5, 0.4, 0.7),` | `*(手动分析)*` |
| 680 | `"enlightened": Color(1.0, 0.95, 0.7),` | `*(手动分析)*` |
| 681 | `"proud": Color(0.8, 0.6, 0.3),` | `*(手动分析)*` |
| 682 | `"respectful": Color(0.6, 0.8, 0.6),` | `*(手动分析)*` |
| 683 | `"blessing": Color(0.9, 0.85, 0.5),` | `*(手动分析)*` |
| 684 | `"elegant": Color(0.9, 0.8, 1.0),` | `*(手动分析)*` |
| 685 | `"disdainful": Color(0.8, 0.5, 0.9),` | `*(手动分析)*` |
| 686 | `"inviting": Color(0.7, 0.9, 1.0),` | `*(手动分析)*` |
| 687 | `"impressed": Color(0.5, 0.9, 0.8),` | `*(手动分析)*` |
| 688 | `"wistful": Color(0.7, 0.7, 0.9),` | `*(手动分析)*` |
| 689 | `"fierce": Color(1.0, 0.3, 0.2),` | `*(手动分析)*` |
| 690 | `"passionate": Color(1.0, 0.5, 0.3),` | `*(手动分析)*` |
| 691 | `"moved": Color(0.6, 0.7, 1.0),` | `*(手动分析)*` |
| 692 | `"encouraging": Color(0.8, 0.9, 0.5),` | `*(手动分析)*` |
| 693 | `"cool": Color(0.3, 0.5, 0.9),` | `*(手动分析)*` |
| 694 | `"serious": Color(0.5, 0.4, 0.6),` | `*(手动分析)*` |
| 695 | `"glitch": Color(0.0, 1.0, 0.5),` | `*(手动分析)*` |
| 696 | `"cold": Color(0.3, 0.3, 0.5),` | `*(手动分析)*` |
| 697 | `"final": Color(0.8, 0.0, 0.3),` | `*(手动分析)*` |
| 698 | `"transcendent": Color(1.0, 1.0, 1.0),` | `*(手动分析)*` |
| 699 | `"neutral": Color(0.7, 0.7, 0.7),` | `*(手动分析)*` |
| 701 | `var color: Color = color_map.get(emotion, Color(0.7, 0.7, 0.7))` | `*(手动分析)*` |
| 709 | `var c := color.lerp(Color(0.1, 0.05, 0.15), v * 0.6)` | `*(手动分析)*` |


### 文件: `godot_project/scripts/ui/codex_ui.gd`

| 行号 | 原始代码 | 建议重构代码 |
|:---|:---|:---:|
| 28 | `const COL_BG := Color("#0A0814")              ## 深渊黑` | `UIColors.PRIMARY_BG` |
| 29 | `const COL_PANEL_BG := Color("#141026")        ## 星空紫` | `UIColors.PANEL_BG` |
| 30 | `const COL_HEADER_BG := Color("#100C20")       ## 深色头部` | `UIColors.PANEL_DARK` |
| 31 | `const COL_ACCENT := Color("#9D6FFF")          ## 谐振紫` | `UIColors.ACCENT` |
| 32 | `const COL_GOLD := Color("#FFD700")            ## 圣光金` | `UIColors.GOLD` |
| 33 | `const COL_TEXT_PRIMARY := Color("#EAE6FF")    ## 晶体白` | `UIColors.TEXT_PRIMARY` |
| 34 | `const COL_TEXT_SECONDARY := Color("#A098C8")  ## 星云灰` | `UIColors.TEXT_SECONDARY` |
| 35 | `const COL_TEXT_DIM := Color("#6B668A")        ## 暗淡文本` | `UIColors.TEXT_DIM` |
| 36 | `const COL_LOCKED := Color("#6B668A")          ## 锁定文本` | `UIColors.TEXT_DIM` |
| 37 | `const COL_ENTRY_BG := Color("#18142C")        ## 条目背景` | `UIColors.PANEL_LIGHT` |
| 38 | `const COL_ENTRY_HOVER := Color("#201A38")     ## 条目悬停` | `UIColors.PANEL_LIGHTER` |
| 39 | `const COL_ENTRY_SELECTED := Color("#2A2248")  ## 条目选中` | `UIColors.PANEL_SELECTED` |
| 40 | `const COL_DETAIL_BG := Color("#120E22F2")     ## 详情背景` | `*(手动分析)*` |
| 41 | `const COL_DEMO_BG := Color("#0D0A1A")         ## 演示区背景` | `*(手动分析)*` |
| 42 | `const COL_DEMO_BORDER := Color("#9D6FFF33")   ## 演示区边框` | `UIColors.with_alpha(UIColors.ACCENT, 0.2)` |
| 43 | `const COL_SEPARATOR := Color("#9D6FFF40")     ## 分割线` | `UIColors.with_alpha(UIColors.ACCENT, 0.25)` |
| 105 | `"static":  Color(0.7, 0.3, 0.3),` | `*(手动分析)*` |
| 106 | `"silence": Color(0.2, 0.1, 0.4),` | `*(手动分析)*` |
| 107 | `"screech": Color(1.0, 0.8, 0.0),` | `*(手动分析)*` |
| 108 | `"pulse":   Color(0.0, 0.5, 1.0),` | `*(手动分析)*` |
| 109 | `"wall":    Color(0.5, 0.5, 0.5),` | `*(手动分析)*` |
| 308 | `search_style.bg_color = Color(COL_PANEL_BG.r, COL_PANEL_BG.g, COL_PANEL_BG.b, 0.9)` | `*(手动分析)*` |
| 369 | `btn_style.border_color = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.2)` | `*(手动分析)*` |
| 436 | `right_style.bg_color = Color(COL_DETAIL_BG.r, COL_DETAIL_BG.g, COL_DETAIL_BG.b, 0.95)` | `*(手动分析)*` |
| 507 | `env.background_color = Color(0, 0, 0, 0)` | `*(手动分析)*` |
| 577 | `btn_style.border_color = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.3)` | `*(手动分析)*` |
| 642 | `row_style.border_color = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.1)` | `*(手动分析)*` |
| 905 | `env.background_color = Color(0, 0, 0, 0)` | `*(手动分析)*` |
| 1013 | `env.background_color = Color(COL_DEMO_BG)` | `*(手动分析)*` |
| 1014 | `env.ambient_light_color = Color(0.3, 0.25, 0.5)` | `*(手动分析)*` |
| 1066 | `cast_style.bg_color = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.3)` | `*(手动分析)*` |
| 1087 | `clear_style.bg_color = Color(0.3, 0.1, 0.1, 0.3)` | `*(手动分析)*` |
| 1088 | `clear_style.border_color = Color(0.8, 0.3, 0.3)` | `*(手动分析)*` |
| 1113 | `mat.albedo_color = Color(0.05, 0.04, 0.1)` | `*(手动分析)*` |


### 文件: `godot_project/scripts/ui/debug_panel.gd`

| 行号 | 原始代码 | 建议重构代码 |
|:---|:---|:---:|
| 19 | `const BG_COLOR := Color(0.05, 0.03, 0.10, 0.92)` | `*(手动分析)*` |
| 20 | `const HEADER_COLOR := Color(0.08, 0.05, 0.14)` | `UIColors.PANEL_BG` |
| 21 | `const SECTION_COLOR := Color(0.6, 0.4, 1.0)` | `*(手动分析)*` |
| 22 | `const ACCENT := Color(0.5, 0.3, 0.9)` | `*(手动分析)*` |
| 23 | `const TEXT_COLOR := Color(0.85, 0.82, 0.90)` | `*(手动分析)*` |
| 24 | `const DIM_COLOR := Color(0.45, 0.42, 0.52)` | `*(手动分析)*` |
| 25 | `const SUCCESS_COLOR := Color(0.3, 0.9, 0.5)` | `*(手动分析)*` |
| 26 | `const WARNING_COLOR := Color(1.0, 0.8, 0.2)` | `*(手动分析)*` |
| 27 | `const DANGER_COLOR := Color(1.0, 0.3, 0.3)` | `UIColors.DANGER` |
| 153 | `title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))` | `*(手动分析)*` |
| 575 | `Color(1.0, 0.3, 0.3), Color(1.0, 0.6, 0.2), Color(1.0, 1.0, 0.3),` | `UIColors.DANGER` |
| 576 | `Color(0.3, 1.0, 0.3), Color(0.3, 0.8, 1.0), Color(0.5, 0.3, 1.0),` | `*(手动分析)*` |
| 577 | `Color(0.9, 0.3, 0.9),` | `*(手动分析)*` |
| 628 | `_style_action_button(mod_cast_btn, Color(0.8, 0.5, 1.0))` | `*(手动分析)*` |
| 655 | `_style_action_button(btn, Color(0.3, 0.7, 1.0))` | `*(手动分析)*` |
| 669 | `["合成器", 0, Color(0.0, 1.0, 0.8)],` | `*(手动分析)*` |
| 670 | `["弹拨", 1, Color(0.85, 0.75, 0.3)],` | `*(手动分析)*` |
| 671 | `["拉弦", 2, Color(0.8, 0.2, 0.3)],` | `*(手动分析)*` |
| 672 | `["吹奏", 3, Color(0.6, 0.9, 0.7)],` | `*(手动分析)*` |
| 673 | `["打击", 4, Color(0.9, 0.9, 0.9)],` | `*(手动分析)*` |
| 739 | `_style_action_button(btn, Color(0.9, 0.7, 0.2))` | `*(手动分析)*` |
| 803 | `Color(1.0, 0.3, 0.3), Color(1.0, 0.6, 0.2), Color(1.0, 1.0, 0.3),` | `UIColors.DANGER` |
| 804 | `Color(0.3, 1.0, 0.3), Color(0.3, 0.8, 1.0), Color(0.5, 0.3, 1.0),` | `*(手动分析)*` |
| 805 | `Color(0.9, 0.3, 0.9),` | `*(手动分析)*` |
| 891 | `style.bg_color = Color(0.04, 0.02, 0.08, 0.9)` | `UIColors.with_alpha(UIColors.PRIMARY_BG, 0.9)` |
| 947 | `style.bg_color = Color(0.04, 0.02, 0.08, 0.9)` | `UIColors.with_alpha(UIColors.PRIMARY_BG, 0.9)` |
| 948 | `style.border_color = Color(0.3, 0.6, 0.9) * 0.3` | `*(手动分析)*` |
| 968 | `_quantize_mode_label.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))` | `*(手动分析)*` |
| 987 | `_style_action_button(full_btn, Color(0.3, 0.6, 0.9))` | `*(手动分析)*` |
| 995 | `_style_action_button(soft_btn, Color(0.6, 0.6, 0.3))` | `*(手动分析)*` |
| 1003 | `_style_action_button(off_btn, Color(0.6, 0.3, 0.3))` | `*(手动分析)*` |
| 1022 | `log_style.bg_color = Color(0.03, 0.02, 0.06, 0.9)` | `*(手动分析)*` |
| 1176 | `style.bg_color = Color(0.06, 0.04, 0.12, 0.95)` | `UIColors.with_alpha(UIColors.PANEL_DARK, 0.95)` |


### 文件: `godot_project/scripts/ui/hall_of_harmony.gd`

| 行号 | 原始代码 | 建议重构代码 |
|:---|:---|:---:|
| 21 | `const BG_COLOR := Color("#0A0814")` | `UIColors.PRIMARY_BG` |
| 22 | `const PANEL_BG := Color("#141026CC")       # 80% 不透明` | `UIColors.with_alpha(UIColors.PANEL_BG, 0.8)` |
| 23 | `const ACCENT := Color("#9D6FFF")           # 主强调色` | `UIColors.ACCENT` |
| 24 | `const GOLD := Color("#FFD700")             # 圣光金` | `UIColors.GOLD` |
| 25 | `const CYAN := Color("#00E5FF")             # 谐振青` | `*(手动分析)*` |
| 26 | `const TEXT_COLOR := Color("#EAE6FF")       # 晶体白` | `UIColors.TEXT_PRIMARY` |
| 27 | `const DIM_TEXT := Color("#A098C8")         # 次级文本` | `UIColors.TEXT_SECONDARY` |
| 28 | `const SUCCESS := Color("#4DFF80")` | `UIColors.SUCCESS` |
| 29 | `const DANGER := Color("#FF4D4D")` | `UIColors.DANGER` |
| 30 | `const LOCKED_COLOR := Color("#6B668A")` | `UIColors.TEXT_DIM` |
| 41 | `"color": Color(0.2, 0.8, 1.0),` | `*(手动分析)*` |
| 49 | `"color": Color(0.8, 0.4, 1.0),` | `*(手动分析)*` |
| 57 | `"color": Color(1.0, 0.6, 0.2),` | `*(手动分析)*` |
| 65 | `"color": Color(0.3, 1.0, 0.5),` | `UIColors.SUCCESS` |
| 144 | `frag_style.bg_color = Color(0.08, 0.06, 0.14, 0.9)` | `UIColors.with_alpha(UIColors.PANEL_BG, 0.9)` |
| 235 | `Color(GOLD.r, GOLD.g, GOLD.b, 0.9))` | `*(手动分析)*` |
| 238 | `Color(DIM_TEXT.r, DIM_TEXT.g, DIM_TEXT.b, 0.7))` | `*(手动分析)*` |
| 254 | `draw_circle(pos, s, Color(0.7, 0.7, 0.9, alpha * 0.6))` | `*(手动分析)*` |
| 265 | `var color := Color(CYAN.r, CYAN.g, CYAN.b, alpha)` | `*(手动分析)*` |
| 269 | `draw_circle(center, 8.0, Color(CYAN.r, CYAN.g, CYAN.b, 0.6 * breath))` | `*(手动分析)*` |
| 270 | `draw_circle(center, 4.0, Color(1.0, 1.0, 1.0, 0.8 * breath))` | `*(手动分析)*` |
| 277 | `draw_line(inner, outer, Color(GOLD.r, GOLD.g, GOLD.b, 0.08), 1.0)` | `*(手动分析)*` |
| 309 | `draw_line(center, constellation_center, Color(ACCENT.r, ACCENT.g, ACCENT.b, line_alpha), 1.0)` | `*(手动分析)*` |
| 319 | `Color(module_color.r, module_color.g, module_color.b, icon_alpha))` | `*(手动分析)*` |
| 325 | `Color(TEXT_COLOR.r, TEXT_COLOR.g, TEXT_COLOR.b, name_alpha))` | `*(手动分析)*` |
| 333 | `Color(DIM_TEXT.r, DIM_TEXT.g, DIM_TEXT.b, 0.6))` | `*(手动分析)*` |
| 341 | `Color(module_color.r, module_color.g, module_color.b, glow_a), 2.0)` | `*(手动分析)*` |
| 357 | `Color(color.r, color.g, color.b, base_alpha * 0.6), 1.5)` | `*(手动分析)*` |
| 377 | `Color(color.r, color.g, color.b, base_alpha * (0.5 - i * 0.1)), 1.0)` | `*(手动分析)*` |
| 382 | `draw_circle(pt, s * breath, Color(color.r, color.g, color.b, base_alpha * breath))` | `*(手动分析)*` |
| 388 | `Color(color.r, color.g, color.b, base_alpha * 0.3), 0.8)` | `*(手动分析)*` |
| 397 | `draw_rect(info_rect, Color(0.06, 0.04, 0.12, 0.85))` | `UIColors.with_alpha(UIColors.PANEL_DARK, 0.85)` |
| 398 | `draw_rect(info_rect, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.3), false, 1.0)` | `*(手动分析)*` |


### 文件: `godot_project/scripts/ui/manual_slot_config_v3.gd`

| 行号 | 原始代码 | 建议重构代码 |
|:---|:---|:---:|
| 36 | `const SLOT_EMPTY_BG := Color("141026B0")` | `*(手动分析)*` |
| 37 | `const SLOT_HOVER_BG := Color("9D6FFF30")` | `*(手动分析)*` |
| 38 | `const SLOT_FILLED_BG := Color("1A1433D0")` | `*(手动分析)*` |
| 39 | `const SLOT_DROP_HIGHLIGHT := Color("00FFD466")` | `*(手动分析)*` |
| 40 | `const SLOT_BORDER := Color("9D6FFF50")` | `*(手动分析)*` |
| 41 | `const SLOT_ACTIVE_BORDER := Color("00FFD4CC")` | `*(手动分析)*` |
| 42 | `const KEY_LABEL_COLOR := Color("9D8FBF")` | `*(手动分析)*` |
| 43 | `const KEY_LABEL_BG := Color("9D6FFF20")` | `*(手动分析)*` |
| 44 | `const COOLDOWN_OVERLAY := Color("00000080")` | `*(手动分析)*` |
| 45 | `const SECTION_TITLE_COLOR := Color("9D8FBF")` | `*(手动分析)*` |
| 49 | `0: Color("00FFD4"), 1: Color("0088FF"), 2: Color("66FF66"),` | `*(手动分析)*` |
| 50 | `3: Color("8844FF"), 4: Color("FF4444"), 5: Color("FF8800"),` | `*(手动分析)*` |
| 51 | `6: Color("FF44AA"),` | `*(手动分析)*` |
| 56 | `"enhanced_projectile": Color("FFD94D"),` | `*(手动分析)*` |
| 57 | `"dot_projectile": Color("3366CC"),` | `*(手动分析)*` |
| 58 | `"explosive_projectile": Color("FF6633"),` | `*(手动分析)*` |
| 59 | `"shockwave": Color("8822BB"),` | `*(手动分析)*` |
| 60 | `"magic_circle": Color("FFCC00"),` | `*(手动分析)*` |
| 61 | `"celestial_strike": Color("CC1111"),` | `*(手动分析)*` |
| 62 | `"shield_heal": Color("33E666"),` | `*(手动分析)*` |
| 63 | `"summon_construct": Color("2233BB"),` | `*(手动分析)*` |
| 64 | `"charged_projectile": Color("D9D9F2"),` | `*(手动分析)*` |
| 65 | `"slow_field": Color("4D4DBB"),` | `*(手动分析)*` |
| 66 | `"generic_blast": Color("808080"),` | `*(手动分析)*` |
| 179 | `var note_color: Color = NOTE_COLORS.get(note_key, Color(0.5, 0.5, 0.5))` | `*(手动分析)*` |
| 181 | `draw_rect(rect.grow(-4), Color(note_color.r, note_color.g, note_color.b, 0.25))` | `*(手动分析)*` |
| 195 | `draw_rect(rect.grow(-4), Color(form_color.r, form_color.g, form_color.b, 0.2))` | `*(手动分析)*` |
| 204 | `"?", HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color("FF4444"))` | `*(手动分析)*` |
| 209 | `"—", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color("9D8FBF40"))` | `*(手动分析)*` |
| 281 | `Color("9D8FBF")` | `*(手动分析)*` |
| 298 | `var color: Color = NOTE_COLORS.get(note_key, Color(0.5, 0.5, 0.5))` | `*(手动分析)*` |
| 451 | `style.bg_color = Color(color.r, color.g, color.b, 0.5)` | `*(手动分析)*` |
| 455 | `style.shadow_color = Color(color.r, color.g, color.b, 0.6)` | `*(手动分析)*` |


### 文件: `godot_project/scripts/ui/note_inventory_ui.gd`

| 行号 | 原始代码 | 建议重构代码 |
|:---|:---|:---:|
| 38 | `const CELL_BG := Color("141026A0")` | `*(手动分析)*` |
| 39 | `const CELL_HOVER_BG := Color("9D6FFF30")` | `*(手动分析)*` |
| 40 | `const CELL_EMPTY_BG := Color("14102660")` | `*(手动分析)*` |
| 41 | `const CELL_BORDER := Color("9D6FFF40")` | `*(手动分析)*` |
| 42 | `const COUNT_COLOR := Color("EAE6FF")` | `*(手动分析)*` |
| 43 | `const EMPTY_COUNT_COLOR := Color("9D8FBF60")` | `*(手动分析)*` |
| 44 | `const SECTION_TITLE_COLOR := Color("9D8FBF")` | `*(手动分析)*` |
| 45 | `const INSUFFICIENT_FLASH_COLOR := Color("FF444480")` | `*(手动分析)*` |
| 52 | `0: Color("00FFD4"),  # C — 谐振青` | `*(手动分析)*` |
| 53 | `1: Color("0088FF"),  # D — 疾风蓝` | `*(手动分析)*` |
| 54 | `2: Color("66FF66"),  # E — 翠叶绿` | `*(手动分析)*` |
| 55 | `3: Color("8844FF"),  # F — 深渊紫` | `*(手动分析)*` |
| 56 | `4: Color("FF4444"),  # G — 烈焰红` | `*(手动分析)*` |
| 57 | `5: Color("FF8800"),  # A — 烈日橙` | `*(手动分析)*` |
| 58 | `6: Color("FF44AA"),  # B — 霓虹粉` | `*(手动分析)*` |
| 62 | `0: Color("009988"),  # C# — 谐振青暗化` | `*(手动分析)*` |
| 63 | `1: Color("005599"),  # D# — 疾风蓝暗化` | `*(手动分析)*` |
| 64 | `2: Color("6633CC"),  # F# — 深渊紫暗化` | `*(手动分析)*` |
| 65 | `3: Color("CC2222"),  # G# — 烈焰红暗化` | `*(手动分析)*` |
| 66 | `4: Color("CC6600"),  # A# — 烈日橙暗化` | `*(手动分析)*` |
| 160 | `var note_color: Color = NOTE_COLORS.get(i, Color(0.5, 0.5, 0.5))` | `*(手动分析)*` |
| 181 | `var indicator_color := note_color if count > 0 else Color(note_color.r, note_color.g, note_color.b, 0.2)` | `*(手动分析)*` |
| 186 | `var text_color := note_color if count > 0 else Color(0.4, 0.4, 0.5, 0.5)` | `*(手动分析)*` |
| 192 | `var desc_color := Color(0.6, 0.55, 0.7, 0.7) if count > 0 else Color(0.4, 0.4, 0.5, 0.3)` | `*(手动分析)*` |
| 225 | `var bk_color: Color = BLACK_KEY_COLORS.get(i, Color(0.4, 0.4, 0.4))` | `*(手动分析)*` |
| 245 | `bk_color if count > 0 else Color(bk_color.r, bk_color.g, bk_color.b, 0.2))` | `*(手动分析)*` |
| 248 | `var text_color := bk_color if count > 0 else Color(0.4, 0.4, 0.5, 0.4)` | `*(手动分析)*` |
| 255 | `var mod_desc_color := Color(0.6, 0.5, 0.7, 0.6) if count > 0 else Color(0.4, 0.4, 0.5, 0.3)` | `*(手动分析)*` |
| 318 | `var color: Color = BLACK_KEY_COLORS.get(idx, Color(0.5, 0.5, 0.5))` | `*(手动分析)*` |
| 340 | `var color: Color = NOTE_COLORS.get(i, Color(0.5, 0.5, 0.5))` | `*(手动分析)*` |
| 362 | `var color: Color = BLACK_KEY_COLORS.get(i, Color(0.4, 0.4, 0.4))` | `*(手动分析)*` |
| 414 | `style.bg_color = Color(color.r, color.g, color.b, 0.5)` | `*(手动分析)*` |
| 418 | `style.shadow_color = Color(color.r, color.g, color.b, 0.6)` | `*(手动分析)*` |


### 文件: `godot_project/scripts/ui/spellbook_panel_v3.gd`

| 行号 | 原始代码 | 建议重构代码 |
|:---|:---|:---:|
| 30 | `const CARD_BG := Color("0E0B1FB0")` | `*(手动分析)*` |
| 31 | `const CARD_HOVER_BG := Color("9D6FFF25")` | `*(手动分析)*` |
| 32 | `const CARD_EQUIPPED_BG := Color("0A081580")` | `*(手动分析)*` |
| 33 | `const CARD_BORDER := Color("9D6FFF30")` | `*(手动分析)*` |
| 34 | `const CARD_HOVER_BORDER := Color("9D6FFF80")` | `*(手动分析)*` |
| 35 | `const CARD_EQUIPPED_BORDER := Color("9D6FFF18")` | `*(手动分析)*` |
| 36 | `const SECTION_TITLE_COLOR := Color("9D8FBF")` | `*(手动分析)*` |
| 37 | `const SPELL_NAME_COLOR := Color("EAE6FF")` | `*(手动分析)*` |
| 38 | `const SPELL_NAME_EQUIPPED := Color("9D8FBF80")` | `*(手动分析)*` |
| 39 | `const FORM_DESC_COLOR := Color("9D8FBFB0")` | `*(手动分析)*` |
| 40 | `const STATUS_READY_COLOR := Color("33CC66B0")` | `*(手动分析)*` |
| 41 | `const STATUS_EQUIPPED_COLOR := Color("3399FFB0")` | `*(手动分析)*` |
| 42 | `const EMPTY_HINT_COLOR := Color("9D8FBF60")` | `*(手动分析)*` |
| 46 | `"enhanced_projectile": Color("FFD94D"),` | `*(手动分析)*` |
| 47 | `"dot_projectile": Color("3366CC"),` | `*(手动分析)*` |
| 48 | `"explosive_projectile": Color("FF6633"),` | `*(手动分析)*` |
| 49 | `"shockwave": Color("8822BB"),` | `*(手动分析)*` |
| 50 | `"magic_circle": Color("FFCC00"),` | `*(手动分析)*` |
| 51 | `"celestial_strike": Color("CC1111"),` | `*(手动分析)*` |
| 52 | `"shield_heal": Color("33E666"),` | `*(手动分析)*` |
| 53 | `"summon_construct": Color("2233BB"),` | `*(手动分析)*` |
| 54 | `"charged_projectile": Color("D9D9F2"),` | `*(手动分析)*` |
| 55 | `"slow_field": Color("4D4DBB"),` | `*(手动分析)*` |
| 56 | `"generic_blast": Color("808080"),` | `*(手动分析)*` |
| 76 | `0: Color("00FFD4"), 1: Color("0088FF"), 2: Color("66FF66"),` | `*(手动分析)*` |
| 77 | `3: Color("8844FF"), 4: Color("FF4444"), 5: Color("FF8800"),` | `*(手动分析)*` |
| 78 | `6: Color("FF44AA"),` | `*(手动分析)*` |
| 126 | `HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("9D8FBF80"))` | `*(手动分析)*` |
| 134 | `"在上方炼成区合成", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("9D8FBF40"))` | `*(手动分析)*` |
| 197 | `var root_color: Color = NOTE_COLORS.get(root_note, Color(0.5, 0.5, 0.5))` | `*(手动分析)*` |
| 330 | `style.bg_color = Color(color.r, color.g, color.b, 0.4)` | `*(手动分析)*` |
| 334 | `style.shadow_color = Color(color.r, color.g, color.b, 0.5)` | `*(手动分析)*` |


### 文件: `godot_project/scripts/ui/help_panel.gd`

| 行号 | 原始代码 | 建议重构代码 |
|:---|:---|:---:|
| 24 | `const COL_BG := Color("#0A0814F2")` | `UIColors.with_alpha(UIColors.PRIMARY_BG, 0.95)` |
| 25 | `const COL_PANEL_BG := Color("#141026")` | `UIColors.PANEL_BG` |
| 26 | `const COL_ACCENT := Color("#9D6FFF")` | `UIColors.ACCENT` |
| 27 | `const COL_GOLD := Color("#FFD700")` | `UIColors.GOLD` |
| 28 | `const COL_OFFENSE := Color("#FF4444")` | `*(手动分析)*` |
| 29 | `const COL_DEFENSE := Color("#4488FF")` | `*(手动分析)*` |
| 30 | `const COL_CORE := Color("#9D6FFF")` | `UIColors.ACCENT` |
| 31 | `const COL_TEXT_PRIMARY := Color("#EAE6FF")` | `UIColors.TEXT_PRIMARY` |
| 32 | `const COL_TEXT_SECONDARY := Color("#A098C8")` | `UIColors.TEXT_SECONDARY` |
| 33 | `const COL_TEXT_DIM := Color("#6B668A")` | `UIColors.TEXT_DIM` |
| 170 | `ps.shadow_color = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.15)` | `*(手动分析)*` |
| 191 | `cs.bg_color = Color(0.3, 0.1, 0.1, 0.3)` | `*(手动分析)*` |
| 203 | `sep.color = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.4)` | `*(手动分析)*` |
| 217 | `bs.bg_color = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.1)` | `*(手动分析)*` |
| 218 | `bs.border_color = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.3)` | `*(手动分析)*` |
| 224 | `ba.bg_color = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.25)` | `*(手动分析)*` |
| 328 | `s.bg_color = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.08)` | `*(手动分析)*` |
| 329 | `s.border_color = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.2)` | `*(手动分析)*` |
| 341 | `s.bg_color = Color(color.r, color.g, color.b, 0.08)` | `*(手动分析)*` |
| 342 | `s.border_color = Color(color.r, color.g, color.b, 0.4)` | `*(手动分析)*` |
| 389 | `_tutorial_overlay.color = Color(0, 0, 0, 0.7)` | `*(手动分析)*` |
| 401 | `ps.bg_color = Color(COL_PANEL_BG.r, COL_PANEL_BG.g, COL_PANEL_BG.b, 0.95)` | `*(手动分析)*` |
| 439 | `ss.bg_color = Color(0.1, 0.08, 0.15, 0.5)` | `*(手动分析)*` |
| 453 | `ns.bg_color = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.3)` | `*(手动分析)*` |
| 551 | `s.bg_color = Color(0.08, 0.06, 0.15, 0.8)` | `UIColors.with_alpha(UIColors.PANEL_BG, 0.8)` |
| 552 | `s.border_color = Color("#9D6FFF")` | `UIColors.ACCENT` |
| 559 | `hs.bg_color = Color(0.15, 0.1, 0.25, 0.9)` | `*(手动分析)*` |
| 560 | `hs.border_color = Color("#FFD700")` | `UIColors.GOLD` |
| 562 | `btn.add_theme_color_override("font_color", Color("#A098C8"))` | `UIColors.TEXT_SECONDARY` |
| 563 | `btn.add_theme_color_override("font_hover_color", Color("#FFD700"))` | `UIColors.GOLD` |


### 文件: `godot_project/scripts/ui/timbre_wheel_ui.gd`

| 行号 | 原始代码 | 建议重构代码 |
|:---|:---|:---:|
| 52 | `"color": Color("#4DFFF3"),` | `UIColors.ACCENT_2` |
| 75 | `"color": Color("#FF8C42"),` | `UIColors.WARNING` |
| 92 | `"color": Color("#9D6FFF"),` | `UIColors.ACCENT` |
| 109 | `"color": Color("#4DFF80"),` | `UIColors.SUCCESS` |
| 134 | `"color": Color("#00E6B8"),` | `*(手动分析)*` |
| 321 | `draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.45 * alpha))` | `*(手动分析)*` |
| 400 | `var name_color := q_color if is_selected or is_gain_quadrant else Color(0.7, 0.7, 0.8)` | `*(手动分析)*` |
| 405 | `HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color(0.5, 0.5, 0.6, 0.6 * alpha))` | `*(手动分析)*` |
| 421 | `var t_color := Color.WHITE if is_unlocked else Color(0.4, 0.4, 0.45)` | `*(手动分析)*` |
| 433 | `HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color(0.5, 0.5, 0.55, alpha))` | `*(手动分析)*` |
| 448 | `var center_fill := Color(0.05, 0.05, 0.1, 0.9 * alpha)` | `*(手动分析)*` |
| 455 | `var center_border := CENTER_TIMBRE["color"] if center_selected else Color(0.3, 0.3, 0.4)` | `*(手动分析)*` |
| 463 | `var center_name_color := CENTER_TIMBRE["color"] if center_selected else Color(0.7, 0.7, 0.8)` | `*(手动分析)*` |
| 468 | `HORIZONTAL_ALIGNMENT_CENTER, -1, 7, Color(0.5, 0.5, 0.6, 0.5 * alpha))` | `*(手动分析)*` |
| 473 | `HORIZONTAL_ALIGNMENT_CENTER, -1, 7, Color(0.0, 0.9, 0.7, 0.8 * alpha))` | `*(手动分析)*` |
| 483 | `HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color(0.5, 0.5, 0.6, 0.6 * alpha))` | `*(手动分析)*` |
| 492 | `var bg_color := Color(0.08, 0.06, 0.15, 0.85 * alpha)` | `*(手动分析)*` |
| 521 | `draw_rect(detail_rect, Color(0.0, 0.0, 0.0, 0.75 * alpha))` | `*(手动分析)*` |
| 523 | `draw_rect(detail_rect, Color(q_color.r, q_color.g, q_color.b, 0.4 * alpha), false, 1.0)` | `*(手动分析)*` |
| 528 | `HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.8, 0.8, 0.9, alpha))` | `*(手动分析)*` |
| 534 | `HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.85, 0.3, alpha))` | `*(手动分析)*` |
| 538 | `HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.8, 0.5, 0.3, alpha))` | `*(手动分析)*` |
| 543 | `HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.0, 0.8, 0.6, 0.7 * alpha))` | `*(手动分析)*` |
| 549 | `HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.85, 0.3, alpha))` | `*(手动分析)*` |
| 552 | `HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.5, 0.5, 0.55, alpha))` | `*(手动分析)*` |
| 555 | `HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.5, 0.5, 0.55, 0.7 * alpha))` | `*(手动分析)*` |


### 文件: `godot_project/scripts/ui/hud.gd`

| 行号 | 原始代码 | 建议重构代码 |
|:---|:---|:---:|
| 250 | `_suggestion_label.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))` | `*(手动分析)*` |
| 261 | `indicator.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.3))` | `*(手动分析)*` |
| 273 | `_overload_warning.add_theme_color_override("font_color", Color(1.0, 0.3, 0.1))` | `*(手动分析)*` |
| 288 | `_progression_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))` | `*(手动分析)*` |
| 301 | `_mode_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9, 0.8))` | `*(手动分析)*` |
| 311 | `_crit_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2, 0.9))` | `*(手动分析)*` |
| 396 | `suggestion_color = Color(1.0, 0.3, 0.2)` | `*(手动分析)*` |
| 398 | `suggestion_color = Color(1.0, 0.8, 0.2)` | `*(手动分析)*` |
| 400 | `suggestion_color = Color(0.6, 0.9, 1.0)` | `*(手动分析)*` |
| 547 | `tween.tween_property(_progression_label, "modulate", Color(1.0, 1.0, 0.5), 0.1)` | `*(手动分析)*` |
| 548 | `tween.tween_property(_progression_label, "modulate", Color(0.2, 1.0, 0.6), 0.3)` | `*(手动分析)*` |
| 599 | `"font_color", Color(1.0, 0.2, 0.2, alpha)` | `*(手动分析)*` |
| 741 | `_progression_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))` | `*(手动分析)*` |
| 746 | `tween.tween_property(_progression_label, "modulate", Color(0.4, 0.9, 1.0), 0.15)` | `*(手动分析)*` |
| 747 | `tween.tween_property(_progression_label, "modulate", Color(0.2, 1.0, 0.6), 0.4)` | `*(手动分析)*` |
| 750 | `_progression_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))` | `*(手动分析)*` |
| 784 | `_xp_bar_bg.color = Color(0.05, 0.05, 0.1, 0.7)` | `*(手动分析)*` |
| 791 | `_xp_bar_fill.color = Color(0.0, 0.9, 0.8, 0.85)` | `*(手动分析)*` |
| 808 | `_xp_bar_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))` | `*(手动分析)*` |
| 810 | `_xp_bar_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))` | `*(手动分析)*` |
| 836 | `var base_color := Color(0.0, 0.9, 0.8).lerp(Color(1.0, 0.85, 0.2), level_color_t)` | `*(手动分析)*` |
| 846 | `base_color = base_color.lerp(Color(1.0, 1.0, 0.5), flash_intensity * 0.8)` | `*(手动分析)*` |
| 848 | `_xp_bar_bg.color = Color(0.05, 0.05, 0.1, 0.7).lerp(` | `*(手动分析)*` |
| 849 | `Color(0.2, 0.2, 0.1, 0.9), flash_intensity * 0.5` | `*(手动分析)*` |
| 853 | `_xp_bar_bg.color = Color(0.05, 0.05, 0.1, 0.7)` | `*(手动分析)*` |


