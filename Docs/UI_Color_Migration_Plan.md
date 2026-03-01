# Project Harmony - UI 颜色系统迁移与重构计划

**角色:** UI 重构工程师 (Agent)  
**日期:** 2026年3月1日  
**相关报告:** `UI_Color_Audit_Report.md`

## 1. 迁移目标

本计划旨在解决 Project Harmony UI 系统中存在的硬编码颜色问题，统一视觉规范，实现以下目标：
1. **消除硬编码:** 将所有 68 个 UI 相关脚本中的硬编码颜色替换为对 `UIColors` 单例的引用。
2. **对齐设计文档:** 修复 `ui_colors.gd` 中与《美术与VFX方向总文档》及《UI设计模块3》冲突的颜色定义（特别是音符颜色）。
3. **完善全局规范:** 将散落在各处的系统级颜色（如章节主题色、音色颜色、敌人类型色）整合进 `UIColors`。
4. **提升可维护性:** 为未来的主题切换和色盲模式实装扫清障碍。

## 2. 阶段一：全局规范 `ui_colors.gd` 修订 (优先级: P0)

在修改任何 UI 脚本之前，必须首先确保 `ui_colors.gd` 是完整且准确的。

### 2.1. 修复音符颜色冲突
将 `NOTE_COLORS` 字典完全重写，对齐设计文档中的“七音符色彩映射”：
```gdscript
const NOTE_COLORS: Dictionary = {
    "C": Color("#00FFD4"),  # 谐振青
    "D": Color("#0088FF"),  # 疾风蓝
    "E": Color("#66FF66"),  # 翠叶绿
    "F": Color("#8844FF"),  # 深渊紫
    "G": Color("#FF4444"),  # 烈焰红
    "A": Color("#FF8800"),  # 烈日橙
    "B": Color("#FF44AA"),  # 霓虹粉
}
```
*注意：同步更新黑键颜色 `BLACK_KEY_COLORS`，保持与其对应白键色相一致但暗化/锐化的原则。*

### 2.2. 补充缺失的系统级颜色
在 `ui_colors.gd` 中新增以下常量字典，以容纳目前硬编码在各个脚本中的颜色：

1. **章节主题色 (`CHAPTER_COLORS`)**：整合 `ui_theme_manager.gd` 和 `main_game.gd` 中的章节颜色。
2. **音色/乐器族群色 (`TIMBRE_CLASS_COLORS`)**：整合 `player_visual_enhancer.gd` 和 `spell_visual_manager.gd` 中的 0-4 索引颜色。
3. **敌人类型色 (`ENEMY_TYPE_COLORS`)**：整合 `main_game.gd` 和 `test_chamber.gd` 中的基础敌人颜色。
4. **评级颜色 (`RATING_COLORS`)**：整合 `game_over.gd` 中的 S-D 级颜色。

## 3. 阶段二：核心 UI 脚本重构 (优先级: P0)

这些文件是游戏流程的核心，且包含了大量的本地常量重复定义，需要立即修复。

### 3.1. `game_over.gd`
- **操作:** 移除文件头部的 `PANEL_BG`, `ACCENT_COLOR`, `TEXT_PRIMARY` 等常量定义。
- **替换:** 在代码中直接使用 `UIColors.PANEL_BG`, `UIColors.ACCENT` 等。
- **重构:** 将 `RATING_COLORS` 字典迁移至 `UIColors`，通过 `UIColors.get_rating_color(rating)` 获取。

### 3.2. `main_menu.gd`
- **操作:** 移除 `COLOR_TITLE`, `COLOR_SUBTITLE`, `COLOR_ACCENT`, `COLOR_PANEL_BG`, `COLOR_PANEL_BORDER` 等常量。
- **替换:** 使用 `UIColors.TEXT_PRIMARY`, `UIColors.TEXT_SECONDARY`, `UIColors.ACCENT`, `UIColors.PANEL_BG` (结合 `with_alpha` 方法) 替代。

### 3.3. `ui_theme_manager.gd`
- **操作:** 移除庞大的 `CHAPTER_UI_COLORS` 字典。
- **重构:** 将主题颜色的获取逻辑委托给 `UIColors` 单例，例如调用 `UIColors.get_chapter_theme(chapter_index)`。

## 4. 阶段三：视觉与特效脚本重构 (优先级: P1)

这些脚本中存在大量在代码逻辑中内联实例化的 `Color(r, g, b)`。

### 4.1. `player_visual_enhancer.gd` & `spell_visual_manager.gd`
- **操作:** 移除本地的 `TIMBRE_COLORS` 字典。
- **替换:** 使用 `UIColors.TIMBRE_CLASS_COLORS`。
- **重构:** 脚本中大量使用了带透明度的颜色构建（如 `Color(r, g, b, alpha)`），应统一使用 `UIColors.with_alpha(base_color, alpha)` 方法来生成，确保基础色调的一致性。

### 4.2. `main_game.gd`
- **操作:** 移除 `_get_enemy_color` 方法中的硬编码颜色，改为查询 `UIColors.ENEMY_TYPE_COLORS`。
- **操作:** 移除第 633 行硬编码的 `chapter_colors` 数组，改为查询 `UIColors.CHAPTER_COLORS`。
- **操作:** 将屏幕闪烁（Screen Flash）特效使用的颜色替换为 `UIColors` 中的功能色（如 `UIColors.WARNING`, `UIColors.INFO`）。

### 4.3. `enemy_visual_enhancer.gd` & `boss_visual_enhancer.gd`
- **操作:** 将敌人和Boss的阶段性颜色（如洋红、橙色、红色）统一映射到 `ui_colors.gd` 中现有的 `BOSS_PHASE_COLORS` 或 `BOSS_RAGE_COLORS`。

## 5. 阶段四：次要与测试脚本清理 (优先级: P2)

### 5.1. `boss_guido.gd`
- **操作:** 将 Boss 专属的硬编码颜色（如 `Color(0.9, 0.75, 0.2)`）提取到 `ui_colors.gd` 中作为 Boss 专属调色板，或复用现有的 `EMOTION_COLORS`。

### 5.2. `test_chamber.gd`
- **操作:** 尽管是测试场景，也应将 `GRID_COLOR`, `GRID_ACCENT`, `BORDER_COLOR` 等常量替换为 `UIColors` 中的等效颜色（如 `UIColors.PANEL_DARK`, `UIColors.ACCENT`），以保证测试环境与实际游戏视觉一致。

## 6. 实施规范与最佳实践

在执行上述重构时，开发团队必须遵循以下规范：

1. **绝对禁止硬编码:** 任何 UI、视觉、特效脚本中，除非是纯粹的透明度控制（如 `Color(1, 1, 1, 0)`），否则严禁出现新的 `Color(r, g, b)` 或 `Color("#...")` 实例化。
2. **使用透明度辅助方法:** 需要调整透明度时，使用 `UIColors.with_alpha(UIColors.SOME_COLOR, 0.5)`，而不是手动拆解 RGB。
3. **颜色语义化:** 在 `ui_colors.gd` 中定义颜色时，应注重其**语义**（如 `SUCCESS`, `DANGER`, `FATIGUE_SEVERE`）而非纯粹的外观（如 `GREEN`, `RED`），这有助于未来的主题切换（例如在色盲模式下，`DANGER` 可能不再是红色）。
4. **增量测试:** 每次重构一个核心脚本后，必须运行游戏并在相应界面验证视觉效果是否与重构前保持一致（除非是故意修复的规范冲突，如音符颜色）。
