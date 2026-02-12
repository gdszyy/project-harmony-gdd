# 文档与实现一致性分析报告 (DOC-01, CODE-02, CODE-03)

**版本**: 1.0
**日期**: 2026-02-12
**作者**: Manus AI

## 1. 分析概述

本次分析旨在解决 Project Harmony 验收问题中提出的【DOC-01】、【CODE-02】和【CODE-03】，并在此基础上，对全部 7 个 UI 设计模块的文档与代码实现进行全面的一致性审查。通过克隆 `gdszyy/project-harmony-gdd` 仓库，我们系统性地对比了设计文档中提及的所有文件名与项目中的实际文件，深入分析了功能实现的差异，并定位了所有需要修正的文档内容。

分析确认，验收问题中指出的三项问题均属实，且在其他模块中也存在大量类似的文件命名不一致和功能实现与文档脱节的问题。本报告将详细列出所有发现，并提供具体的修复建议。

## 2. 核心问题分析

### 2.1. 【DOC-01】模块1 `SceneManager.gd` 与 `waveform.gdshader` 缺失

#### 2.1.1. `SceneManager.gd` vs `UITransitionManager.gd`

经过分析，我们确认设计文档 `Docs/UI_Design_Module1_MainMenu.md` 中要求的全局场景管理器 `SceneManager.gd` 在代码中并未以此名称实现。然而，项目中存在一个名为 `godot_project/scripts/ui/ui_transition_manager.gd` 的 Autoload 单例脚本，其功能与文档描述完全吻合。

**功能对比:**

| 功能点 | 文档要求 (`SceneManager.gd`) | 实际实现 (`UITransitionManager.gd`) |
| :--- | :--- | :--- |
| **角色** | 全局单例 (Autoload) 场景管理器 | 全局单例 (Autoload) UI 页面转场管理器 |
| **核心API** | `SceneManager.switch_scene(path, type)` | `UITransitionManager.transition_to_scene(path, type)` |
| **转场类型** | 支持 "glitch" 等多种转场 | 支持 "glitch", "fade", "instant" 三种转场 |
| **实现方式** | 通过 `CanvasLayer` 和 `Shader` 实现 | 通过 `CanvasLayer` 和 `glitch_transition.gdshader` 实现 |

**结论**: `UITransitionManager.gd` 实际上就是文档中所构想的 `SceneManager.gd`。这是一个典型的 **命名不一致** 问题，而非功能缺失。实现的功能完全覆盖了文档需求。

#### 2.1.2. `waveform.gdshader` 缺失情况

对仓库的全面搜索确认，`waveform.gdshader` 文件确实 **不存在** 于项目中。然而，在 `godot_project/scripts/scenes/main_menu.gd` 脚本中，存在明确的加载和使用该着色器的代码逻辑：

```gdscript
// godot_project/scripts/scenes/main_menu.gd
@onready var _waveform_rect: ColorRect = $WaveformRect

func _setup_vfx():
    // ...
    if _waveform_rect:
        var waveform_shader := load("res://shaders/waveform.gdshader") if ResourceLoader.exists("res://shaders/waveform.gdshader") else null
        if waveform_shader:
            var mat := ShaderMaterial.new()
            mat.shader = waveform_shader
            _waveform_rect.material = mat
```

代码通过 `ResourceLoader.exists()` 进行了安全检查，因此在文件缺失时不会引发运行时错误，但这导致了文档所描述的“谐振波形”背景动效未能实现。

**结论**: `waveform.gdshader` 文件 **完全缺失**，属于实现与文档脱节。

### 2.2. 【CODE-02】 & 【CODE-03】模块6、7文件名不一致

分析确认，这两项均为简单的文件名不一致问题：

- **模块6**: 文档 `Docs/UI_Design_Module6_ResonanceSlicing.md` 中提到的 `phase_energy_ring.gd`，实际实现为 `godot_project/scripts/ui/phase_energy_bar.gd`。
- **模块7**: 文档 `Docs/UI_Design_Module7_TutorialAux.md` 中提到的 `tooltip_controller.gd`，实际实现为 `godot_project/scripts/ui/tooltip_system.gd`。

## 3. 全面命名一致性审查结果

除了上述三项，我们对全部 7 个 UI 模块的文档进行了扫描，发现了大量命名不一致或文件缺失的情况。下表汇总了所有需要修正的问题点。

