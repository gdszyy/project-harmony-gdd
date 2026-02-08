# Project Harmony GDD — 核心模块深度审查报告（第二轮）

## 审查范围

本轮对项目所有核心模块进行了全面交叉验证，涵盖以下类别：

| 类别 | 审查文件数 | 审查内容 |
|------|-----------|---------|
| Autoload 系统 | 11 个 | GameManager, FatigueManager, SpellcraftSystem, ModeSystem, GlobalMusicManager, AudioManager, BGMManager, SaveManager, CodexManager, MetaProgressionManager, MusicTheoryEngine |
| 实体脚本 | 20+ 个 | player.gd, enemy_base.gd, boss_base.gd, elite_base.gd, xp_pickup.gd, 各章节敌人和精英/Boss |
| 系统脚本 | 5 个 | enemy_spawner.gd, projectile_manager.gd, boss_spawner.gd, chapter_manager.gd, summon_manager.gd |
| UI 脚本 | 10 个 | hud.gd, sequencer_ui.gd, fatigue_meter.gd, hp_bar.gd, debug_panel.gd, upgrade_panel.gd, pause_menu.gd, codex_ui.gd 等 |
| 场景文件 | 8 个 | 所有 .tscn 文件的节点结构、信号连接、资源引用 |

## 发现并修复的问题

### 1. player.gd — 暂停输入重复处理（严重）

`player.gd` 的 `_unhandled_input` 和 `main_game.gd` 的 `_input` 都处理了 `pause_game` 动作。由于 `_input` 先于 `_unhandled_input` 执行，两者会在同一帧内先暂停再恢复（或反之），导致暂停功能完全失效。已删除 `player.gd` 中的重复暂停处理。

### 2. player.gd — InvincibilityTimer timeout 信号未连接（严重）

`_setup_timers()` 只在 InvincibilityTimer 节点不存在时动态创建并连接信号。但场景中已预置了该 Timer 节点，导致 `_on_invincibility_timeout` 永远不会被调用，玩家受击后无敌状态无法解除。已在 `_ready()` 中添加显式信号连接。

### 3. player.gd — PickupArea 信号类型错误（严重）

`xp_pickup.gd` 继承自 `Area2D`，但 PickupArea 使用的是 `body_entered` 信号。`body_entered` 只检测 `PhysicsBody2D`（如 CharacterBody2D、RigidBody2D），不会检测 Area2D。已改为使用 `area_entered` 信号。

### 4. player.gd — xp_value 属性读取方式不兼容

`enemy_spawner.gd` 创建的简易 pickup 使用 `set_meta("xp_value", value)` 存储经验值，而 `player.gd` 使用 `"xp_value" in area` 检查属性。已修改为同时兼容属性和 meta 两种方式。

### 5. FatigueManager — 缺少 get_current_fatigue() 方法（中等）

`ch1_frequency_sentinel.gd`（第一章精英敌人）调用 `FatigueManager.get_current_fatigue()` 来根据疲劳度计算伤害加成，但该方法不存在。虽然有 `has_method` 保护不会崩溃，但功能失效。已添加该方法。

### 6. enemy_base.gd — 缺少 set_frozen() 方法（中等）

`test_chamber.gd` 的冻结敌人功能调用 `enemy.set_frozen(true/false)`，但 `enemy_base.gd` 中没有该方法。已添加基于 `_is_stunned` 状态的冻结实现。

### 7. xp_pickup.gd — _collect() 未调用 GameManager.add_xp（严重）

`xp_pickup.gd` 的磁吸收集逻辑 `_collect()` 只发出 `collected` 信号，但没有任何地方连接该信号来处理经验值。已在 `_collect()` 中直接调用 `GameManager.add_xp(xp_value)`。

### 8. enemy_spawner.gd — 经验值重复计算（严重）

`_on_enemy_died` 中直接调用 `GameManager.add_xp(xp)`，同时又生成 xp_pickup，pickup 被拾取时再次调用 `add_xp`，导致经验值双倍计算。`_start_pickup_attraction` 中也有同样的重复。已删除所有重复的 `add_xp` 调用。

### 9. enemy_spawner.gd — 简易 pickup 缺少 xp_value 属性

`_spawn_xp_pickup` 创建的简易 Area2D 只使用 `set_meta` 存储 xp_value，但 player 的拾取逻辑需要属性访问。已添加 `set("xp_value", value)` 确保兼容。

## 验证通过的模块

以下模块经审查确认无问题：

| 模块 | 验证结果 |
|------|---------|
| GameManager 信号签名 | beat_tick, half_beat_tick, measure_complete 参数与所有监听器匹配 |
| SpellcraftSystem 信号 | spell_blocked_by_silence, accuracy_penalized, progression_resolved 参数匹配 |
| FatigueManager 信号 | fatigue_updated, fatigue_level_changed, note_silenced 参数匹配 |
| AudioManager 方法 | play_spell_cast_sfx, play_chord_cast_sfx, register_enemy 均存在 |
| GlobalMusicManager 方法 | play_note_sound, play_chord_sound, set_timbre, get_beat_energy 均存在 |
| BGMManager 方法 | start_bgm, auto_select_bgm_for_state 均存在 |
| 场景切换路径 | 所有 change_scene_to_file 引用的 .tscn 路径均存在 |
| Input Action 名称 | 所有脚本引用的动作名称均在 project.godot 或 input_setup.gd 中定义 |
| 数据类 | MusicData, ChapterData, CodexData 的常量和枚举引用均正确 |
