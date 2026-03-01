# Project Harmony: EventBus 事件总线架构设计

**项目:** Project Harmony (Godot 4.6)
**任务 ID:** tsk-c61b04fa-930
**评估日期:** 2026年3月1日
**作者:** Manus AI (architecture_refactor_engineer)
**状态:** 正式发布

---

## 1. 设计背景与目标

### 1.1. 问题陈述

通过对 `gdszyy/project-harmony-gdd` 仓库的静态代码分析，发现 Project Harmony 的核心 Autoload 系统存在严重的耦合问题。`GameManager` 在整个脚本库中被引用超过 **533次**（跨63个文件），是整个架构的中心枢纽，实际上已演变为一个"上帝对象"（God Object）。

以下是主要 Autoload 的引用统计（基于代码分析）：

| Autoload | 总引用次数 | 涉及文件数 | 耦合等级 |
| :--- | :---: | :---: | :---: |
| `UIColors` | 1463 | 55 | 高（但多为只读常量） |
| `GameManager` | 533 | 63 | **极高（双向依赖）** |
| `SpellcraftSystem` | 282 | 28 | **高（双向依赖）** |
| `FatigueManager` | 224 | 26 | **高（双向依赖）** |
| `SaveManager` | 86 | 19 | 中 |
| `ModeSystem` | 75 | 12 | 中 |
| `BGMManager` | 66 | 13 | 中 |
| `ChapterManager` | 63 | 19 | 中 |
| `NoteInventory` | 62 | 10 | 中 |
| `AudioManager` | 57 | 12 | 中 |

更关键的是，这些 Autoload 之间存在**双向依赖**（循环引用），例如：

- `GameManager` 直接调用 `FatigueManager.reset()` 和 `SpellcraftSystem.reset()`
- `FatigueManager` 反向调用 `GameManager.apply_dissonance_damage()`
- `SpellcraftSystem` 反向读取 `GameManager.game_time`, `GameManager.current_state` 等

这种紧耦合使得任何对核心系统的修改都可能产生不可预见的连锁反应，严重阻碍了项目的可维护性和可扩展性。

### 1.2. 设计目标

引入 **EventBus（事件总线）** 架构的核心目标是：

1.  **解耦 (Decoupling)**: 消除或减少 Autoload 单例之间的直接引用和方法调用，特别是 `GameManager` 与其他系统之间的双向依赖。
2.  **依赖倒置 (Dependency Inversion)**: 让高层模块（如 `GameManager`）和低层模块（如 `FatigueManager`）都依赖于抽象（事件），而不是相互依赖具体实现。
3.  **提升可扩展性 (Scalability)**: 使添加新的游戏系统或监听现有事件的逻辑变得更容易，而无需修改事件的发布者代码。
4.  **提高可测试性 (Testability)**: 独立的系统可以更容易地被隔离测试，只需模拟相应的输入事件即可。

---

## 2. EventBus 架构设计

### 2.1. 核心组件

我们将创建两个新的核心文件：

1.  **`EventBus.gd`**: 全局事件总线 Autoload，负责事件的注册、发布和订阅。
2.  **`Events.gd`**: 事件名称常量定义文件，提供类型安全的事件名称引用，避免拼写错误。

### 2.2. EventBus.gd 实现

`EventBus` 采用**动态信号注册**模式，无需预先声明所有信号，而是在首次订阅时动态创建。这使得系统具有高度的灵活性。