| 模块 | 文档路径 | 文档中名称 | 状态 | 实际名称 / 备注 |
| :--- | :--- | :--- | :--- | :--- |
| **1** | `UI_Design_Module1_MainMenu.md` | `SceneManager.gd` | 命名不一致 | `ui_transition_manager.gd` |
| **1** | `UI_Design_Module1_MainMenu.md` | `waveform.gdshader` | **缺失** | 文件完全缺失 |
| **2** | `UI_Design_Module2_BattleHUD.md` | `sequencer_ring.gd` | 命名不一致 | `sequencer_ui.gd` |
| **2** | `UI_Design_Module2_BattleHUD.md` | `DamageNumber.tscn` | 命名不一致 | `damage_number.tscn` (小写) |
| **2** | `UI_Design_Module2_BattleHUD.md` | `ammo_ring.gd` | 命名不一致 | `ammo_ring_hud.gd` |
| **3** | `UI_Design_Module3_IntegratedComposer.md` | `Theme.tres` | 命名不一致 | `GlobalTheme.tres` |
| **4** | `UI_Design_Module4_CircleOfFifths.md` | `Compass.tscn` | **缺失** | 功能由 `circle_of_fifths_upgrade_v3.gd` 通过自定义绘制实现，无独立场景 |
| **4** | `UI_Design_Module4_CircleOfFifths.md` | `compass.gd` | 命名不一致 | `circle_of_fifths_upgrade_v3.gd` |
| **4** | `UI_Design_Module4_CircleOfFifths.md` | `UpgradeData.gd` | **缺失** | 未找到对应的升级数据资源定义文件 |
| **4** | `UI_Design_Module4_CircleOfFifths.md` | `compass_glow_border.gdshader` | **缺失** | 功能可能已合并到其他 shader 或未实现 |
| **4** | `UI_Design_Module4_CircleOfFifths.md` | `nebula_core.gdshader` | **缺失** | 功能可能已合并到其他 shader 或未实现 |
| **5** | `UI_Design_Module5_HallOfHarmony.md` | `HallOfHarmony.tscn` | 命名不一致 | `hall_of_harmony.tscn` (小写) |
| **6** | `UI_Design_Module6_ResonanceSlicing.md` | `phase_indicator.gd` | 命名不一致 | `phase_indicator_ui.gd` |
| **6** | `UI_Design_Module6_ResonanceSlicing.md` | `phase_energy_ring.gd` | 命名不一致 | `phase_energy_bar.gd` |
| **6** | `UI_Design_Module6_ResonanceSlicing.md` | `spectrum_offset_fatigue_bar.gd` | 命名不一致 | `spectral_fatigue_indicator.gd` |
| **6** | `UI_Design_Module6_ResonanceSlicing.md` | `timbre_wheel_phase_extension.gd` | **功能合并** | 相关功能已直接在 `timbre_wheel_ui.gd` 中实现，无需独立文件 |
| **6** | `UI_Design_Module6_ResonanceSlicing.md` | `phase_transition_effect.gd` | 命名不一致 | `phase_transition_overlay.gd` |
| **6** | `UI_Design_Module6_ResonanceSlicing.md` | `gain_hint_panel.gd` | 命名不一致 | `phase_gain_hint.gd` |
| **6** | `UI_Design_Module6_ResonanceSlicing.md` | `gain_hint_panel.tscn` | 命名不一致 | `phase_gain_hint.tscn` |
| **6** | `UI_Design_Module6_ResonanceSlicing.md` | `hud_phase_tint.gdshader` | **功能合并** | 功能由 `phase_hud_tint_manager.gd` 脚本控制，无独立 shader 文件 |
| **7** | `UI_Design_Module7_TutorialAux.md` | `TutorialManager.gd` | 命名不一致 | `tutorial_manager.gd` (位于 `scripts/systems/` 目录下) |
| **7** | `UI_Design_Module7_TutorialAux.md` | `TutorialHighlight.tscn` | **功能合并** | 功能由 `tutorial_hint_manager.gd` 脚本控制，无独立场景 |
| **7** | `UI_Design_Module7_TutorialAux.md` | `TutorialHintArrow.tscn` | **功能合并** | 功能由 `tutorial_hint_manager.gd` 脚本控制，无独立场景 |
| **7** | `UI_Design_Module7_TutorialAux.md` | `loading_tips.json` | **缺失** | 未找到该文件，提示文本可能硬编码在 `loading_screen.gd` 中 |
| **7** | `UI_Design_Module7_TutorialAux.md` | `ConfirmationDialog.gd` | 命名不一致 | `dialog_system.gd` |
| **7** | `UI_Design_Module7_TutorialAux.md` | `NotificationManager.gd` | 命名不一致 | `notification_manager.gd` (Autoload) |
| **7** | `UI_Design_Module7_TutorialAux.md` | `ToastPanel.tscn` | 命名不一致 | `toast_notification.tscn` |
| **7** | `UI_Design_Module7_TutorialAux.md` | `tooltip_controller.gd` | 命名不一致 | `tooltip_system.gd` |

## 4. 修复建议

建议创建专门的 Task 来逐一修正上述所有设计文档中的不一致之处。修复工作应以 **更新文档以匹配当前代码实现** 为原则，而不是修改代码来匹配旧文档。

**具体修改内容示例:**

1.  **对于 `Docs/UI_Design_Module1_MainMenu.md`:**
    *   将所有 `SceneManager.gd` 的引用修改为 `UITransitionManager.gd`。
    *   在 `7.1. 节点结构` 部分，将 `SceneManager.gd` 的描述更新为 `UITransitionManager.gd`。
    *   在 `7.2. 信号连接` 部分，将示例代码 `SceneManager.switch_scene(...)` 修改为 `UITransitionManager.transition_to_scene(...)`。
    *   添加一条备注，说明 `waveform.gdshader` 文件当前缺失，相关功能未实现。

2.  **对于 `Docs/UI_Design_Module6_ResonanceSlicing.md`:**
    *   将 `phase_energy_ring.gd` 修改为 `phase_energy_bar.gd`。
    *   将 `spectrum_offset_fatigue_bar.gd` 修改为 `spectral_fatigue_indicator.gd`。
    *   删除对 `timbre_wheel_phase_extension.gd` 的引用，并说明其功能已整合进 `timbre_wheel_ui.gd`。

3.  **对于 `Docs/UI_Design_Module4_CircleOfFifths.md`:**
    *   删除对 `Compass.tscn` 的引用，并解释罗盘视觉效果是由 `circle_of_fifths_upgrade_v3.gd` 脚本通过 `_draw()` 函数动态绘制的。
    *   将 `compass.gd` 的引用修改为 `circle_of_fifths_upgrade_v3.gd`。
    *   标记 `UpgradeData.gd`, `compass_glow_border.gdshader`, `nebula_core.gdshader` 为已废弃或未实现。

对所有其他不一致项，均应参照以上方式进行修正，确保文档的准确性和时效性，为后续的开发与维护工作提供可靠的参考依据。
