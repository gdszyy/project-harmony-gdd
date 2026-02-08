# v5.0 代码审查与修复报告

> **审查日期：** 2026-02-08  
> **审查范围：** v5.0 提交的 15 个文件（3860 行新增代码），涵盖音频系统、弹体系统、UI 系统、Shader 等四大模块  
> **修复文件数：** 8 个  
> **修复问题数：** 8 个（严重 4 个，中等 4 个）

---

## 修复清单

### 严重问题

| 编号 | 文件 | 问题描述 | 修复方案 |
|------|------|----------|----------|
| S1 | `game_manager.gd` | 缺少 `player_damaged` 信号 — `hit_feedback_manager.gd` 连接该信号以触发屏幕抖动、红色暗角等受击反馈，信号不存在导致所有受击反馈完全失效 | 添加 `signal player_damaged(damage, source_position)` 并在 `damage_player()` 中发射 |
| S2 | `meta_progression_manager.gd` | 缺少 6 个 UI 适配方法 — `hall_of_harmony.gd` 调用 `get_upgrade_levels()`, `get_unlocked_skills()`, `get_selected_mode()`, `set_selected_mode()`, `purchase_upgrade()`, `unlock_skill()` 均不存在，导致和谐殿堂升级/技能/模式选择功能完全失效 | 添加 6 个适配方法，委托给已有的具体模块方法 |
| S3 | `game_manager.gd` + `projectile_manager.gd` | 护盾 `shield_hp` 没有实际吸收伤害的逻辑 — `_spawn_shield` 设置了 `shield_hp: 40.0` 但只在弹体字典中，`damage_player()` 不知道护盾的存在 | 在 GameManager 添加 `shield_hp`/`max_shield_hp` 属性，`damage_player()` 优先扣除护盾值，`_spawn_shield` 同步到 GameManager，护盾消失时清零 |
| S4 | `project.godot` | `HitFeedbackManager` 未注册为 autoload — 文件注释标注为 Autoload 但未在 project.godot 中注册，导致受击反馈系统不会被加载 | 在 `[autoload]` 段添加 `HitFeedbackManager` |

### 中等问题

| 编号 | 文件 | 问题描述 | 修复方案 |
|------|------|----------|----------|
| M1 | `codex_manager.gd` | 缺少 `get_unlocked_entries()` 方法 — `codex_ui.gd` 的 `_load_unlock_state()` 调用该方法加载图鉴解锁状态 | 添加 `get_unlocked_entries()` 返回 `_unlocked_entries.duplicate()` |
| M2 | `bgm_manager.gd` | `PAD_CHORDS: Array[Array]` 类型声明在 Godot 4.x 中不支持嵌套类型数组 | 改为 `PAD_CHORDS: Array`（无类型约束） |
| M3 | `player.gd` + `enemy_base.gd` | `take_damage()` 不传递伤害来源位置 — `hit_feedback_manager.gd` 需要 `source_position` 来显示方向性受击反馈 | `player.take_damage()` 添加 `source_position` 参数，`enemy_base.gd` 碰撞时传递 `global_position` |
| M4 | `game_manager.gd` | `reset_game()` 未重置 `shield_hp` — 新一局游戏可能继承上一局的残余护盾值 | 在 `reset_game()` 中添加 `shield_hp = 0.0` 和 `max_shield_hp = 0.0` |

---

## 验证通过的模块

以下 v5.0 新增/修改的模块经审查确认无问题：

| 模块 | 审查结果 |
|------|----------|
| `bgm_manager.gd` 核心逻辑 | 信号连接正确，FatigueManager 信号参数匹配 |
| `hit_feedback_manager.gd` 核心逻辑 | 使用 `has_signal` 保护，不会因信号缺失崩溃 |
| `crystallized_obstacle.gd` | 自包含逻辑，仅引用 shader 文件 |
| `boss_hp_bar_ui.gd` | 自包含 UI 组件，无外部依赖问题 |
| `note_synthesizer.gd` | MusicData 枚举引用正确 |
| `sequencer_ui.gd` 修改部分 | SpellcraftSystem 方法引用正确 |
| `audio_manager.gd` 修改部分 | NoteSynthesizer 方法引用正确 |
| `codex_ui.gd` 修改部分 | CodexData 常量引用正确 |
| Shader 文件 | 语法结构正确 |

---

## 修复文件清单

```
godot_project/project.godot                            (+1)
godot_project/scripts/autoload/game_manager.gd         (+21 -2)
godot_project/scripts/autoload/meta_progression_manager.gd (+41)
godot_project/scripts/autoload/codex_manager.gd        (+4)
godot_project/scripts/autoload/bgm_manager.gd          (+1 -1)
godot_project/scripts/entities/player.gd               (+2 -2)
godot_project/scripts/entities/enemy_base.gd           (+1 -1)
godot_project/scripts/systems/projectile_manager.gd    (+8)
```
