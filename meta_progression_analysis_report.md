# Project Harmony 局外升级系统实装分析报告

**作者：** Manus AI  
**日期：** 2026年2月10日

---

## 1. 结论概要

局外升级系统（"和谐殿堂"）**已经实装**，但存在**双轨并行、数据不一致、部分加成未落地**三个关键问题。具体来说：

1. **代码已写好，框架已搭建**：`MetaProgressionManager`（803行）、`SaveManager`（461行）、`hall_of_harmony.gd`（882行）、`run_results_screen.gd`（225行）等核心文件均已完成编写，并在 `project.godot` 中注册为 Autoload。
2. **核心循环已打通**：主菜单 → 和谐殿堂 → 开始游戏 → 局结算 → 碎片奖励 → 和谐殿堂 的完整流程已连接。
3. **但存在严重的"双轨"问题**：`SaveManager` 和 `MetaProgressionManager` 两个单例**各自独立维护了一套局外升级的数据定义和逻辑**，且两者的配置参数不一致。游戏主逻辑实际调用的是 `SaveManager`，而 UI 界面（`hall_of_harmony.gd`）又使用了**第三套**自定义数据。
4. **部分加成"只写不读"**：拾音范围、节拍判定窗口等加成虽然被 `SaveManager` 计算并提供了接口，但在游戏实体（`player.gd`、`rhythm_indicator.gd`）中**从未被读取和应用**。

---

## 2. 架构分析：三套并行的数据定义

这是目前最严重的结构性问题。局外升级的数据定义在三个不同的文件中各有一套，且**互不兼容**。

### 2.1 三套数据对比

| 维度 | `MetaProgressionManager` | `SaveManager` | `hall_of_harmony.gd` (UI) |
| :--- | :--- | :--- | :--- |
| **文件** | `meta_progression_manager.gd` | `save_manager.gd` | `hall_of_harmony.gd` |
| **角色** | 设计文档的代码化实现 | 实际被游戏主逻辑调用 | UI 显示与交互 |
| **模块 A 升级项** | 5项（舞台定力、基础声压、节拍敏锐度、拾音范围、起拍速度） | 5项（同名但数值不同） | 5项（**完全不同的 ID 和名称**：音量增幅、节拍加速、共鸣扩展、生命和弦、布鲁斯之魂） |
| **模块 B 技能** | 7项（黑键修饰符+和弦解锁+传说乐章） | 7项（类似但 ID 不同） | 7项（**完全不同**：和弦精通、节奏感知、谐波护盾、回响精通、休止蓄力、转调大师、绝对音感） |
| **模块 C 调式** | 4种（伊奥尼亚、多利亚、五声音阶、布鲁斯） | 4种（同） | **7种**（伊奥尼亚、多利亚、弗里几亚、利底亚、混合利底亚、爱奥利亚、洛克里亚） |
| **模块 D 升级项** | 4项（听觉耐受、混响消除、绝对音感、休止符美学） | 4项（同名但数值不同） | 4项（**不同 ID**：听感耐受、恢复速率、静默抗性、密度容忍） |
| **HP 加成/级** | +10 HP | +10 HP | +10 HP（一致） |
| **伤害加成/级** | +2% | +2% | +8%（**不一致**） |
| **存档路径** | `user://meta_progression.cfg` | `user://save_game.cfg` | 无（依赖 Manager） |

### 2.2 数据流向分析

```
游戏启动时：
  GameManager.start_game()
    → SaveManager.apply_meta_bonuses()     ← 实际生效的是 SaveManager 的数据
    → ModeSystem.apply_mode(SaveManager.get_selected_mode())

局结算时：
  GameManager.game_over()
    → SaveManager.save_game()
    → GameManager._award_resonance_fragments()
      → SaveManager.add_resonance_fragments()   ← 碎片存入 SaveManager

结算 UI：
  run_results_screen.gd
    → MetaProgressionManager.on_run_completed()  ← 碎片又存入 MetaProgressionManager

和谐殿堂 UI：
  hall_of_harmony.gd
    → MetaProgressionManager.get_upgrade_levels()  ← 读取 MetaProgressionManager
    → MetaProgressionManager.purchase_upgrade()    ← 购买写入 MetaProgressionManager
```

