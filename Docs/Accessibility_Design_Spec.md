# Project Harmony — 可访问性设计规范

**文档类型**: 设计规范 (Design Specification)
**作者**: accessibility_designer (Manus AI)
**日期**: 2026-03-01
**版本**: 1.0
**关联任务**: tsk-1a4337cd-499 [设计-P1] 实装色盲模式与降低视觉闪烁选项

---

## 目录

1. [背景与目标](#1-背景与目标)
2. [颜色依赖 UI 元素审计](#2-颜色依赖-ui-元素审计)
3. [色盲模式设计](#3-色盲模式设计)
4. [低视觉闪烁模式设计](#4-低视觉闪烁模式设计)
5. [设置菜单 UI 布局](#5-设置菜单-ui-布局)
6. [技术实现指南](#6-技术实现指南)
7. [测试与验证标准](#7-测试与验证标准)

---

## 1. 背景与目标

《Project Harmony》是一款以音乐理论为核心玩法的幸存者类肉鸽游戏，其 UI 系统大量使用颜色来传递关键游戏信息。UI 设计评估报告和交互设计评估报告均指出，游戏中存在以下可访问性风险：

**颜色依赖问题**: 游戏中的谐振青 (`#00FFD4`)、Dominant 黄 (`#FFE066`)、错误红 (`#FF2244`)、以及七个音符各自的专属颜色，是玩家识别游戏状态的主要视觉线索。对于约 8% 的男性玩家和 0.5% 的女性玩家而言（色觉障碍的全球发生率），这些颜色区分可能完全失效。

**光敏安全问题**: 游戏的核心美学"故障艺术（Glitch Art）"包含大量高频闪烁效果，包括 `enemy_glitch.gdshader`、节拍闪光、受伤白屏等。国际癫痫基金会（ILAE）建议，任何面向公众的视觉内容都应避免超过 3 Hz 的高对比度闪烁，以防止诱发光敏性癫痫发作。

**本规范的目标**是在不破坏游戏核心美学的前提下，通过引入可选的可访问性模式，使游戏对色觉障碍玩家和光敏感玩家友好。

---

## 2. 颜色依赖 UI 元素审计

以下是对所有依赖颜色区分的核心 UI 元素的完整审计，按照风险等级排序：

### 2.1. 高风险元素（颜色是唯一区分手段）

| 元素名称 | 所在模块 | 颜色依赖描述 | 色盲类型影响 |
| :--- | :--- | :--- | :--- |
| **音符类型标识** | 序列器状态环、弹药环 | 7 种音符（C/D/E/F/G/A/B）各有专属颜色，颜色是区分音符种类的唯一手段 | 红绿色盲：G(红)与E(绿)混淆；全色盲：所有音符无法区分 |
| **危险警告文本** | 战斗 HUD | `DENSITY OVERLOAD` 等警告仅通过红色文本和红色闪烁传达危险 | 红色盲：完全无法察觉警告 |
| **疲劳指数状态** | 疲劳条 | 从绿色(安全)→黄色(警告)→红色(危险)的渐变，仅靠颜色区分状态 | 红绿色盲：无法区分安全与危险状态 |
| **节拍判定反馈** | 节拍指示器 | 完美(圣光金)、良好(白)、错过(红)，仅靠颜色区分判定结果 | 红绿色盲：无法区分"良好"与"错过" |

### 2.2. 中风险元素（颜色是主要区分手段，辅以形状）

| 元素名称 | 所在模块 | 颜色依赖描述 | 色盲类型影响 |
| :--- | :--- | :--- | :--- |
| **升级方向标识** | 五度圈罗盘 | 进攻方向(Dominant黄)、防御方向(治愈绿)、核心方向(晶体白)，虽有文字说明，但颜色是快速识别的主要手段 | 蓝黄色盲：黄色与白色混淆 |
| **弹药环弧段** | 战斗 HUD | 各音色的弹药弧段颜色与音符特征色对应，弧段长度表示弹药量 | 红绿色盲：G(红)与E(绿)弧段混淆 |
| **谐振完整度（血条）** | 战斗 HUD | 从谐振青(正常)→腐蚀紫(受伤)→错误红(危险)，有波形形状变化辅助，但颜色是主要信号 | 红绿色盲：危险状态的红色不明显 |

### 2.3. 低风险元素（颜色是辅助手段，有其他线索）

| 元素名称 | 所在模块 | 颜色依赖描述 |
| :--- | :--- | :--- |
| **五度圈当前调性** | 五度圈罗盘 | 谐振青高亮当前调性，但位置信息（刻度位置）也是明确线索 |
| **冷却状态遮罩** | 手动法术槽 | 深色遮罩+数字倒计时，颜色仅起辅助作用 |
| **Boss 血条阶段** | Boss 血条 | 有明确的阶段标记线，颜色仅为主题化装饰 |

---

## 3. 色盲模式设计

### 3.1. 设计原则

本规范遵循 **WCAG 2.1 AA 级**可访问性标准，核心原则如下：

> **不得将颜色作为传递信息的唯一视觉手段。** 所有依赖颜色区分的 UI 元素，必须同时提供形状、纹理、图标或文字等次级视觉线索。

### 3.2. 次级视觉线索系统：音符符号体系

为 7 种音符设计一套独特的几何符号，该符号体系在所有色盲模式下均可见：

| 音符 | 原始颜色 | 几何符号 | 符号含义 | 符号形状描述 |
| :--- | :--- | :---: | :--- | :--- |
| **C** | 谐振青 `#00FFD4` | ◉ | 均衡/中性 | 带中心点的圆形（靶心） |
| **D** | 疾风蓝 `#0088FF` | ▲ | 极速/远程 | 向上等边三角形 |
| **E** | 翠叶绿 `#66FF66` | ■ | 范围/持久 | 实心正方形 |
| **F** | 深渊紫 `#8844FF` | ◆ | 控制/神秘 | 实心菱形 |
| **G** | 烈焰红 `#FF4444` | ✦ | 爆发/攻击 | 四角星（锐角） |
| **A** | 烈日橙 `#FF8800` | ⬡ | 持久/温暖 | 正六边形 |
| **B** | 霓虹粉 `#FF44AA` | ▼ | 锐利/高速 | 向下等边三角形 |

**实现方式**: 在序列器状态环的每个有音符的刻度标记上，以及弹药环的每个弧段中心，叠加渲染对应的几何符号（使用 `Label` 节点或专用 `Sprite2D`）。符号颜色在色盲模式下统一使用高对比度的**晶体白** (`#EAE6FF`)，以确保在任何背景下均可见。

### 3.3. 三种色盲模式的调色板方案

在 `UIColors` 单例中，为每种色盲模式提供一套完整的颜色重载方案：

#### 3.3.1. 红绿色盲模式 (Protanopia / Deuteranopia)

红绿色盲是最常见的色觉障碍，患者无法区分红色和绿色。

| 原始颜色名称 | 原始色值 | 替代色值 | 替代颜色名称 | 调整原因 |
| :--- | :--- | :--- | :--- | :--- |
| 错误红 (危险) | `#FF2244` | `#FF8C00` | 警戒橙 | 橙色在红绿色盲下清晰可辨 |
| 翠叶绿 E音符 | `#66FF66` | `#00BFFF` | 天蓝色 | 蓝色与红色无混淆 |
| 治愈绿 (防御) | `#66FFB2` | `#00CED1` | 暗青色 | 与黄色形成明确对比 |
| 故障洋红 (极危) | `#FF00AA` | `#FF6600` | 深橙色 | 提高危险辨识度 |
| 疲劳条安全绿 | `#00FF88` | `#00BFFF` | 天蓝色 | 避免与红色混淆 |

#### 3.3.2. 蓝黄色盲模式 (Tritanopia)

蓝黄色盲患者无法区分蓝色和黄色。

| 原始颜色名称 | 原始色值 | 替代色值 | 替代颜色名称 | 调整原因 |
| :--- | :--- | :--- | :--- | :--- |
| Dominant 黄 | `#FFE066` | `#FF4500` | 橙红色 | 红色在蓝黄色盲下清晰可辨 |
| 圣光金 (完美节拍) | `#FFD700` | `#FF6347` | 番茄红 | 与蓝色系形成对比 |
| 谐振青 | `#00FFD4` | `#00FF00` | 纯绿色 | 绿色在蓝黄色盲下可辨 |
| 和弦蓝 | `#4D9FFF` | `#FF69B4` | 热粉色 | 与黄色系形成对比 |
| 疾风蓝 D音符 | `#0088FF` | `#FF1493` | 深粉色 | 避免与黄色混淆 |

#### 3.3.3. 全色盲 / 高对比度模式 (Achromatopsia)

全色盲患者完全无法感知颜色，仅依赖亮度对比。此模式同时适用于需要极高对比度的玩家。

**核心原则**: 将所有颜色映射为不同亮度级别的灰度值，相邻元素的亮度对比度至少达到 **4.5:1**（WCAG AA 标准）。

| 颜色角色 | 原始色值 | 灰度亮度级别 | 用途 |
| :--- | :--- | :--- | :--- |
| 主要信息 (最亮) | 任意 | `#FFFFFF` (100%) | 当前激活的音符、危险警告 |
| 次要信息 (亮) | 任意 | `#CCCCCC` (80%) | 可用但非激活的元素 |
| 背景元素 (中) | 任意 | `#666666` (40%) | 界面背景、非激活状态 |
| 禁用/休止 (暗) | 任意 | `#333333` (20%) | 休止符、冷却中的法术 |
| 极度危险 (最亮+闪烁) | 任意 | `#FFFFFF` + 快速闪烁 | 危险警告（配合形状线索） |

在全色盲模式下，**音符符号体系**（见 3.2 节）是区分音符类型的唯一手段，因此该模式下符号显示强制开启且无法关闭。

### 3.4. 状态指示的多重线索设计

对于关键的状态变化，设计三重线索（颜色 + 形状/图标 + 文字/数字）：

| 状态 | 颜色线索 | 形状/图标线索 | 文字/数字线索 |
| :--- | :--- | :--- | :--- |
| **疲劳安全** | 绿色 → 蓝色(色盲) | 平滑正弦波形 | 数值 0-40% |
| **疲劳警告** | 黄色 → 橙色(色盲) | 波形开始不规则 | 数值 40-80% + "⚠" 图标 |
| **疲劳危险** | 红色 → 橙红色(色盲) | 方波 + 画面抖动 | 数值 80-100% + "⚠⚠" 图标 |
| **节拍完美** | 圣光金 → 橙红(色盲) | 八角星芒 ✴ 爆发 | "PERFECT" 文字 |
| **节拍良好** | 晶体白 | 空心圆环 ○ 扩散 | "GOOD" 文字 |
| **节拍错过** | 错误红 → 橙色(色盲) | 叉号 ✖ 出现 | "MISS" 文字 |

---

## 4. 低视觉闪烁模式设计

### 4.1. 光敏安全标准

本规范参照以下国际标准：

- **WCAG 2.1 成功标准 2.3.1**: 页面不包含任何在 1 秒内闪烁超过 3 次的内容，或闪烁低于通用闪烁和红色闪烁阈值。
- **ITU-R BT.1702**: 广播内容中的闪烁频率不得超过 3 Hz。
- **Harding FPA 标准**: 闪烁面积不得超过屏幕面积的 25%，且频率不超过 3 Hz。

### 4.2. 低闪烁模式的具体限制

#### 4.2.1. 全局闪烁频率限制

当低闪烁模式开启时，通过全局 `AccessibilityManager` 单例向所有相关着色器注入 `low_flash_mode` uniform 变量（值为 `true`），各着色器根据此变量调整行为：

| 特效类型 | 正常模式 | 低闪烁模式 |
| :--- | :--- | :--- |
| **Glitch 故障特效** (enemy_glitch.gdshader) | 随机高频跳变，可达 10-30 Hz | 限制为最高 **2 Hz**，位移量减少 50% |
| **节拍闪光** (rhythm_indicator.gd) | 每拍一次，BPM 120 时为 2 Hz | 保持，但将闪光持续时间从 0.05s 延长至 0.2s（平滑化） |
| **受伤白闪** (hit_feedback.gdshader) | 瞬间全屏白闪（<0.05s） | 替换为屏幕边缘 Vignette 发光，持续 0.3s |
| **疲劳脉冲** (fatigue_filter.gdshader) | 与节拍同步的高频脉动 | 改为每 2 秒一次的缓慢脉动 |
| **Boss 战闪电特效** | 随机高频闪烁 | 限制为最高 **2 Hz**，亮度降低 40% |
| **密度过载警告** | 全屏红色闪烁 | 替换为屏幕边缘持续的红色 Vignette，不闪烁 |

#### 4.2.2. 过渡平滑化

所有原本"瞬间切换"的视觉状态变化，在低闪烁模式下必须使用 Tween 进行平滑过渡：

| 过渡类型 | 正常模式时长 | 低闪烁模式时长 | 缓动函数 |
| :--- | :--- | :--- | :--- |
| 受伤反馈 | 0.05s (瞬闪) | 0.3s (渐变) | `ease_in_out` |
| 疲劳状态切换 | 瞬间 | 0.5s | `linear` |
| 相位切换全屏效果 | 0.1s | 0.5s | `ease_out` |
| 死亡/失败特效 | 瞬间 | 0.8s | `ease_in` |
| 菜单转场 Glitch | 0.2s | 0.4s | `ease_in_out` |

#### 4.2.3. 对比度降低

| 特效 | 正常模式最大亮度 | 低闪烁模式最大亮度 |
| :--- | :--- | :--- |
| 节拍完美冲击波 | 100% (Alpha 1.0) | 50% (Alpha 0.5) |
| 受伤白闪 | 100% (全白) | 30% (边缘 Vignette) |
| 圣光金高亮 | 100% | 60% |
| 故障特效 RGB 分离 | 最大 20px 偏移 | 最大 5px 偏移 |

### 4.3. 首次启动提示

游戏首次启动时，在主菜单出现之前，显示以下提示对话框：

```
┌─────────────────────────────────────────────────────┐
│                  ⚠ 光敏感警告                        │
│                                                     │
│  《Project Harmony》包含高频闪烁的视觉特效，         │
│  可能对光敏性癫痫患者造成风险。                       │
│                                                     │
│  建议患有光敏性癫痫或相关病史的玩家，                  │
│  开启"低视觉闪烁"模式。                              │
│                                                     │
│  [ 立即开启低闪烁模式 ]   [ 继续（不开启）]           │
└─────────────────────────────────────────────────────┘
```

此提示仅在首次启动时显示，玩家的选择将被保存。可在设置菜单的"可访问性"选项卡中随时修改。

---

## 5. 设置菜单 UI 布局

### 5.1. 菜单结构

在现有的设置菜单 (`settings_menu.gd`) 中，新增一个顶级的 **"可访问性 (Accessibility)"** 选项卡，位于现有选项卡的末尾：

```
[ 游戏 ]  [ 视频 ]  [ 音频 ]  [ 控制 ]  [ 可访问性 ]
```

### 5.2. 可访问性面板完整布局

```
┌─────────────────────────────────────────────────────────────────────┐
│  可访问性设置                                         [ 预览区域 ]   │
│  ─────────────────────────────────────────────────  ┌───────────┐  │
│                                                     │           │  │
│  视觉辅助                                           │  C  D  E  │  │
│  ─────────────────────────────────────────────────  │ ◉  ▲  ■  │  │
│                                                     │           │  │
│  色盲模式                                           │ ⚠ 疲劳警告 │  │
│  [ 关闭 ▼ ]                                         │           │  │
│    ○ 关闭                                           │ ✴ 完美节拍 │  │
│    ○ 红绿色盲 (Protanopia/Deuteranopia)             │           │  │
│    ○ 蓝黄色盲 (Tritanopia)                          └───────────┘  │
│    ○ 全色盲/高对比度 (Achromatopsia)                               │
│                                                                     │
│  附加视觉线索（形状/符号）                                           │
│  [●] 开启  [ ] 关闭                                                 │
│  在音符和状态元素上显示额外的形状符号                                 │
│                                                                     │
│  高对比度文本                                                        │
│  [●] 开启  [ ] 关闭                                                 │
│  为所有文本添加黑色描边，提高可读性                                   │
│                                                                     │
│  UI 元素缩放                                                         │
│  [━━━━━━━━━━━━●━━━━━━━━━━━━━━━━━━] 110%                            │
│  80%                              150%                              │
│                                                                     │
│  ─────────────────────────────────────────────────                  │
│                                                                     │
│  光敏感保护                                                          │
│  ─────────────────────────────────────────────────                  │
│                                                                     │
│  低视觉闪烁模式                                                      │
│  [●] 开启  [ ] 关闭                                                 │
│  限制闪烁频率 ≤ 3Hz，平滑特效过渡，保护光敏感玩家                     │
│                                                                     │
│  闪烁强度                                                            │
│  [━━━━━━━━━━━━━━━━━━━━━━━━●━━━━━━] 80%                             │
│  0% (完全关闭)                    100% (完整效果)                    │
│  （低视觉闪烁模式开启时，此项自动限制在 50% 以下）                    │
│                                                                     │
│  运动模糊                                                            │
│  [ ] 开启  [●] 关闭                                                 │
│  关闭运动模糊可减少视觉晕眩感                                         │
│                                                                     │
│  ─────────────────────────────────────────────────                  │
│                                                                     │
│  [ 恢复默认 ]                                    [ 应用并关闭 ]      │
└─────────────────────────────────────────────────────────────────────┘
```

### 5.3. 预览区域规范

预览区域（右侧小窗口）实时展示以下元素，随设置变化即时更新：

1. **三个音符示例**: C (◉)、D (▲)、E (■)，展示颜色和符号的变化效果。
2. **疲劳警告示例**: 展示危险状态下的颜色和图标线索。
3. **节拍判定示例**: 展示完美节拍的视觉反馈效果。

预览区域的背景使用游戏实际的星空紫 (`#141026`)，确保预览效果与游戏内一致。

### 5.4. 设置项的持久化

所有可访问性设置通过 `ConfigFile` 保存到用户数据目录（`user://accessibility_settings.cfg`），游戏启动时自动加载。设置变更立即生效，无需重启游戏。

---

## 6. 技术实现指南

### 6.1. AccessibilityManager 单例

新建 `godot_project/scripts/autoload/accessibility_manager.gd` 作为全局可访问性管理器：

```gdscript
# accessibility_manager.gd
extends Node

# 色盲模式枚举
enum ColorBlindMode {
    NONE,           # 关闭
    PROTANOPIA,     # 红绿色盲（红色弱）
    DEUTERANOPIA,   # 红绿色盲（绿色弱）
    TRITANOPIA,     # 蓝黄色盲
    ACHROMATOPSIA   # 全色盲/高对比度
}

# 当前设置
var color_blind_mode: ColorBlindMode = ColorBlindMode.NONE
var show_visual_cues: bool = false      # 附加视觉线索（形状/符号）
var low_flash_mode: bool = false        # 低视觉闪烁模式
var flash_intensity: float = 1.0       # 闪烁强度 (0.0 - 1.0)
var high_contrast_text: bool = false   # 高对比度文本
var ui_scale: float = 1.0              # UI 缩放

# 信号：设置变更时通知所有订阅者
signal accessibility_settings_changed

func apply_color_blind_mode(mode: ColorBlindMode) -> void:
    color_blind_mode = mode
    # 更新 UIColors 单例的颜色重载
    UIColors.apply_color_blind_palette(mode)
    # 通知所有 UI 元素更新
    emit_signal("accessibility_settings_changed")

func apply_low_flash_mode(enabled: bool) -> void:
    low_flash_mode = enabled
    # 向所有着色器注入 uniform
    # 如果低闪烁模式开启，限制闪烁强度上限
    if enabled:
        flash_intensity = min(flash_intensity, 0.5)
    emit_signal("accessibility_settings_changed")

func save_settings() -> void:
    var config = ConfigFile.new()
    config.set_value("accessibility", "color_blind_mode", color_blind_mode)
    config.set_value("accessibility", "show_visual_cues", show_visual_cues)
    config.set_value("accessibility", "low_flash_mode", low_flash_mode)
    config.set_value("accessibility", "flash_intensity", flash_intensity)
    config.set_value("accessibility", "high_contrast_text", high_contrast_text)
    config.set_value("accessibility", "ui_scale", ui_scale)
    config.save("user://accessibility_settings.cfg")

func load_settings() -> void:
    var config = ConfigFile.new()
    if config.load("user://accessibility_settings.cfg") == OK:
        color_blind_mode = config.get_value("accessibility", "color_blind_mode", ColorBlindMode.NONE)
        show_visual_cues = config.get_value("accessibility", "show_visual_cues", false)
        low_flash_mode = config.get_value("accessibility", "low_flash_mode", false)
        flash_intensity = config.get_value("accessibility", "flash_intensity", 1.0)
        high_contrast_text = config.get_value("accessibility", "high_contrast_text", false)
        ui_scale = config.get_value("accessibility", "ui_scale", 1.0)
    apply_color_blind_mode(color_blind_mode)
    apply_low_flash_mode(low_flash_mode)
```

### 6.2. UIColors 单例的色盲调色板扩展

在现有的 `godot_project/scripts/autoload/ui_colors.gd` 中，新增色盲调色板重载功能：

```gdscript
# 在 ui_colors.gd 中新增

# 当前激活的颜色集（默认为标准颜色）
var active_palette: Dictionary = {}

func apply_color_blind_palette(mode: int) -> void:
    match mode:
        AccessibilityManager.ColorBlindMode.PROTANOPIA:
            # 红绿色盲（红色弱）调色板
            active_palette = {
                "ERROR_RED": Color("#FF8C00"),       # 警戒橙替代错误红
                "NOTE_E_COLOR": Color("#00BFFF"),    # 天蓝替代翠叶绿
                "HEALING_GREEN": Color("#00CED1"),   # 暗青替代治愈绿
                "GLITCH_MAGENTA": Color("#FF6600"),  # 深橙替代故障洋红
            }
        AccessibilityManager.ColorBlindMode.TRITANOPIA:
            # 蓝黄色盲调色板
            active_palette = {
                "DOMINANT_YELLOW": Color("#FF4500"), # 橙红替代Dominant黄
                "HOLY_GOLD": Color("#FF6347"),       # 番茄红替代圣光金
                "RESONANCE_CYAN": Color("#00FF00"),  # 纯绿替代谐振青
                "CHORD_BLUE": Color("#FF69B4"),      # 热粉替代和弦蓝
            }
        AccessibilityManager.ColorBlindMode.ACHROMATOPSIA:
            # 全色盲/高对比度模式（灰度）
            active_palette = {
                # 所有颜色映射为灰度亮度级别
                "NOTE_C_COLOR": Color("#FFFFFF"),
                "NOTE_D_COLOR": Color("#CCCCCC"),
                "NOTE_E_COLOR": Color("#AAAAAA"),
                "NOTE_F_COLOR": Color("#888888"),
                "NOTE_G_COLOR": Color("#FFFFFF"),    # 最亮，配合✦符号
                "NOTE_A_COLOR": Color("#CCCCCC"),
                "NOTE_B_COLOR": Color("#AAAAAA"),
                "ERROR_RED": Color("#FFFFFF"),       # 最亮表示危险
            }
        _:
            # 恢复默认颜色
            active_palette = {}

# 获取颜色（优先返回色盲调色板中的替代色）
func get_color(color_name: String) -> Color:
    if color_name in active_palette:
        return active_palette[color_name]
    return get(color_name)  # 返回原始颜色常量
```

### 6.3. 音符符号渲染

在序列器状态环和弹药环的渲染脚本中，增加符号叠加逻辑：

```gdscript
# 音符符号映射
const NOTE_SYMBOLS = {
    "C": "◉", "D": "▲", "E": "■",
    "F": "◆", "G": "✦", "A": "⬡", "B": "▼"
}

func update_note_display(note: String, slot_node: Control) -> void:
    # 更新颜色
    slot_node.modulate = UIColors.get_color("NOTE_" + note + "_COLOR")
    
    # 如果开启了附加视觉线索，显示符号
    var symbol_label = slot_node.get_node_or_null("SymbolLabel")
    if symbol_label:
        symbol_label.visible = AccessibilityManager.show_visual_cues \
            or AccessibilityManager.color_blind_mode != AccessibilityManager.ColorBlindMode.NONE
        symbol_label.text = NOTE_SYMBOLS.get(note, "")
```

### 6.4. 低闪烁模式的着色器修改

在所有涉及闪烁的着色器中，增加 `low_flash_mode` uniform：

```glsl
// 在 enemy_glitch.gdshader 中添加
uniform bool low_flash_mode = false;
uniform float flash_intensity_multiplier = 1.0;

// 在闪烁计算部分
float glitch_freq = low_flash_mode ? 2.0 : 10.0;  // 低闪烁模式限制为 2Hz
float glitch = step(1.0 - corruption_level * 0.5,
    random(vec2(col, floor(TIME * glitch_freq))));

// 应用强度限制
float effective_intensity = low_flash_mode ? 
    min(glitch * 0.3, 0.3) :  // 低闪烁模式：最大 30% 强度
    glitch * flash_intensity_multiplier;
```

---

## 7. 测试与验证标准

### 7.1. 色盲模式测试清单

| 测试项目 | 验证方法 | 通过标准 |
| :--- | :--- | :--- |
| 红绿色盲模式下音符区分 | 使用 Coblis 色盲模拟器截图 | 所有 7 种音符在模拟视图中可明确区分 |
| 蓝黄色盲模式下方向区分 | 使用 Coblis 色盲模拟器截图 | 五度圈的三个方向在模拟视图中可明确区分 |
| 全色盲模式对比度 | 使用 Colour Contrast Analyser | 所有相邻元素的对比度 ≥ 4.5:1 |
| 符号线索可见性 | 在 1080p 分辨率下目视检查 | 所有符号在 60cm 观看距离下清晰可辨 |

### 7.2. 低闪烁模式测试清单

| 测试项目 | 验证方法 | 通过标准 |
| :--- | :--- | :--- |
| 闪烁频率 | 使用帧分析工具测量高对比度帧的频率 | 所有闪烁 ≤ 3 Hz |
| 受伤反馈平滑度 | 录制视频并逐帧分析 | 无瞬间全屏白闪（<0.1s 的高亮变化） |
| 过渡时长 | 代码审查 Tween 参数 | 所有过渡时长 ≥ 0.2s |
| 对比度降低 | 截图分析最亮帧的亮度 | 最亮帧的 Alpha ≤ 0.5 |

### 7.3. 设置菜单可用性测试

- 设置变更应在 **100ms 内**立即反映在预览区域。
- 所有设置项应有清晰的文字说明，字号不小于 14px。
- 设置保存后，重启游戏应正确恢复所有设置。

---

## 附录：参考资料

- WCAG 2.1 成功标准 2.3.1 (Three Flashes or Below Threshold): https://www.w3.org/WAI/WCAG21/Understanding/three-flashes-or-below-threshold.html
- WCAG 2.1 成功标准 1.4.1 (Use of Color): https://www.w3.org/WAI/WCAG21/Understanding/use-of-color.html
- Harding Flash and Pattern Analyzer (FPA): https://hardingfpa.co.uk/
- Coblis 色盲模拟器: https://www.color-blindness.com/coblis-color-blindness-simulator/
- 国际色盲协会 (Colour Blind Awareness): https://www.colourblindawareness.org/
