# Project Harmony - 信号系统审计报告 (Issue #86)

**最后更新时间:** 2026-02-12
**作者:** Manus AI

## 1. 审计概述

本次审计旨在全面分析 `project-harmony-gdd` 代码库中的信号系统，解决大量已触发（`emit`）但未被监听（`connect`）的信号问题。通过本次审计，我们希望达成以下目标：

-   **提升代码可维护性：** 明确信号的流向，减少因信号未连接导致的逻辑中断和调试困难。
-   **增强系统稳定性：** 确保核心游戏事件（如战斗、升级、资源管理）的信号被正确处理，避免功能缺失。
-   **清理代码库：** 识别并移除不再需要的废弃信号，或添加 `DEPRECATED` 注释以供参考。

审计工作主要分为三个阶段：

1.  **全面分析：** 使用自动化脚本扫描所有 `.gd` 文件，提取信号的定义、触发和连接位置，生成完整的状态报告。
2.  **核心连接：** 基于分析报告，优先连接对游戏逻辑至关重要的核心事件信号。
3.  **清理与归档：** 对确认不再需要的信号进行标记或移除，并生成最终的审计报告。

## 2. 信号状态分析

通过对 `scripts/` 目录下的所有 `.gd` 文件进行静态分析，我们得到了以下统计数据：

| 类别                 | 数量 (审计前) | 数量 (审计后) | 变化   |
| -------------------- | ------------- | ------------- | ------ |
| **总信号定义**       | ~170          | ~170          | 0      |
| **已连接信号**       | ~85           | ~125          | +40    |
| **仅触发未连接信号** | ~85           | ~45           | -40    |
| **仅定义未使用信号** | ~20           | ~20           | 0      |

审计前，约 **50%** 的信号处于“触发但未连接”的状态，这表明许多游戏事件的逻辑链条存在中断。审计后，通过引入 `SignalBridge` Autoload 单例和在特定场景中补充连接，我们将这一比例降低至约 **26%**。剩余的未连接信号大多为内部诊断、UI 交互或已被标记为 `DEPRECATED` 的旧功能信号，对核心玩法影响较小。

## 3. 核心事件信号连接实现

为了集中管理和修复未连接的信号，我们引入了一个新的 Autoload 单例：`SignalBridge` (`scripts/autoload/signal_bridge.gd`)。该脚本在游戏启动时自动加载，并负责连接分散在各个系统中的核心信号。

以下是主要修复的信号类别及其连接策略：

### 3.1 战斗事件 (Combat Events)

-   `GameManager.player_damaged`: 连接到 `SignalBridge` 中的 `_on_player_damaged`，用于触发全局受击音效。
-   `GameManager.player_died`: 连接到 `SignalBridge` 中的 `_on_player_died`，用于记录会话结束日志。
-   `enemy_damaged` / `enemy_died`: 这些信号在 `enemy_base.gd` 中定义，并通过 `AudioManager.register_enemy()` 方法在敌人生成时动态连接，无需在 `SignalBridge` 中重复处理。

### 3.2 升级事件 (Upgrade Events)

-   `GameManager.upgrade_selected`: 连接到 `SignalBridge`，用于触发升级确认音效和记录日志。
-   `GameManager.inscription_acquired`: 连接到 `SignalBridge`，用于记录词条获取日志。
-   `GameManager.easter_egg_triggered`: 连接到 `SignalBridge`，用于记录音乐史彩蛋触发日志。

### 3.3 资源事件 (Resource Events)

-   `NoteInventory.insufficient_notes`: 连接到 `SignalBridge`，用于在音符不足时播放警告音效。
-   `NoteInventory.chord_spell_crafted`: 连接到 `SignalBridge`，用于在和弦合成成功时播放音效。

### 3.4 章节与波次事件 (Chapter & Wave Events)

-   `EnemySpawner.wave_completed` / `wave_started`: 在 `SignalBridge` 中通过查找场景树中的 `EnemySpawner` 实例进行连接，用于更新 HUD 和记录日志。
-   `ChapterManager.bpm_changed`: 连接到 `SignalBridge`，用于同步 `GameManager` 中的全局 BPM。
-   `ChapterManager` 的其他信号（如 `wave_started_in_chapter`, `elite_wave_triggered`）也已连接到 `SignalBridge` 用于日志记录。

### 3.5 音频与音乐事件 (Audio & Music Events)

-   `BgmManager` 的 `intensity_changed`, `layer_toggled`, `tonality_changed` 等信号被连接，为未来实现更丰富的声画同步效果提供了接口。
-   `MusicTheoryEngine.progression_triggered` 和 `ModeSystem.transpose_changed` 被连接，用于记录核心音乐系统的状态变化。

### 3.6 局外成长事件 (Meta Progression Events)

-   `MetaProgressionManager` 的 `mode_unlocked`, `mode_selected`, `theory_unlocked` 等信号被连接，用于在控制台输出调试信息，方便追踪玩家的局外解锁进度。
-   `SaveManager.resonance_changed` 也被连接以追踪共鸣碎片的变化。

## 4. 废弃信号处理

对于确认不再使用或功能已被重构的信号，我们采取了以下两种处理方式：

1.  **归档目录文件：** `scripts/ui/archive/` 目录下的所有 `.gd` 文件均为旧版 UI 的残留。我们为这些文件的头部添加了 `DEPRECATED` 注释，明确指出其已不再使用。

2.  **行内注释：** 对于一些仍在代码库中但已无实际消费者的信号，我们在其定义上方添加了 `DEPRECATED` 注释，并简要说明了其状态。这包括：
    -   对象池（`ObjectPool`）的内部诊断信号（`pool_exhausted`, `pool_expanded`）。
    -   视觉特效管理器（`VFXManager`）的生命周期信号（`vfx_finished`）。
    -   合成器（`SynthManager`）和音频队列（`AudioEventQueue`）的内部状态信号。

## 5. 结论与后续建议

本次信号系统审计显著改善了项目的代码健康状况。通过引入 `SignalBridge` 并系统性地连接核心事件，我们修复了许多潜在的逻辑中断问题，并为未来的功能迭代打下了更坚实的基础。

**后续建议：**

-   **推广 `SignalBridge` 模式：** 未来新增的全局性信号连接应优先考虑在 `SignalBridge` 中实现，以保持信号管理的集中性。
-   **定期审计：** 建议在大型重构或新功能模块完成后，定期运行信号分析脚本，检查是否存在新的未连接信号。
-   **移除已注释的废弃代码：** 对于已添加 `DEPRECATED` 注释超过一个开发周期的代码，可以考虑在确认无任何依赖后彻底移除，以进一步减小代码库体积。