```gdscript
## EventBus.gd
## 全局事件总线 (Autoload)
## 用于解耦核心系统，取代直接的方法调用。
##
## 使用方法:
##   发布事件: EventBus.publish(Events.GAME_RESET)
##   订阅事件: EventBus.subscribe(Events.GAME_RESET, _on_game_reset)
##   取消订阅: EventBus.unsubscribe(Events.GAME_RESET, _on_game_reset)
extends Node

## 内部事件注册表：事件名称 -> 信号对象
var _registry: Dictionary = {}

## 发布一个事件，通知所有订阅者
## @param event_name: 事件的唯一名称，建议使用 Events 常量
## @param payload: 伴随事件发出的数据 (通常是 Dictionary)
func publish(event_name: String, payload: Variant = null) -> void:
    if not _registry.has(event_name):
        # 事件从未被订阅，静默忽略（不报错，避免初始化顺序问题）
        return
    _registry[event_name].emit(payload)

## 订阅一个事件
## @param event_name: 要订阅的事件名称
## @param callback: 事件触发时调用的函数 (Callable)
## 注意：回调函数的签名应为 func(payload: Variant) -> void
func subscribe(event_name: String, callback: Callable) -> void:
    if not _registry.has(event_name):
        # 首次订阅时，动态创建信号
        add_user_signal(event_name, [{"name": "payload", "type": TYPE_NIL}])
        _registry[event_name] = Signal(self, event_name)
    
    if not _registry[event_name].is_connected(callback):
        _registry[event_name].connect(callback)

## 取消订阅一个事件
## @param event_name: 要取消订阅的事件名称
## @param callback: 之前用于订阅的回调函数
func unsubscribe(event_name: String, callback: Callable) -> void:
    if _registry.has(event_name) and _registry[event_name].is_connected(callback):
        _registry[event_name].disconnect(callback)

## 检查某个事件是否有订阅者
func has_subscribers(event_name: String) -> bool:
    return _registry.has(event_name) and _registry[event_name].get_connections().size() > 0
```

### 2.3. Events.gd 事件名称常量

```gdscript
## Events.gd
## 全局事件名称常量定义
## 提供类型安全的事件名称，避免拼写错误
class_name Events

# ============================================================
# 游戏生命周期事件
# ============================================================
## 游戏重置到主菜单状态
const GAME_RESET: String = "game_reset"
## 新一局游戏开始
const GAME_STARTED: String = "game_started"
## 游戏暂停
const GAME_PAUSED: String = "game_paused"
## 游戏恢复
const GAME_RESUMED: String = "game_resumed"
## 游戏结束（玩家死亡或通关）
const GAME_OVER: String = "game_over"
## 进入升级选择界面
const UPGRADE_SELECT_ENTERED: String = "upgrade_select_entered"

# ============================================================
# 玩家状态事件
# ============================================================
## 玩家受到伤害
## payload: { "damage": float, "source_pos": Vector2 }
const PLAYER_DAMAGED: String = "player_damaged"
## 玩家死亡
## payload: null
const PLAYER_DIED: String = "player_died"
## 玩家血量变化
## payload: { "current_hp": float, "max_hp": float }
const PLAYER_HP_CHANGED: String = "player_hp_changed"
## 玩家升级
## payload: { "new_level": int }
const PLAYER_LEVEL_UP: String = "player_level_up"
## 玩家获得经验值
## payload: { "amount": int }
const XP_GAINED: String = "xp_gained"

# ============================================================
# 升级系统事件
# ============================================================
## 玩家选择了一个升级
## payload: { "upgrade": Dictionary }
const UPGRADE_SELECTED: String = "upgrade_selected"
## 玩家获得了一个章节词条
## payload: { "inscription": Dictionary }
const INSCRIPTION_ACQUIRED: String = "inscription_acquired"
## 音乐史彩蛋被触发
## payload: { "egg": Dictionary }
const EASTER_EGG_TRIGGERED: String = "easter_egg_triggered"

# ============================================================
# 节拍系统事件
# ============================================================
## 四分音符节拍触发
## payload: { "beat": int }
const BEAT_TICK: String = "beat_tick"
## 八分音符节拍触发
## payload: { "half_beat": int }
const HALF_BEAT_TICK: String = "half_beat_tick"
## 小节完成
## payload: { "measure": int }
const MEASURE_COMPLETED: String = "measure_completed"
## BPM 变更
## payload: { "new_bpm": float }
const BPM_CHANGED: String = "bpm_changed"

# ============================================================
# 战斗事件
# ============================================================
## 敌人被击杀
## payload: { "position": Vector2, "enemy_type": String }
const ENEMY_KILLED: String = "enemy_killed"
## 波次开始
## payload: { "wave_number": int, "wave_type": String }
const WAVE_STARTED: String = "wave_started"
## 波次完成
## payload: { "wave_number": int }
const WAVE_COMPLETED: String = "wave_completed"

# ============================================================
# 法术与音符事件
# ============================================================
## 不和谐度造成伤害
## payload: { "dissonance": float, "damage": float }
const DISSONANCE_APPLIED: String = "dissonance_applied"
## 和弦法术合成
## payload: { "chord_spell": Dictionary }
const CHORD_SPELL_CRAFTED: String = "chord_spell_crafted"
## 音符库存变化
## payload: { "note_key": int, "new_count": int }
const NOTE_INVENTORY_CHANGED: String = "note_inventory_changed"
```

