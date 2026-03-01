# Project Harmony 事件系统架构规范

**版本:** 1.0
**日期:** 2026-03-01
**状态:** 强制执行 (基于 ADR-002)

本指南规定了 Project Harmony 中事件与信号的正确使用方式，旨在消除架构双轨制，防止循环依赖，并提升代码的长期可维护性。

## 1. 核心原则：何时使用什么？

项目中的事件通信被严格划分为两个层级，必须遵守以下边界：

### 1.1 使用 EventBus (全局事件总线)
**适用场景**：跨系统、跨 Autoload、以及核心 UI 与逻辑系统之间的通信。
**规则**：
*   **必须**用于 Autoload 之间的状态变更通知（如 `GameManager` 通知 `BGMManager` 游戏开始）。
*   **必须**用于解耦高层逻辑（如将 `SaveManager` 的存档触发与 `GameManager` 的结算逻辑分离）。
*   **禁止**在 Autoload 中使用原生的 `signal` 关键字定义新的全局信号（历史遗留信号将逐步迁移）。

### 1.2 使用原生 Signal (场景内局部信号)
**适用场景**：场景树内部、父子节点之间、以及组件内部的通信。
**规则**：
*   **必须**用于 UI 组件的内部交互（如 `button.pressed`）。
*   **必须**用于实体内部的状态传递（如 `Enemy` 的 `health_changed` 信号发给自身的 `HealthBar`）。
*   **必须**遵循“向下调用方法，向上发送信号”的 Godot 最佳实践。
*   **禁止**将局部节点的原生信号直接暴露给全局 Autoload 监听（应通过 `SignalBridge` 适配，或最好由该节点主动调用 `EventBus.publish`）。

---

## 2. EventBus 使用规范

### 2.1 事件定义
所有全局事件**必须**在 `scripts/autoload/events.gd` 中定义为常量。

```gdscript
# ❌ 错误做法：使用硬编码字符串
EventBus.publish("player_level_up", {"level": 2})

# ✅ 正确做法：使用 Events 常量
EventBus.publish(Events.PLAYER_LEVEL_UP, {"level": 2})
```

### 2.2 Payload 数据结构规范
*   Payload 必须是一个 `Dictionary`，或者为 `null`（如果仅需通知事件发生）。
*   在 `events.gd` 中定义常量时，**必须**在注释中明确注明 Payload 的结构。

```gdscript
## 玩家受到伤害
## payload: { "damage": float, "source_pos": Vector2 }
const PLAYER_DAMAGED: String = "player_damaged"
```

### 2.3 订阅与取消订阅
*   在 `_ready()` 中订阅事件。
*   如果订阅者是一个会被销毁的节点（非 Autoload），**必须**在 `_exit_tree()` 或 `_notification(NOTIFICATION_PREDELETE)` 中取消订阅，防止内存泄漏。

```gdscript
func _ready() -> void:
    EventBus.subscribe(Events.GAME_STARTED, _on_game_started)

func _exit_tree() -> void:
    EventBus.unsubscribe(Events.GAME_STARTED, _on_game_started)
```

---

## 3. 防御性编程要求

为了防止信号链（Signal Chaining）导致的无限循环或重复触发（如 Issue #86 中的 `upgrade_chosen` 缺陷），必须遵守以下防御性编程规范：

### 3.1 避免在回调中触发同类事件
**禁止**在一个事件的回调函数中，直接或间接地再次触发该事件。

```gdscript
# ❌ 错误做法：极易导致无限循环
func _on_upgrade_selected(upgrade: Dictionary) -> void:
    # ... 处理逻辑 ...
    GameManager.upgrade_selected.emit(upgrade) # 绝对禁止！
```

### 3.2 使用防重入标志 (Reentrancy Guards)
对于可能被高频触发或存在复杂调用链的核心事件（如伤害计算、升级应用），**必须**使用布尔标志防止同一帧内的重入。

```gdscript
var _is_processing_damage: bool = false

func _on_player_damaged(payload: Variant) -> void:
    if _is_processing_damage:
        push_warning("检测到伤害事件重入，已拦截！")
        return
        
    _is_processing_damage = true
    # ... 执行伤害逻辑 ...
    _is_processing_damage = false
```

### 3.3 原生信号的防御性连接 (适用于过渡期的 SignalBridge)
在动态连接原生信号时，必须进行双重检查：
1.  检查对象是否存在且包含该信号 (`has_signal`)。
2.  检查是否已经连接 (`is_connected`)，防止重复连接导致回调执行多次。

```gdscript
if target_node and target_node.has_signal("some_signal"):
    if not target_node.some_signal.is_connected(_on_some_signal):
        target_node.some_signal.connect(_on_some_signal)
```

---

## 4. 命名规范

*   **事件常量**：全大写，下划线分隔，如 `PLAYER_DAMAGED`。
*   **信号名称**：全小写，下划线分隔，动词过去式或状态描述，如 `health_changed`, `enemy_killed`。
*   **回调函数**：必须以 `_on_` 开头，后接事件或信号名称。
    *   对于 EventBus：`_on_game_started(payload: Variant)`
    *   对于原生信号：`_on_button_pressed()`

## 5. 附录：SignalBridge 弃用计划
根据 ADR-002，`SignalBridge` 已被标记为**过渡性组件**。
*   **禁止**向 `SignalBridge` 添加新的 Autoload 之间的逻辑桥接。
*   现有的 `SignalBridge` 逻辑将在后续重构中逐步迁移至 `EventBus`。
