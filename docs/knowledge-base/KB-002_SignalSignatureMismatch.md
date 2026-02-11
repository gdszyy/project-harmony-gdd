# KB-002: 统一 Godot 信号参数的最佳实践

**问题编号:** KB-002  
**创建日期:** 2026-02-12  
**作者:** Manus AI Agent

---

## 1. 问题背景

在 Godot 项目中，信号（Signal）是节点间解耦通信的核心机制。当信号的声明（`emit` 端）与回调函数的签名（`connect` 端）不匹配时，会在运行时产生错误。

在开发过程中，遇到以下运行时错误：

```
E 0:00:23:114   enemy_base.gd:437 @ _die(): Error calling from signal 'enemy_killed' to callable: 'Node2D(test_chamber.gd)::_on_enemy_killed_vfx': Method expected 3 argument(s), but called with 1.
```

错误发生在 `enemy_base.gd` 的 `_die` 函数中，`enemy_killed` 信号发射时只带了 1 个参数，但 `test_chamber.gd` 中的回调函数 `_on_enemy_killed_vfx` 期望接收 3 个参数。

## 2. 根因分析

- **信号声明:** `GameManager` 中的 `enemy_killed` 信号被声明为 `signal enemy_killed(enemy_position: Vector2)`，只包含 1 个参数。
- **信号发射:** `enemy_base.gd` 中调用 `GameManager.enemy_killed.emit(global_position)`，正确地传递了 1 个参数。
- **信号连接:** `test_chamber.gd` 中的回调函数 `_on_enemy_killed_vfx` 的签名是 `func _on_enemy_killed_vfx(pos: Vector2, _xp: int, enemy_type: String)`，期望 3 个参数。

由于参数数量不匹配，导致信号调用失败。此外，项目中其他连接到 `enemy_killed` 信号的回调函数也存在不同的参数签名，缺乏统一标准。

## 3. 解决方案

为了解决这个问题，需要建立一个统一的信号签名作为“单一事实来源”，并同步更新所有发射端和连接端。

### 3.1. 核心修复

1.  **确定统一签名:** 决定将 `enemy_killed` 信号的签名统一为 `(enemy_position: Vector2, enemy_type: String)`，这能满足大部分回调函数的需求。

2.  **修改信号声明:** 在 `game_manager.gd` 中更新信号声明。
    ```gdscript
    # In game_manager.gd
    signal enemy_killed(enemy_position: Vector2, enemy_type: String)
    ```

3.  **修改所有发射端:** 在 `enemy_base.gd`, `boss_base.gd`, `elite_base.gd` 中，修改 `emit` 调用，增加 `enemy_type` 参数。
    ```gdscript
    # In enemy_base.gd
    var type_name := _get_type_name()
    GameManager.enemy_killed.emit(global_position, type_name)
    ```

4.  **修改所有连接端:** 统一所有回调函数的签名为 `(pos: Vector2, enemy_type: String)`。对于不需要 `enemy_type` 的回调，可以将其声明为 `_enemy_type` 以避免 Godot 的未使用变量警告。

    ```gdscript
    # In test_chamber.gd
    func _on_enemy_killed_vfx(pos: Vector2, enemy_type: String = "static") -> void:
        # ...

    # In codex_manager.gd
    func _on_enemy_killed(enemy_position: Vector2, enemy_type: String = "static") -> void:
        record_kill(enemy_type)
    ```

### 3.2. 最佳实践

- **全局信号中心:** 将全局信号（如 `enemy_killed`）集中在 Autoload 单例（如 `GameManager`）中声明，使其成为全局事件总线。
- **明确参数:** 信号参数应尽可能明确和自包含，避免回调函数需要通过其他方式获取额外信息。
- **版本控制:** 当修改信号签名时，应在提交信息中明确指出，并通知所有依赖该信号的团队成员。

## 4. 关键文件依赖

- `godot_project/scripts/autoload/game_manager.gd` (信号声明中心)
- `godot_project/scripts/entities/enemy_base.gd` (主要发射端)
- `godot_project/scripts/scenes/test_chamber.gd` (主要连接端)
- `godot_project/scripts/autoload/codex_manager.gd` (其他连接端)
- `godot_project/scripts/systems/damage_number_manager.gd` (其他连接端)
