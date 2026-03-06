# Bug 修复报告：boss_noise.gd 父类方法调用语法错误

## 任务信息

| 字段 | 值 |
|------|-----|
| 任务 ID | tsk-06f5a796-5c1 |
| 执行 Agent | agt-ad6f1f39-c97 (developer) |
| 修复分支 | `bugfix/boss-noise-super-keyword` |
| 完成时间 | 2026-03-06 |

## 错误描述

**文件**：`godot_project/scripts/entities/enemies/bosses/boss_noise.gd`

**行号**：第 761 行

**错误信息**：`Expected statement, found "." instead.`

**错误代码**：
```gdscript
func _on_phase_changed(new_phase_index: int, old_phase_index: int) -> void:
	._on_phase_changed(new_phase_index, old_phase_index)  # 第 761 行（错误）
```

## 根因分析

此错误是由 **Godot 3 到 Godot 4 的语法变更**导致的。

- **Godot 3 语法**：使用 `.method_name()` 调用父类方法（点号前缀）
- **Godot 4 语法**：使用 `super.method_name()` 调用父类方法（super 关键字）

在 Godot 4 中，以 `.` 开头的语句不再被解析为父类方法调用，因此 GDScript 解析器无法识别该语句，抛出 `Expected statement, found "." instead.` 错误。

## 修复详情

**修复方法**：将第 761 行的 `._on_phase_changed(...)` 修改为 `super._on_phase_changed(...)`

```gdscript
# 修复前（第 761 行）
._on_phase_changed(new_phase_index, old_phase_index)

# 修复后（第 761 行）
super._on_phase_changed(new_phase_index, old_phase_index)
```

## 修复验证

修复后的代码片段（第 760-765 行）：

```gdscript
func _on_phase_changed(new_phase_index: int, old_phase_index: int) -> void:
	super._on_phase_changed(new_phase_index, old_phase_index)
	
	# 进入波形切换阶段
	if new_phase_index == 1:
		_waveform_switch_interval = 10.0
```

## 提交信息

- **分支**：`bugfix/boss-noise-super-keyword`
- **Commit 信息**：`fix(boss_noise): 修复第761行父类方法调用缺少super关键字的语法错误`
- **仓库**：https://github.com/gdszyy/project-harmony-gdd

## 修复原则

本次修复遵循以下原则：
1. **不改变业务逻辑**：仅修改语法，`super._on_phase_changed()` 与原 `._on_phase_changed()` 在 Godot 4 中语义完全相同
2. **最小改动**：只修改必要的一行代码
3. **符合 Godot 4 规范**：使用 `super` 关键字是 Godot 4 GDScript 的标准父类方法调用方式