**问题**：碎片被**同时**存入 `SaveManager` 和 `MetaProgressionManager` 两个不同的存档文件，购买升级时只修改了 `MetaProgressionManager` 的数据，但游戏开始时读取的是 `SaveManager` 的数据。这意味着**玩家在和谐殿堂中购买的升级，在下一局游戏中不会生效**。

---

## 3. 各模块实装状态详细分析

### 3.1 模块 A：乐器调优（基础属性成长）

| 升级项 | 接口已定义 | 加成已计算 | 加成已应用到游戏实体 | 实际生效 |
| :--- | :--- | :--- | :--- | :--- |
| 舞台定力（+HP） | ✅ | ✅ | ✅ `GameManager.player_max_hp` | ✅ **生效** |
| 基础声压（+伤害%） | ✅ | ✅ | ✅ `SpellcraftSystem` 读取 | ✅ **生效** |
| 节拍敏锐度（+判定窗口） | ✅ | ✅ | ❌ `rhythm_indicator.gd` 未读取 | ❌ **未生效** |
| 拾音范围（+吸附范围） | ✅ | ✅ | ❌ `player.gd` 未读取 | ❌ **未生效** |
| 起拍速度（+弹速%） | ✅ | ✅ | ✅ `SpellcraftSystem` 读取 | ✅ **生效** |

**小结**：5项中有3项实际生效，2项（节拍敏锐度、拾音范围）处于"接口已就绪但末端未接入"的状态。

### 3.2 模块 B：乐理研习（复杂性解锁）

| 解锁项 | 接口已定义 | 前置检查已实现 | 游戏逻辑已集成 | 实际生效 |
| :--- | :--- | :--- | :--- | :--- |
| D# 追踪修饰符 | ✅ | ✅ | ✅ `SpellcraftSystem` 检查 `SaveManager.is_modifier_available()` | ✅ **生效** |
| G# 回响修饰符 | ✅ | ✅ | ✅ 同上 | ✅ **生效** |
| A# 散射修饰符 | ✅ | ✅ | ✅ 同上 | ✅ **生效** |
| 减三/增三和弦 | ✅ | ✅ | ✅ `SpellcraftSystem` 检查 `SaveManager.is_chord_type_available()` | ✅ **生效** |
| 七和弦解析 | ✅ | ✅ | ✅ 同上 | ✅ **生效** |
| 传说乐章许可 | ✅ | ✅ | ⚠️ 概率提升逻辑未明确实现 | ⚠️ **部分生效** |

**小结**：乐理研习模块是实装最完整的部分，`SaveManager` 提供的 `is_modifier_available()` 和 `is_chord_type_available()` 接口已被 `SpellcraftSystem` 正确调用。

### 3.3 模块 C：调式风格（职业/流派系统）

| 功能 | 实装状态 | 说明 |
| :--- | :--- | :--- |
| 调式选择与存档 | ✅ 已实现 | `SaveManager.get_selected_mode()` / `set_selected_mode()` |
| 调式解锁与购买 | ✅ 已实现 | `SaveManager.unlock_mode()` |
| 调式应用到游戏 | ✅ 已实现 | `ModeSystem.apply_mode()` 限制可用音符、设置伤害倍率、被动效果 |
| 布鲁斯暴击被动 | ✅ 已实现 | `ModeSystem.on_dissonance_applied()` + `check_crit()` |
| 多利亚回响被动 | ✅ 已实现 | `ModeSystem.on_spell_cast()` 每3次施法附加回响 |

**小结**：调式系统是实装最完善的模块，从选择到应用到被动效果均已完整实现。但 UI 中定义了7种调式，而后端只支持4种。

### 3.4 模块 D：声学降噪（疲劳系统缓解）

| 升级项 | 接口已定义 | 加成已计算 | 加成已应用到 FatigueManager | 实际生效 |
| :--- | :--- | :--- | :--- | :--- |
| 听觉耐受（-单调值） | ✅ | ✅ | ✅ `FatigueManager._monotony_resistance` | ✅ **生效** |
| 混响消除（+密度恢复） | ✅ | ✅ | ✅ `FatigueManager._density_resistance` | ✅ **生效** |
| 绝对音感（-不和谐伤害） | ✅ | ✅ | ✅ `GameManager.apply_dissonance_damage()` 读取 | ✅ **生效** |
| 休止符美学（+清除效率） | ✅ | ✅ | ❌ `FatigueManager` 未读取此加成 | ❌ **未生效** |