### 2.4. 核心事件清单

下表汇总了所有核心事件，包括其数据结构和设计意图：

| 事件常量 | 事件名称 | Payload 数据结构 | 发布者 | 主要订阅者 |
| :--- | :--- | :--- | :--- | :--- |
| `Events.GAME_RESET` | `game_reset` | `null` | `GameManager` | `FatigueManager`, `SpellcraftSystem`, `NoteInventory`, `MusicTheoryEngine`, `ModeSystem`, `BGMManager` |
| `Events.GAME_STARTED` | `game_started` | `null` | `GameManager` | `BGMManager`, `FatigueManager`, `ModeSystem` |
| `Events.GAME_OVER` | `game_over` | `{ "reason": String }` | `GameManager` | `SaveManager`, `MetaProgressionManager` |
| `Events.PLAYER_DAMAGED` | `player_damaged` | `{ "damage": float, "source_pos": Vector2 }` | `GameManager` | `SignalBridge`, `AudioManager` |
| `Events.PLAYER_DIED` | `player_died` | `null` | `GameManager` | `SignalBridge`, UI 层 |
| `Events.PLAYER_LEVEL_UP` | `player_level_up` | `{ "new_level": int }` | `GameManager` | `NoteInventory`, UI 层 |
| `Events.UPGRADE_SELECTED` | `upgrade_selected` | `{ "upgrade": Dictionary }` | `GameManager` | `FatigueManager`, `SpellcraftSystem`, UI 层 |
| `Events.BEAT_TICK` | `beat_tick` | `{ "beat": int }` | `GameManager` | `SpellcraftSystem`, `BGMManager`, UI 层 |
| `Events.DISSONANCE_APPLIED` | `dissonance_applied` | `{ "dissonance": float, "damage": float }` | `FatigueManager` | `GameManager` |
| `Events.WAVE_COMPLETED` | `wave_completed` | `{ "wave_number": int }` | `EnemySpawner` | `ChapterManager`, UI 层 |

### 2.5. 与 SignalBridge 的关系

`SignalBridge` 和 `EventBus` 将在重构过渡期内**共存**，但职责明确分工：

**`SignalBridge`** 的定位是**场景内信号路由器**，它处理的是：
- 场景树中动态实例化节点（如 `EnemySpawner`, `CircleOfFifthsUpgrade`）的信号
- UI 节点与 Autoload 之间的信号连接
- 已有的、具体的 `Signal` 对象的连接管理

**`EventBus`** 的定位是**全局逻辑事件总线**，它处理的是：
- 核心 Autoload 之间的逻辑事件通信
- 跨系统的状态变更通知
- 取代 Autoload 之间的直接方法调用

**长期目标**: 随着重构的推进，`SignalBridge` 的职责将逐步收窄，最终仅保留处理场景节点信号的部分，而所有 Autoload 间的通信将全部通过 `EventBus` 进行。

---

## 3. 分阶段迁移计划

我们采用循序渐进的方式进行重构，以降低风险并确保每个阶段都可以独立验证。

### Phase 1: 解耦 `GameManager` 的重置与启动逻辑

**目标**: 将 `GameManager.reset_game()` 和 `start_game()` 中对其他系统的直接调用替换为发布事件。

**预期收益**: 移除 `GameManager` 对 `FatigueManager`, `SpellcraftSystem`, `NoteInventory`, `MusicTheoryEngine`, `ModeSystem`, `BGMManager` 的直接调用（约6个直接依赖）。

**风险等级**: 低（仅涉及重置逻辑，不影响游戏核心玩法）

**步骤**:
1.  在 `project.godot` 中注册 `EventBus.gd` 为 Autoload（在 `GameManager` 之前）。
2.  修改 `GameManager.reset_game()` 和 `start_game()`，发布相应事件。
3.  在各子系统的 `_ready()` 中订阅事件，替代被动等待 `GameManager` 调用。
4.  运行完整游戏测试，验证重置和启动流程正常。

### Phase 2: 迁移 `SaveManager` 和 `MetaProgressionManager`

**目标**: 将 `GameManager.game_over()` 中对 `SaveManager.save_game()` 的直接调用，以及 `MetaProgressionManager` 对 `GameManager` 的反向依赖迁移到 EventBus。

**预期收益**: 解耦游戏结算逻辑，使 `SaveManager` 和 `MetaProgressionManager` 能够独立响应 `game_over` 事件。

