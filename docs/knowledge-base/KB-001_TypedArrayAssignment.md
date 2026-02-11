# KB-001: 修复 Godot 4 强类型数组赋值错误

**问题编号:** KB-001  
**创建日期:** 2026-02-12  
**作者:** Manus AI Agent

---

## 1. 问题背景

在 Godot 4.x 中，GDScript 引入了强类型数组（Typed Arrays），例如 `Array[Dictionary]`。这增强了代码的健壮性和可读性，但也带来了更严格的类型检查。

在开发过程中，遇到以下运行时错误：

```
E 0:00:45:948   activate_chapter_timbre: Trying to assign an array of type "Array" to a variable of type "Array[Dictionary]".
  <GDScript 源文件>game_manager.gd:471 @ activate_chapter_timbre()
```

错误发生在 `game_manager.gd` 的 `activate_chapter_timbre` 函数中，试图将一个 `Array` 类型的返回值赋给一个声明为 `Array[Dictionary]` 的变量。

## 2. 根因分析

- **赋值端:** `game_manager.gd` 的 `current_chapter_inscription_pool` 变量被声明为 `var current_chapter_inscription_pool: Array[Dictionary] = []`。
- **返回端:** `ChapterData.get_chapter_inscriptions()` 函数的返回类型被声明为 `-> Array`。

尽管 `get_chapter_inscriptions` 实际上返回的是一个包含字典的数组，但由于其签名是 `Array`，Godot 的类型系统视其为一个通用数组，因此在赋值给强类型的 `Array[Dictionary]` 时会因类型不匹配而报错。

## 3. 解决方案

为了解决这个问题，需要确保函数返回的类型与变量声明的类型完全匹配。

### 3.1. 核心修复

修改 `chapter_data.gd` 中 `get_chapter_inscriptions` 函数的签名和实现，使其显式返回 `Array[Dictionary]`。

**修复前:**
```gdscript
# In chapter_data.gd
static func get_chapter_inscriptions(chapter: int) -> Array:
    return CHAPTER_INSCRIPTIONS.get(chapter, [])
```

**修复后:**
```gdscript
# In chapter_data.gd
static func get_chapter_inscriptions(chapter: int) -> Array[Dictionary]:
    var raw: Array = CHAPTER_INSCRIPTIONS.get(chapter, [])
    var result: Array[Dictionary] = []
    for item in raw:
        result.append(item)
    return result
```

### 3.2. 讨论

虽然直接修改返回类型签名 `-> Array[Dictionary]` 也能在某些情况下工作，但通过创建一个新的 `Array[Dictionary]` 并逐项复制，可以提供最强的类型安全保证，避免因 `CHAPTER_INSCRIPTIONS` 数据源内部结构变化而引发的潜在问题。

## 4. 关键文件依赖

- `godot_project/scripts/autoload/game_manager.gd` (信号消费者)
- `godot_project/scripts/data/chapter_data.gd` (数据源提供者)
