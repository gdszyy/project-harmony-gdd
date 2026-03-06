# Bug-2 修复报告：BgmManager Autoload 名称不匹配及 bgm_manager.gd 语法错误

## 任务信息

| 字段 | 值 |
|------|-----|
| 任务 ID | tsk-7126ecc6-d45 |
| 执行 Agent | agt-9080558c-eb4 (developer) |
| 修复分支 | `bugfix/bug-2-bgm-manager` |
| 完成时间 | 2026-03-06 |

## 根因分析

本次 Bug 包含两个独立根因：

**根因 1：bgm_manager.gd 语法错误（空 if 块）**

`bgm_manager.gd:1232` 中存在一个空 `if` 块，GDScript 要求 `if` 块后必须有至少一条语句，否则会导致编译失败。

**根因 2：Autoload 名称大小写不匹配**

`project.godot` 中将 BGM 管理器注册为 `BGMManager`，但以下三个文件中引用的是 `BgmManager`（大小写不一致），导致运行时无法找到该 Autoload 节点：
- `chapter_manager.gd`
- `main_game.gd`
- `test_chamber.gd`

## 修复详情

### 修复 1：bgm_manager.gd:1232 — 空 if 块添加 pass

**文件**：`godot_project/scripts/autoload/bgm_manager.gd`

```gdscript
# 修复前
if old_root != root:

## 计算和弦包含的音高类

# 修复后
if old_root != root:
    pass

## 计算和弦包含的音高类
```

### 修复 2：chapter_manager.gd:257-258 — BgmManager → BGMManager

**文件**：`godot_project/scripts/systems/chapter_manager.gd`

```gdscript
# 修复前
if BgmManager and BgmManager.has_method("set_tonality"):
    BgmManager.set_tonality(tonality_key)

# 修复后
if BGMManager and BGMManager.has_method("set_tonality"):
    BGMManager.set_tonality(tonality_key)
```

### 修复 3：main_game.gd:1296-1297 — BgmManager → BGMManager

**文件**：`godot_project/scripts/scenes/main_game.gd`

```gdscript
# 修复前
if BgmManager and BgmManager.has_method("set_tonality"):
    BgmManager.set_tonality(tonality_key)

# 修复后
if BGMManager and BGMManager.has_method("set_tonality"):
    BGMManager.set_tonality(tonality_key)
```

### 修复 4：test_chamber.gd:408-409 — BgmManager → BGMManager

**文件**：`godot_project/scripts/scenes/test_chamber.gd`

```gdscript
# 修复前
if BgmManager and BgmManager.has_method("set_tonality"):
    BgmManager.set_tonality(tonality_key)

# 修复后
if BGMManager and BGMManager.has_method("set_tonality"):
    BGMManager.set_tonality(tonality_key)
```

## 验证说明

1. **bgm_manager.gd**：空 `if` 块添加 `pass` 后，GDScript 编译器可正常解析该函数，不再报语法错误。
2. **Autoload 名称统一**：三个文件中的 `BgmManager` 均已改为 `BGMManager`，与 `project.godot` 中的注册名一致，运行时可正确访问该 Autoload 节点。
3. **业务逻辑不变**：所有修改仅涉及名称大小写和空块语法，未改变任何业务逻辑。

## 注意事项

以下文件中的 `BgmManager` 字符串仅出现在**注释**中，无需修改：
- `signal_bridge.gd:459` — 注释文字
- `enemy_audio_controller.gd` — 注释文字（实际代码使用 `get_node_or_null("/root/BGMManager")`）
- `relative_pitch_resolver.gd` — 注释文字（实际代码使用 `Engine.get_singleton("BGMManager")`）

## Git 提交信息

- **分支**：`bugfix/bug-2-bgm-manager`
- **Commit**：`50d2d63` — `fix(Bug-2): 修复 BgmManager Autoload 名称不匹配及 bgm_manager.gd 语法错误`
- **仓库**：https://github.com/gdszyy/project-harmony-gdd
