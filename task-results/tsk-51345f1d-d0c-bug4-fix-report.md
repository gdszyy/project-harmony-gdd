# Bug-4 修复报告：spellcraft_system.gd Lambda 缩进错误

## 任务信息

- **任务 ID**: tsk-51345f1d-d0c
- **任务标题**: Bug-4: 修复 spellcraft_system.gd Lambda 缩进错误
- **执行 Agent**: agt-fa3dc156-50a (developer)
- **修复分支**: `bugfix/bug-4-spellcraft-system`
- **完成时间**: 2026-03-06

## 问题描述

在 `godot_project/scripts/autoload/spellcraft_system.gd` 第 1156 行，`_execute_spell` 函数被错误地缩进为 `_midi_to_black_key` 函数内部的嵌套 lambda，导致 Godot 4.x 将其解析为 standalone lambda 而非独立的类方法。

### 错误代码（修复前）

```gdscript
func _midi_to_black_key(note: int) -> int:
    var pc := note % 12
    match pc:
        1: return MusicData.BlackKey.CS
        ...
        _: return -1

    func _execute_spell(spell_data: Dictionary) -> void:  # ← 错误：多了一级缩进（1个Tab）
        # 应用手动施法的时机奖励
        var timing_bonus: float = spell_data.get("timing_bonus", 1.0)
        ...
```

## 修复内容

### 修复后代码

```gdscript
func _midi_to_black_key(note: int) -> int:
    var pc := note % 12
    match pc:
        1: return MusicData.BlackKey.CS
        ...
        _: return -1

func _execute_spell(spell_data: Dictionary) -> void:  # ← 正确：类顶级方法（0个Tab）
    # 应用手动施法的时机奖励
    var timing_bonus: float = spell_data.get("timing_bonus", 1.0)
    ...
```

### 修改的文件

| 文件 | 修改行范围 | 修改内容 |
|------|-----------|---------|
| `godot_project/scripts/autoload/spellcraft_system.gd` | 第 1156-1168 行 | 将 `_execute_spell` 函数及其函数体的缩进减少一级（去掉一个 Tab） |

### 具体修改

- **第 1156 行**: `\tfunc _execute_spell(...)` → `func _execute_spell(...)` （去掉 1 个 Tab）
- **第 1157-1167 行**: 函数体内所有行同步减少一级 Tab 缩进（`\t\t` → `\t`）

## 修复原则

- 只修复缩进，不改变任何业务逻辑
- 函数体内的相对缩进关系保持不变
- 不影响其他函数或代码

## Git 提交信息

- **分支**: `bugfix/bug-4-spellcraft-system`
- **Commit Hash**: `7762646`
- **Commit Message**: `fix(Bug-4): 修复 spellcraft_system.gd 中 _execute_spell 函数的 Lambda 缩进错误`
- **远程仓库**: https://github.com/gdszyy/project-harmony-gdd/tree/bugfix/bug-4-spellcraft-system
