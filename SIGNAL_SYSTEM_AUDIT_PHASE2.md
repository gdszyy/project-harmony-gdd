# Project Harmony - 信号系统深度审计报告 (Phase 2)

**审计日期:** 2026-03-01
**作者:** Manus AI (signal_system_auditor)
**审计范围:** `project-harmony-gdd/godot_project/scripts/` 目录下的所有 `.gd` 文件
**核心焦点:** Event Bus (`SignalBridge`) 完整性、防御性编程质量及信号链路健康度

## 1. 审计概述与对比

本次审计在上次 `SIGNAL_AUDIT_REPORT.md` 的基础上进行了更深度的静态分析。我们不仅关注信号的连接状态，更深入分析了参数匹配、循环依赖风险以及 `SignalBridge` 的实现质量。

### 1.1 信号状态对比

与上次审计相比，信号系统的规模有所扩大，但未连接信号的比例有所回升。

| 类别 | 上次审计 | 本次审计 | 变化 | 状态说明 |
| :--- | :--- | :--- | :--- | :--- |
| **总文件数** | - | 203 | - | 扫描的 `.gd` 文件总数 |
| **总信号数** | ~170 | 281 | +111 | 项目中定义的唯一信号总数 |
| **完全连接** | ~125 | 116 | -9 | 既有定义、触发，又有连接监听的健康信号 |
| **仅触发未连接** | ~45 | 130 | +85 | **需重点关注**：被触发但没有任何系统监听的信号 |
| **连接但未定义** | - | 35 | 新增指标 | 监听了不存在的信号或内置引擎信号 |
| **仅定义未使用** | ~20 | 0 | -20 | 代码库清理效果显著 |

> **分析结论**：虽然上次审计大幅降低了未连接信号的比例，但随着新功能（如 Boss 系统、UI 序列、局外成长）的开发，产生了大量新的“触发但未连接”的信号。同时，我们发现了 35 个“连接但未定义”的信号，其中大部分是 Godot 内置信号（如 `pressed`, `timeout`, `area_entered`），属于正常现象。

## 2. SignalBridge 健康度评估

`SignalBridge` 作为核心事件桥接器，其稳定性和效率对整个游戏至关重要。

### 2.1 防御性编程质量

`SignalBridge` 在防御性编程方面表现良好，但在实现细节上存在优化空间。

- **`has_signal()` 检查**: 29 次
- **`is_connected()` 检查**: 27 次
- **总连接操作**: 26 次
- **防御覆盖率**: 27/26 (极佳)

### 2.2 发现的设计与实现问题

1. **空回调函数泛滥**：
   在 26 个连接中，有 12 个回调函数体完全为空（仅有 `pass` 或注释）。
   *示例*: `_on_player_died`, `_on_wave_completed`, `_on_boss_health_changed` 等。
   *影响*: 这些信号被成功桥接，但并未产生任何实际的全局效果，造成了“虚假的安全感”和微小的性能损耗。

2. **过度依赖低效查找**：
   `_find_node_in_tree()` 方法使用了递归遍历整个场景树，且被调用了 4 次。
   *建议*: 对于 Autoload 节点（如 `ChapterManager`）应直接访问；对于场景节点（如 `EnemySpawner`）应通过 `Group` 查找或让节点主动注册到 `SignalBridge`。

3. **名称硬编码不一致**：
   `project.godot` 中注册的 Autoload 名为 `BGMManager`，但 `SignalBridge` 中使用 `has_node("/root/BGMManager")` 进行路径硬编码检查。

## 3. 核心信号链路分析

我们对影响游戏核心循环的关键信号进行了链路完整性检查：

| 信号名称 | 状态 | 所属系统 | 影响评估 |
| :--- | :--- | :--- | :--- |
| `player_damaged` / `player_died` | ✅ 已连接 | 玩家状态 | 正常，音效与统计链路完整 |
| `upgrade_selected` / `inscription_acquired` | ✅ 已连接 | 成长系统 | 正常，UI与音效链路完整 |
| `wave_completed` / `chapter_completed` | ✅ 已连接 | 章节进度 | 正常，核心流程链路完整 |
| `boss_spawned` | ❌ 未连接 | Boss系统 | **高风险**：Boss生成后可能无法触发UI血条或特定逻辑 |
| `boss_vulnerability_started` / `ended` | ❌ 未连接 | Boss系统 | **高风险**：Boss虚弱机制可能无法提供视觉反馈或伤害加成 |
| `enemy_damaged` | ❌ 未连接 | 战斗系统 | **中风险**：可能导致伤害数字不显示或受击特效丢失 |

## 4. 严重问题详细列表

