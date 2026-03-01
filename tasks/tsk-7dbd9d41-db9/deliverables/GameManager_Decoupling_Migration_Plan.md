# GameManager 解耦迁移计划

**任务 ID:** tsk-7dbd9d41-db9
**参考:** EventBus_Architecture_Design.md (tsk-c61b04fa-930)
**日期:** 2026年3月1日

---

## 1. 当前状态

### 1.1. GameManager 引用统计（465次引用，63个文件）

| 使用类型 | 引用次数 | 说明 |
| :--- | :---: | :--- |
| 属性读取 | 171 | `game_time`, `current_bpm`, `is_test_mode`, `player_level` 等 |
| 信号连接 | 82 | `beat_tick.connect()`, `enemy_killed.connect()` 等 |
| `has_method`/`has_signal` 检查 | 46 | 防御性编程模式 |
| 方法调用 | 36 | `reset_game()`, `damage_player()`, `apply_dissonance_damage()` 等 |
| 信号发射 | 10 | 来自 `SignalBridge` 和 `main_game.gd` |

### 1.2. Phase 1 已完成的解耦

**已消除的直接依赖（9个调用）：**

```
reset_game() → EventBus.publish(Events.GAME_RESET)
  - NoteInventory.reset()        → NoteInventory 自行订阅
  - FatigueManager.reset()       → FatigueManager 自行订阅
  - SpellcraftSystem.reset()     → SpellcraftSystem 自行订阅
  - MusicTheoryEngine.clear()    → MusicTheoryEngine 自行订阅
  - ModeSystem.reset()           → ModeSystem 自行订阅
  - BGMManager._reset_harmony()  → BGMManager 自行订阅

start_game() → EventBus.publish(Events.GAME_STARTED, {bpm, mode})
  - ModeSystem.apply_mode()      → ModeSystem 自行订阅
  - BGMManager.start_bgm()       → BGMManager 自行订阅
  - FatigueManager.reset()       → FatigueManager 自行订阅
```

---

## 2. Phase 2: 解耦游戏结算逻辑

### 2.1. 目标

将 `GameManager.game_over()` 中对 `SaveManager.save_game()` 的直接调用迁移到 EventBus。

### 2.2. 当前代码

```gdscript
func game_over() -> void:
    current_state = GameState.GAME_OVER
    SaveManager.save_game()  # ← 直接调用
    game_state_changed.emit(current_state)
```

### 2.3. 重构方案

```gdscript
# game_manager.gd
func game_over() -> void:
    current_state = GameState.GAME_OVER
    EventBus.publish(Events.GAME_OVER, {"reason": "player_died"})
    game_state_changed.emit(current_state)

# save_manager.gd
func _ready() -> void:
    EventBus.subscribe(Events.GAME_OVER, _on_game_over)

func _on_game_over(payload: Variant) -> void:
    save_game()
```

### 2.4. 风险评估

- **风险等级:** 中
- **关注点:** `SaveManager.save_game()` 的调用时序必须在 `game_state_changed.emit()` 之前完成
- **测试重点:** 确认游戏结束后存档数据完整性

---

## 3. Phase 3: 解耦 SpellcraftSystem 反向依赖

### 3.1. 目标

减少 `SpellcraftSystem` 中对 `GameManager` 属性的 21 次直接访问。

### 3.2. 当前耦合点

```
SpellcraftSystem 读取:
  - GameManager.game_time (11次)
  - GameManager.current_state (3次)
  - GameManager.current_bpm (2次)
  - GameManager.is_test_mode (2次)
  - GameManager.extended_chords_unlocked (3次)
```

### 3.3. 重构方案：提取 GameState.gd

创建轻量级的 `GameState.gd` Autoload，专门存储纯数据状态：

```gdscript
## game_state.gd (新增 Autoload)
## 纯数据状态存储，与 GameManager 的行为逻辑分离
extends Node

var game_time: float = 0.0
var current_bpm: float = 120.0
var current_state: int = 0  # GameManager.GameState
var player_level: int = 1
var is_test_mode: bool = false
var extended_chords_unlocked: bool = false
```

`GameManager._process()` 中同步更新 `GameState`，其他系统改为引用 `GameState`。

### 3.4. 风险评估

- **风险等级:** 中高
- **关注点:** `game_time` 的实时性要求，需确保每帧同步
- **测试重点:** 法术系统的时间相关逻辑（节拍同步、冷却计时）

---

## 4. Phase 3b: 解耦 FatigueManager 反向依赖

### 4.1. 目标

消除 `FatigueManager` → `GameManager.apply_dissonance_damage()` 的反向调用。

### 4.2. 重构方案

```gdscript
# fatigue_manager.gd (修改)
# 替换: GameManager.apply_dissonance_damage(effective_dissonance)
# 改为: EventBus.publish(Events.DISSONANCE_APPLIED, {...})
EventBus.publish(Events.DISSONANCE_APPLIED, {
    "dissonance": effective_dissonance,
    "damage": base_damage
})

# game_manager.gd (新增订阅)
func _ready() -> void:
    EventBus.subscribe(Events.DISSONANCE_APPLIED, _on_dissonance_applied)

func _on_dissonance_applied(payload: Variant) -> void:
    if payload:
        apply_dissonance_damage(payload["dissonance"])
```

---

## 5. Phase 4: 全面推广与规范化

### 5.1. 编码规范

1. **新功能开发**：优先使用 EventBus 模式进行跨系统通信
2. **代码审查**：检查新引入的 Autoload 直接调用，要求使用 EventBus 替代
3. **定期审计**：每月审计 Autoload 依赖关系，防止耦合度回升

### 5.2. 信号迁移优先级

| 信号 | 当前连接数 | 迁移优先级 | 说明 |
| :--- | :---: | :---: | :--- |
| `beat_tick` | 28 | 低 | 高频信号，EventBus 的 Dictionary payload 可能有性能开销 |
| `enemy_killed` | 15 | 中 | 可迁移，但需确保所有消费者都更新 |
| `player_died` | 6 | 高 | 低频，适合 EventBus |
| `player_hp_changed` | 5 | 中 | UI 更新相关 |
| `game_state_changed` | 5 | 高 | 核心状态变更，适合 EventBus |
| `upgrade_selected` | 3 | 高 | 已有 SignalBridge 桥接 |

### 5.3. 长期目标

- **短期（Phase 1-2）:** 消除 `GameManager` 的 "God Object" 特征，移除所有直接方法调用
- **中期（Phase 3）:** 提取 `GameState.gd`，减少属性读取耦合
- **长期（Phase 4）:** 所有 Autoload 间通信通过 EventBus，`SignalBridge` 仅保留场景节点信号路由

---

## 6. 预期收益总结

| 指标 | Phase 1 前 | Phase 1 后 | 全部完成后（预估） |
| :--- | :---: | :---: | :---: |
| `GameManager` 直接调用次数 | 36 | 27 | < 10 |
| `reset_game()` 中的直接依赖 | 6 | 0 | 0 |
| `start_game()` 中的直接依赖 | 3 | 0 | 0 |
| `game_over()` 中的直接依赖 | 1 | 1 | 0 |
| 双向依赖对数 | 3 | 2 | 0 |
| EventBus 事件数 | 0 | 30+ | 30+ |
