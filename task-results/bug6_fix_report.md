# Bug-6 修复报告：Systems 及 Scenes 脚本独立编译错误

## 概述

本次修复共涉及 **12 个文件**，修复了 GDScript 编译错误，包括：空代码块、变量重复声明、类型推断失败、内置关键字冲突等问题。所有修改均不改变业务逻辑。

## 修复详情

### 1. `godot_project/scripts/systems/character_class_manager.gd`

**问题**：第 22 行 `signal class_applied` 的参数名 `class_name` 与 GDScript 内置关键字冲突。

**修复**：将参数名 `class_name` 重命名为 `applied_class_name`。

```gdscript
# 修复前
signal class_applied(class_id: String, class_name: String)

# 修复后
signal class_applied(class_id: String, applied_class_name: String)
```

---

### 2. `godot_project/scripts/systems/enemy_spawner.gd`

**问题**：第 1204 行 `if _pool_manager:` 后面没有任何代码块，形成空 if 块。

**修复**：添加 `pass` 语句。

```gdscript
# 修复前
if _pool_manager:
else:
    push_warning(...)

# 修复后
if _pool_manager:
    pass
else:
    push_warning(...)
```

---

### 3. `godot_project/scripts/systems/pool_manager.gd`

**问题**：第 140、150 行 `pool_name` 变量使用 `:=` 推断类型，但 GDScript 无法从字符串拼接推断类型。

**修复**：添加显式类型注解 `String`。

```gdscript
# 修复前
var pool_name := "enemy_" + type_name

# 修复后
var pool_name: String = "enemy_" + type_name
```

---

### 4. `godot_project/scripts/systems/projectile_manager.gd`

**问题 1**：第 125 行在 `spawn_from_spell` 函数中引用了未声明的 `player_pos`，该函数使用外部传入的 `origin` 参数。

**修复**：将 `player_pos` 替换为 `origin`（函数参数）。

**问题 2**：第 1109-1507 行多处类型推断失败（`dist`、`pull_dir`、`pull_strength`、`push_dir`、`progress`、`dist_ratio`、`actual_slow`、`remaining`、`remaining2`）。

**修复**：为所有相关变量添加显式类型注解（`float` 或 `Vector2`）。

---

### 5. `godot_project/scripts/systems/spell_visual_manager.gd`

**问题**：第 1155 行 `_vfx_slow_field` 函数中声明了 `var color`，与外层作用域的 `_vfx_finale` 函数中的 `color` 变量重复声明。

**修复**：将 `_vfx_slow_field` 函数内的 `color` 重命名为 `slow_color`，并更新所有引用。

---

### 6. `godot_project/scripts/systems/vfx_manager.gd`

**问题**：第 311 行 `tween.tween_callback(func():` 后的 lambda 体只有注释，没有可执行语句，形成空代码块。

**修复**：添加 `pass` 语句。

---

### 7. `godot_project/scripts/ui/damage_number.gd`

**问题**：第 264 行 `var ripple_progress := clamp(...)` 使用 `:=` 推断，`clamp` 返回 Variant 类型，产生警告。

**修复**：添加显式类型注解 `float`。

---

### 8. `godot_project/scripts/ui/status_notification.gd`

**问题**：第 116-117 行 `bw` 和 `bh` 变量类型推断失败（`abs(sin(...))` 返回 Variant）。

**修复**：添加显式类型注解 `float`。

---

### 9. `godot_project/scripts/scenes/main_game.gd`

**问题**：
- 第 585 行 `_on_timbre_changed(timbre)` 参数无类型注解。
- 第 587 行 `var timbre_info := SpellcraftSystem.get_timbre_info(timbre)` 类型推断失败。
- 第 1004、1051、1111 行 `var timbre := SpellcraftSystem.get_current_timbre()` 类型推断失败。

**修复**：添加显式类型注解（`int` 和 `Dictionary`）。

---

### 10. `godot_project/scripts/scenes/main_menu.gd`

**问题**：第 333 行 `var settings_menu := settings_scene.instantiate()` 类型推断失败（`instantiate()` 返回 Variant）。

**修复**：添加显式类型注解 `Node`。

---

### 11. `godot_project/scripts/scenes/test_chamber.gd`

**问题**：
- 第 503 行 `_on_timbre_changed(timbre)` 参数无类型注解。
- 第 504 行 `var timbre_info := SpellcraftSystem.get_timbre_info(timbre)` 类型推断失败。
- 第 524、573、636 行 `var timbre := SpellcraftSystem.get_current_timbre()` 类型推断失败。

**修复**：添加显式类型注解（`int` 和 `Dictionary`）。

---

### 12. `godot_project/scripts/tests/performance_benchmark.gd`

**问题**：
- 第 341、466 行 `var enemy := _pool_manager.acquire_enemy(...)` 类型推断失败（返回 Variant）。
- 第 483 行 `var one_percent_count := max(...)` 类型推断失败（`max` 返回 Variant）。

**修复**：添加显式类型注解（`Node` 和 `int`）。

---

## 修复原则

1. **不改变业务逻辑**：所有修改仅为语法层面，不影响运行时行为。
2. **空代码块加 pass**：对空 if 块和空 lambda 块添加 `pass`。
3. **显式类型注解**：对类型推断失败的变量添加明确的类型声明。
4. **关键字冲突重命名**：将与内置关键字冲突的参数名改为语义清晰的替代名称。
5. **变量重复声明改名**：将作用域内重复声明的变量重命名以消除歧义。

## 提交分支

`bugfix/bug-6-systems-scripts`