**风险等级**: 中（涉及游戏存档逻辑，需要仔细测试）

### Phase 3: 解耦 `SpellcraftSystem` 对 `GameManager` 的反向依赖

**目标**: 减少 `SpellcraftSystem` 中对 `GameManager.game_time`, `GameManager.current_state` 等属性的直接访问。

**方案**: 
- 创建一个轻量级的 `GameState.gd` Autoload，专门存储纯数据状态（`current_state`, `game_time`, `player_level` 等），与 `GameManager` 的行为逻辑分离。
- `SpellcraftSystem` 改为引用 `GameState` 而非 `GameManager`，减少对庞大 `GameManager` 的依赖。

**风险等级**: 中高（涉及核心法术系统，需要大量测试）

### Phase 4: 全面推广与规范化

**目标**: 建立团队规范，在新功能开发中优先使用 EventBus 模式。

**步骤**:
- 编写 EventBus 使用指南，纳入项目文档。
- 在代码审查中检查新引入的 Autoload 直接调用，要求使用 EventBus 替代。
- 定期审计 Autoload 依赖关系，防止耦合度回升。

---

## 4. Phase 1 完整示例代码

### 4.1. 新增文件：EventBus.gd

（见第 2.2 节）

### 4.2. 新增文件：Events.gd

（见第 2.3 节）

### 4.3. 修改文件：game_manager.gd

以下展示了 `reset_game()` 和 `start_game()` 的重构前后对比：

**重构前 (Before)**:
```gdscript
func reset_game() -> void:
    _reset_common_state()
    current_state = GameState.MENU
    # ... 其他状态重置 ...

    # 直接调用其他系统 — 强耦合
    if NoteInventory.has_method("reset"):
        NoteInventory.reset()
    if FatigueManager.has_method("reset"):
        FatigueManager.reset()
    if SpellcraftSystem.has_method("reset"):
        SpellcraftSystem.reset()
    if MusicTheoryEngine.has_method("clear_history"):
        MusicTheoryEngine.clear_history()
    if ModeSystem.has_method("reset"):
        ModeSystem.reset()
    if BGMManager.has_method("_reset_harmony_conductor"):
        BGMManager._reset_harmony_conductor()

    game_state_changed.emit(current_state)

func start_game() -> void:
    _reset_common_state()
    current_state = GameState.PLAYING
    session_kills = 0

    SaveManager.apply_meta_bonuses()
    player_current_hp = player_max_hp

    if ModeSystem.has_method("apply_mode"):
        ModeSystem.apply_mode(SaveManager.get_selected_mode())

    if BGMManager.has_method("start_bgm"):
        BGMManager.start_bgm(current_bpm)

    if FatigueManager.has_method("reset"):
        FatigueManager.reset()

    game_state_changed.emit(current_state)
```

**重构后 (After)**:
```gdscript
func reset_game() -> void:
    _reset_common_state()
    current_state = GameState.MENU
    # ... 其他状态重置 ...

    # 【Phase 1 重构】发布 game_reset 事件，由各系统自行响应
    # 不再需要知道哪些系统需要重置
    EventBus.publish(Events.GAME_RESET)

    game_state_changed.emit(current_state)

func start_game() -> void:
    _reset_common_state()
    current_state = GameState.PLAYING
    session_kills = 0

    # SaveManager 仍然需要在此处调用，因为它的返回值影响玩家HP
    # 这是 Phase 2 的重构目标
    SaveManager.apply_meta_bonuses()
    player_current_hp = player_max_hp

    # 【Phase 1 重构】发布 game_started 事件
    EventBus.publish(Events.GAME_STARTED, {
        "bpm": current_bpm,
        "mode": SaveManager.get_selected_mode()
    })

    game_state_changed.emit(current_state)
```

### 4.4. 修改文件：fatigue_manager.gd

```gdscript
## fatigue_manager.gd (Phase 1 修改)

func _ready() -> void:
    # 【Phase 1 重构】订阅 game_reset 事件
    EventBus.subscribe(Events.GAME_RESET, _on_game_reset)
    EventBus.subscribe(Events.GAME_STARTED, _on_game_started)

## 响应 game_reset 事件
func _on_game_reset(_payload: Variant = null) -> void:
    reset()

## 响应 game_started 事件
func _on_game_started(_payload: Variant = null) -> void:
    reset()

## 重置疲劳系统的所有状态
func reset() -> void:
    current_afi = 0.0
    last_event_timestamp = 0.0
    pitch_history.clear()
    rhythm_history.clear()
    chord_history.clear()
    # ... 其他重置逻辑 ...
    
    fatigue_updated.emit(_build_fatigue_result())
```