深度分析揭示了几个可能导致运行时错误或逻辑死锁的严重问题：

### 4.1 信号名称不匹配 (The `boss_triggered` Bug)
在 `scripts/scenes/main_game.gd` 的第 490-492 行，尝试连接 `_chapter_manager.boss_triggered`。然而，在 `ChapterManager` 中定义的实际信号是 `boss_wave_triggered`。
* **后果**: `main_game` 永远无法收到 Boss 触发的通知，可能导致 Boss 战特有逻辑（如封锁区域、切换 BGM）失效。

### 4.2 信号参数不匹配 (共 27 处)
我们发现了多个信号在 `emit` 时的参数数量与 `signal` 定义时不一致，这在 Godot 4 中会导致运行时报错或参数截断。

* **`milestone_reached`**: 
  * 定义 (`codex_manager.gd:22`): 3个参数 `(entry_id, milestone, current_kills)`
  * 触发 (`timed_milestone_manager.gd:199`): 2个参数 `(milestone_index, boss_key)`
  * *分析*: 两个不同系统使用了同名信号，但参数签名不同，若有全局监听者会导致崩溃。

* **`upgrade_selected`**:
  * 定义 (`game_manager.gd:19`): 1个参数 `(upgrade: Dictionary)`
  * 触发 (`hall_of_harmony.gd:456`): 2个参数 `(nid: String, cat: String)`
  * *分析*: UI 层的升级选择信号签名与全局 `GameManager` 不兼容。

### 4.3 潜在循环依赖风险
在 `SignalBridge` 中，`_on_upgrade_chosen_v3` 回调函数内部调用了 `GameManager.upgrade_selected.emit(upgrade)`。
* **风险**: 如果 `GameManager` 的监听者中包含触发 `upgrade_chosen` 的源头，可能形成无限循环。虽然目前尚未造成死锁，但这种“在信号处理函数中发射同类信号”的模式（Signal Chaining）是架构上的坏味道。

## 5. 未连接信号分类统计

针对 130 个触发但未连接的信号，我们进行了分类归因：

- **UI 交互 (23 个)**: 包含大量 `hovered`, `pressed`, `tooltip_shown` 等，多为 UI 组件的内部状态广播，若无外部需求可保持原样。
- **Boss 机制 (17 个)**: 包含 `arena_phase_changed`, `boss_summon_minions` 等。这是近期新增系统，**亟需补充监听逻辑**。
- **战斗细节 (10 个)**: 包含 `projectile_hit_enemy`, `summon_attacked` 等。
- **局外成长 (8 个)**: 包含 `upgrade_purchased`, `breakthrough_acknowledged` 等。

## 6. 新型 EventBus 架构评估

我们注意到项目中引入了 `scripts/autoload/event_bus.gd`（Phase 1 实现），旨在取代直接的信号连接。

- **现状**: 该脚本已包含完整的 `publish`/`subscribe` 机制，并在 `bgm_manager`, `fatigue_manager`, `game_manager` 等核心系统中开始使用。
- **冲突**: 目前项目处于 `SignalBridge` (基于原生信号桥接) 和 `EventBus` (基于字符串主题的发布订阅) 两种模式并存的过渡期。这增加了系统的复杂度和认知负担。

## 7. 修复建议与优先级

基于上述发现，我们提出以下分级修复建议：

### 🔴 优先级 P0 (立即修复，可能导致崩溃或阻断流程)
1. **修复信号名称不匹配**: 将 `main_game.gd` 中的 `boss_triggered` 更改为正确的 `boss_wave_triggered`。
2. **修复参数不匹配**: 统一 `upgrade_selected` 和 `milestone_reached` 的参数签名。建议通过重命名局部信号（如将 UI 的改为 `ui_upgrade_selected`）来消除歧义。

### 🟠 优先级 P1 (核心功能完善)
1. **清理 SignalBridge 空回调**: 移除 `SignalBridge` 中无实际逻辑的 `_on_xxx` 函数及对应的 `connect` 调用，减少无意义的事件派发。
2. **连接 Boss 核心信号**: 在 `SignalBridge` 中补充对 `boss_spawned` 和 Boss 阶段转换信号的实际处理逻辑。

### 🟡 优先级 P2 (架构与性能优化)
1. **优化节点查找**: 将 `SignalBridge` 中的 `_find_node_in_tree` 替换为 `get_tree().get_nodes_in_group("xxx")` 模式。
2. **统一事件架构**: 团队需要决定是继续使用 `SignalBridge` 还是全面迁移至新的 `EventBus` 模式，并在 `DOCUMENTATION_GUIDELINES.md` 中确立唯一标准，避免双轨制。