**小结**：4项中有3项实际生效，休止符美学的加成虽然被 `MetaProgressionManager` 写入了 `GameManager.set_meta()`，但 `FatigueManager` 中没有读取该 meta 数据的代码。

### 3.5 共鸣碎片经济

| 功能 | 实装状态 | 说明 |
| :--- | :--- | :--- |
| 碎片获取（局结算） | ✅ 已实现 | `GameManager._award_resonance_fragments()` → `SaveManager.add_resonance_fragments()` |
| 碎片消耗（购买升级） | ⚠️ 双轨 | `hall_of_harmony.gd` 调用 `MetaProgressionManager.purchase_upgrade()`，但碎片存在 `SaveManager` |
| 碎片显示（结算界面） | ⚠️ 双轨 | `run_results_screen.gd` 调用 `MetaProgressionManager.on_run_completed()` 计算碎片 |
| 碎片持久化 | ⚠️ 双轨 | 两个存档文件各存一份 |

---

## 4. 问题总结与修复建议

### 4.1 高优先级问题

| # | 问题 | 影响 | 建议修复方案 |
| :--- | :--- | :--- | :--- |
| **P0** | SaveManager 与 MetaProgressionManager 双轨并行，数据不同步 | 玩家购买的升级不会在游戏中生效 | **统一为单一数据源**。建议保留 `MetaProgressionManager` 作为唯一的局外数据管理器，将 `SaveManager` 中的局外升级逻辑全部删除，`GameManager.start_game()` 改为调用 `MetaProgressionManager.apply_meta_bonuses()` |
| **P0** | `hall_of_harmony.gd` 的升级数据与后端完全不一致 | UI 显示的升级内容与实际效果不匹配 | 将 `hall_of_harmony.gd` 中的硬编码数据（TUNING_UPGRADES、THEORY_SKILLS 等）替换为从 `MetaProgressionManager` 的常量中动态读取 |
| **P1** | 拾音范围加成未被 `player.gd` 读取 | 升级了拾音范围但无效果 | 在 `player.gd` 的 `_ready()` 中读取 `SaveManager.get_pickup_range_bonus()` 并调整 `_pickup_area` 的碰撞形状半径 |
| **P1** | 节拍判定窗口加成未被 `rhythm_indicator.gd` 读取 | 升级了节拍敏锐度但无效果 | 在 `rhythm_indicator.gd` 的 `_ready()` 中读取 `SaveManager.get_timing_window_bonus()` 并叠加到 `perfect_window` |
| **P1** | 休止符美学加成未被 `FatigueManager` 读取 | 升级了休止符美学但无效果 | 在 `FatigueManager` 的休止符处理逻辑中读取 `GameManager.get_meta("meta_rest_efficiency_bonus")` |

### 4.2 中优先级问题

| # | 问题 | 建议 |
| :--- | :--- | :--- |
| **P2** | UI 定义了7种调式，后端只支持4种 | 要么在后端补全弗里几亚、利底亚、混合利底亚、爱奥利亚、洛克里亚的逻辑，要么在 UI 中暂时隐藏未实现的调式 |
| **P2** | 碎片奖励计算逻辑在 `GameManager._award_resonance_fragments()` 和 `MetaProgressionManager.on_run_completed()` 中各有一套，公式不同 | 统一为一套计算逻辑 |
| **P2** | `MetaProgressionManager.apply_meta_bonuses()` 通过 `GameManager.set_meta()` 存储加成，但下游系统未统一读取 | 建议改为直接修改对应系统的变量，而非使用 meta 数据 |

---

## 5. 总结

局外升级系统的**设计文档非常完整**，**代码框架已全部搭建**，**核心流程已打通**。但由于开发过程中出现了 `SaveManager` 和 `MetaProgressionManager` 两套并行实现，导致了数据不一致的严重问题。加之 `hall_of_harmony.gd` 的 UI 层又使用了第三套数据定义，使得"玩家在 UI 中看到的升级"、"玩家购买的升级"和"游戏中实际生效的升级"三者之间存在脱节。

**核心修复工作量估计**：统一数据源（约2-3小时）+ 接入未生效的加成（约1-2小时）+ UI 数据对齐（约2-3小时），总计约 **5-8小时** 的开发工作即可将局外升级系统完全实装。

从积极的角度看，所有必要的接口和逻辑都已经存在，问题主要在于"连接"而非"创建"。这是一个典型的集成问题，而非设计或实现缺失。