### 4.5. 修改文件：spellcraft_system.gd

```gdscript
## spellcraft_system.gd (Phase 1 修改)

func _ready() -> void:
    # 原有的信号连接保持不变
    GameManager.beat_tick.connect(_on_beat_tick)
    GameManager.half_beat_tick.connect(_on_half_beat_tick)
    GameManager.measure_complete.connect(_on_measure_complete)

    # 【Phase 1 重构】订阅 game_reset 事件
    EventBus.subscribe(Events.GAME_RESET, _on_game_reset)

## 响应 game_reset 事件
func _on_game_reset(_payload: Variant = null) -> void:
    reset()

## 重置系统状态
func reset() -> void:
    active_spells.clear()
    spell_queue.clear()
    active_modifiers.clear()
    # ... 其他重置逻辑 ...
```

### 4.6. 修改文件：note_inventory.gd

```gdscript
## note_inventory.gd (Phase 1 修改)

func _ready() -> void:
    # 【Phase 1 重构】订阅 game_reset 事件
    EventBus.subscribe(Events.GAME_RESET, _on_game_reset)

func _on_game_reset(_payload: Variant = null) -> void:
    reset()

func reset() -> void:
    _inventory.clear()
    _init_inventory()
    inventory_changed.emit(-1, 0)
```

### 4.7. 修改文件：mode_system.gd

```gdscript
## mode_system.gd (Phase 1 修改)

func _ready() -> void:
    # 【Phase 1 重构】订阅 game_started 事件（包含 mode 信息）
    EventBus.subscribe(Events.GAME_STARTED, _on_game_started)
    EventBus.subscribe(Events.GAME_RESET, _on_game_reset)

func _on_game_started(payload: Variant) -> void:
    if payload and payload.has("mode"):
        apply_mode(payload["mode"])

func _on_game_reset(_payload: Variant = null) -> void:
    reset()
```

### 4.8. 修改文件：bgm_manager.gd

```gdscript
## bgm_manager.gd (Phase 1 修改)

func _ready() -> void:
    # 【Phase 1 重构】订阅 game_started 事件（包含 bpm 信息）
    EventBus.subscribe(Events.GAME_STARTED, _on_game_started)
    EventBus.subscribe(Events.GAME_RESET, _on_game_reset)

func _on_game_started(payload: Variant) -> void:
    var bpm: float = 120.0
    if payload and payload.has("bpm"):
        bpm = payload["bpm"]
    start_bgm(bpm)

func _on_game_reset(_payload: Variant = null) -> void:
    _reset_harmony_conductor()
```

---

## 5. 验收标准

Phase 1 重构完成后，应满足以下验收标准：

1.  **功能正确性**: 游戏的重置（返回主菜单）和启动（开始新一局）流程完全正常，无任何功能回归。
2.  **依赖减少**: `GameManager.reset_game()` 中不再包含对 `FatigueManager`, `SpellcraftSystem`, `NoteInventory`, `MusicTheoryEngine`, `ModeSystem`, `BGMManager` 的直接引用。
3.  **代码可读性**: 重构后的 `GameManager` 代码更简洁，职责更单一。
4.  **无新 Bug**: 通过完整的游戏测试（至少完成一局完整游戏），确认无新引入的 Bug。

---

## 6. 附录：project.godot 注册顺序

在 `project.godot` 中，`EventBus` 必须在所有其他需要使用它的 Autoload 之前注册，以确保初始化顺序正确：

```ini
[autoload]
; 基础工具类（无依赖）
UIColors="*res://scripts/autoload/ui_colors.gd"
Events="*res://scripts/autoload/events.gd"

; 【新增】事件总线（必须在其他系统之前注册）
EventBus="*res://scripts/autoload/event_bus.gd"

; 核心系统（依赖 EventBus）
GameManager="*res://scripts/autoload/game_manager.gd"
FatigueManager="*res://scripts/autoload/fatigue_manager.gd"
SaveManager="*res://scripts/autoload/save_manager.gd"
; ... 其他系统 ...

; 信号桥接器（最后注册，依赖所有系统）
SignalBridge="*res://scripts/autoload/signal_bridge.gd"
```
