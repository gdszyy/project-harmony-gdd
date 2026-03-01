# ADR 002: 统一全局事件系统与消除双轨制

**日期:** 2026-03-01
**状态:** 已接受
**作者:** Manus AI (software_architect)
**上下文:** Project Harmony (Godot 4.6) 信号系统重构

## 1. 背景 (Context)

在 `project-harmony-gdd` 项目中，目前同时存在两套处理全局事件的机制（双轨制）：

1. **`SignalBridge` (原生信号桥接)**: 早期引入的单例，用于集中连接项目中已触发但未被监听的信号。它依赖于 Godot 原生的 `Signal` 机制，通过硬编码的路径或 `_find_node_in_tree` 查找节点并进行连接。
2. **`EventBus` (发布订阅模式)**: 在 Phase 1 架构重构中引入的单例，采用基于字符串主题的发布/订阅模式（Publish/Subscribe）。目前已在 `GameManager`、`FatigueManager`、`BGMManager` 等核心系统中使用。

这种双轨制带来了以下问题：
* **认知负担增加**：开发者不清楚何时该用 `SignalBridge`，何时该用 `EventBus`。
* **职责重叠与冲突**：两套系统都在处理全局级别的事件路由。
* **循环依赖风险**：`SignalBridge` 中的原生信号桥接（如 `_on_upgrade_chosen_v3` 桥接到 `GameManager.upgrade_selected`）导致了隐式的信号链（Signal Chaining），不仅触发了双重执行（如音效播放两次），还存在潜在的无限循环死锁风险。
* **性能损耗**：`SignalBridge` 包含大量空回调函数，并且在场景树中使用低效的递归查找节点。

## 2. 决策 (Decision)

我们决定**全面采用 `EventBus` 作为全局唯一的事件总线系统，并逐步弃用 `SignalBridge` 的全局桥接职责**。

具体决策如下：

1. **确立 `EventBus` 的核心地位**：所有跨系统、跨层级（特别是 Autoload 之间，以及核心 UI 与 Autoload 之间）的事件通信，必须通过 `EventBus.publish()` 和 `EventBus.subscribe()` 进行。
2. **重新定义 `SignalBridge` 职责（过渡期）**：在彻底移除前，`SignalBridge` 将被降级为仅处理**场景内特定动态节点**（如 `EnemySpawner`）的信号适配器，不再处理 Autoload 之间的逻辑桥接。
3. **切断危险的信号链**：立即移除 `SignalBridge` 中会导致循环或重复触发的桥接代码（如 `upgrade_chosen` 桥接）。
4. **统一事件字典**：所有全局事件名称必须在 `Events.gd` 中定义为常量，确保类型安全。

## 3. 理由 (Rationale)

* **彻底解耦**：`EventBus` 的发布订阅模式不需要订阅者知道发布者的存在，也不需要发布者存在于场景树中。这消除了 `SignalBridge` 中 `_find_node_in_tree` 的低效操作和对节点加载顺序的依赖。
* **避免循环依赖**：原生信号链（A emit -> B connect -> B emit C）极易隐藏循环依赖。`EventBus` 的单向流动使得事件流向更加清晰。
* **可扩展性**：在 `EventBus` 中添加新的监听者只需一行 `subscribe`，不需要像 `SignalBridge` 那样编写额外的样板回调函数（`_on_xxx`）。
* **清理历史债务**：`SignalBridge` 目前包含 12 个完全为空的回调函数，这是一种“虚假的安全感”。迁移到 `EventBus` 能够自然地清理这些无用代码。

## 4. 后果 (Consequences)

### 4.1 积极后果 (Positive)
* **架构清晰**：消除了双轨制，团队拥有了统一的事件处理标准。
* **性能提升**：移除了 `SignalBridge` 中的递归节点查找和无效的空回调。
* **稳定性增强**：修复了 `upgrade_chosen` 导致的双重音效播放问题，消除了潜在的循环依赖死锁。

### 4.2 消极后果/风险 (Negative/Risks)
* **重构工作量**：需要将现有 `SignalBridge` 中的有效连接逐步迁移到各个具体系统的 `_ready` 函数中进行 `EventBus` 订阅。
* **调试难度**：与原生信号相比，基于字符串的 `EventBus` 在 Godot 编辑器的“节点信号”面板中不可见，需要依赖代码搜索（或我们提供的 `EventBus.get_debug_info()`）进行调试。

## 5. 迁移计划 (Migration Plan)

由于不能在单个任务中完成所有迁移，我们制定了以下分步计划：

**第一阶段（本任务）**：
1. 修复 `SignalBridge` 中的循环依赖风险（断开 `upgrade_chosen` 的桥接）。
2. 编写 `EVENT_SYSTEM_GUIDELINES.md` 规范文档。

**第二阶段（后续任务）**：
1. 迁移战斗事件（`player_damaged`, `player_died`）至 `EventBus`，并由 `AudioManager` 直接订阅。
2. 迁移资源与章节事件至 `EventBus`。
3. 彻底删除 `signal_bridge.gd`，从 `project.godot` 中移除该 Autoload。
