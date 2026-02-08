# Project Harmony — 开发待办清单 (TODO)

> **重要规范**：每次对代码或设计文档进行修改后，**必须同步更新本文件**以反映最新的开发状态。  
> 最后更新时间：2026-02-08

---

## 目录

1. [核心系统状态总览](#核心系统状态总览)
2. [法术构建系统 (SpellcraftSystem)](#法术构建系统-spellcraftsystem)
3. [听感疲劳系统 (FatigueManager)](#听感疲劳系统-fatiguemanager)
4. [音乐理论引擎 (MusicTheoryEngine)](#音乐理论引擎-musictheoryengine)
5. [弹体系统 (ProjectileManager)](#弹体系统-projectilemanager)
6. [敌人系统 (EnemySpawner)](#敌人系统-enemyspawner)
7. [Boss 系统](#boss-系统)
8. [视觉与 Shader](#视觉与-shader)
9. [UI 系统](#ui-系统)
10. [音频系统](#音频系统)
11. [局外成长 (SaveManager)](#局外成长-savemanager)
12. [游戏流程](#游戏流程)
13. [性能优化](#性能优化)
14. [待设计/待讨论](#待设计待讨论)

---

## 核心系统状态总览

| 系统 | 状态 | 完成度 | 说明 |
|------|------|--------|------|
| 法术构建系统 | ✅ 核心完成 | 85% | 序列器、手动施法、和弦构建、节奏型修饰、和弦进行效果均已实现 |
| 听感疲劳系统 | ✅ 核心完成 | 90% | 八维AFI、三维惩罚（单音寂静/密度过载/不和谐腐蚀）均已实现 |
| 音乐理论引擎 | ✅ 完成 | 95% | 和弦识别、功能判定、进行分析、不和谐度计算均已实现 |
| 弹体系统 | ✅ 核心完成 | 80% | MultiMesh渲染、修饰符、和弦弹体、密度过载散射均已实现 |
| 敌人系统 | ✅ 核心完成 | 75% | 5种基础敌人已实现，需要更多敌人变体 |
| Boss 系统 | ⚠️ 待重做 | 10% | 原Boss已归档，需按GDD重新设计音乐史七大Boss |
| 视觉/Shader | ✅ 核心完成 | 85% | 疲劳滤镜、弹体发光、脉冲网格、事件视界均已实现 |
| UI 系统 | ✅ 核心完成 | 80% | HUD、伤害数字、疲劳仪表、升级面板均已实现 |
| 音频系统 | ✅ 核心完成 | 75% | 音符合成、ADSR包络、音色系统已实现 |
| 局外成长 | ✅ 核心完成 | 85% | 乐器调优、乐理研习、声学降噪、调式选择均已实现 |
| 游戏流程 | ✅ 核心完成 | 80% | 开始/暂停/结束/重置/结算均已实现 |

---

## 法术构建系统 (SpellcraftSystem)

### 已完成 ✅

- [x] 16拍序列器 (4小节 × 4拍)
- [x] 7个白键音符，每个有独立四维属性 (DMG/SPD/DUR/SIZE)
- [x] 5个黑键修饰符 (穿透/追踪/分裂/回响/散射)
- [x] **黑键双重身份**：和弦缓冲窗口内参与和弦构建，否则作为修饰符 (Issue #18) — *v2.0 新增*
- [x] 和弦构建缓冲区 (0.3秒窗口)
- [x] 9种基础和弦 → 9种法术形态映射
- [x] 6种扩展和弦 → 6种传说法术形态映射
- [x] **6种节奏型识别与行为修饰** (连射/重击/闪避射击/摇摆弹道/三连发/精准蓄力) — *v2.0 完善*
- [x] **手动施法槽** (3槽，带冷却，八分音符精度对齐，时机奖励+15%) — *v2.0 完善*
- [x] **和弦进行效果完整实现** — *v2.0 新增*
  - D→T: 爆发治疗（低血量）或全屏伤害（高血量），受完整度加成
  - T→D: 增伤Buff（下一法术伤害翻倍），受完整度加成
  - PD→D: 全体手动施法槽冷却缩减50%，受完整度加成
- [x] 音色系统接口 (切换音色、疲劳代价)
- [x] **单音寂静检查集成** (被寂静音符无法施放，发出 spell_blocked_by_silence 信号) — *v2.0 新增*
- [x] **密度过载精准度惩罚集成** (弹体方向随机偏移) — *v2.0 新增*
- [x] **不和谐法术缓解单调值的交互** (reduce_monotony_from_dissonance) — *v2.0 新增*
- [x] **系统重置接口** (供 GameManager.reset_game 调用) — *v2.0 新增*
- [x] **小节完成时的处理逻辑** (_on_measure_complete) — *v2.0 新增*
- [x] **八分音符精度的手动施法** (_on_half_beat_tick) — *v2.0 新增*
- [x] **闪避射击行为** (SYNCOPATED 发射时玩家向后微位移) — *v2.0 新增*
- [x] **连射行为** (EVEN_EIGHTH 多弹体发射) — *v2.0 新增*
- [x] **三连发行为** (TRIPLET 扇形弹体) — *v2.0 新增*
- [x] **精准蓄力加成** (REST 休止符数量加成同小节弹体伤害和大小) — *v2.0 新增*

### 待完成 🔲

- [ ] 摇摆弹道 (SWING) 的 S 型/波浪形轨迹实现 (ProjectileManager 中)
- [ ] 和弦法术的完整视觉效果 (法阵、天降打击、护盾、召唤等)
- [ ] 扩展和弦法术的完整视觉效果 (风暴区域、圣光领域、湮灭射线等)
- [ ] 序列器 UI 的拖拽编辑交互
- [ ] 手动施法槽的 UI 冷却显示
- [ ] 音色切换的 UI 和快捷键绑定

---

## 听感疲劳系统 (FatigueManager)

### 已完成 ✅

- [x] 八维 AFI 计算 (音高熵/转移熵/节奏熵/和弦多样性/模式递归/密度/留白缺失/持续压力)
- [x] 滑动窗口 + 指数时间衰减
- [x] 五级疲劳等级 (NONE/MILD/MODERATE/SEVERE/CRITICAL)
- [x] 三种惩罚模式 (WEAKEN/LOCKOUT/GLOBAL_DEBUFF)
- [x] **单音寂静惩罚** — *v2.0 新增*
  - 短窗口(8秒)内同一音符使用 ≥4次 → 该音符暂时禁用
  - 基础寂静时间3秒 + 每多用1次额外+1秒
  - 受单调抗性升级减免
  - 信号：note_silenced / note_unsilenced
- [x] **密度过载惩罚** — *v2.0 新增*
  - 3秒内施法次数超过动态阈值 → 弹体精准度下降
  - 轻度过载：0.3弧度散射偏移
  - 严重过载：0.6弧度散射偏移
  - 阈值随BPM动态调整，受密度抗性升级加成
  - 信号：density_overload_changed
- [x] **不和谐值连接** — *v2.0 新增*
  - 不和谐法术直接扣血 (生命腐蚀)，由 GameManager.apply_dissonance_damage 处理
  - 不和谐度 > 2.0 时触发
  - 受局外成长"绝对音感"升级减免
- [x] **不和谐法术缓解单调值** (reduce_monotony_from_dissonance) — *v2.0 新增*
  - 每点不和谐度减少0.5秒寂静时间（不和谐是双刃剑的关键交互）
- [x] 每个音符的独立疲劳度查询 (get_note_fatigue_map)
- [x] 恢复建议系统 (recovery_suggestion 信号) — *v2.0 增强：包含单音寂静和密度过载建议*
- [x] 外部疲劳注入接口 (add_external_fatigue)
- [x] 疲劳减少接口 (reduce_fatigue)
- [x] 升级抗性接口 (单调抗性/密度抗性/不和谐衰减)
- [x] **系统重置接口** (包含寂静和过载状态重置) — *v2.0 完善*

### 待完成 🔲

- [ ] 调优：单音寂静触发阈值的平衡性测试
- [ ] 调优：密度过载阈值与 BPM 的动态关系微调
- [ ] 留白奖励机制：休止符主动清除负面状态的实现
- [ ] 疲劳等级变化时的视觉/音效反馈增强

---

## 音乐理论引擎 (MusicTheoryEngine)

### 已完成 ✅

- [x] 和弦识别 (支持所有15种和弦类型)
- [x] 和弦功能判定 (T/PD/D 三功能)
- [x] 和弦进行分析 (D→T/T→D/PD→D)
- [x] 完整度计算 (2-4和弦连续有效转换)
- [x] 不和谐度计算 (和弦级别 + 音程级别)
- [x] 扩展和弦检测
- [x] 历史清除接口

### 待完成 🔲

- [ ] 调性感知：根据当前调式动态调整和弦功能判定
- [ ] 更精确的和弦转位识别

---

## 弹体系统 (ProjectileManager)

### 已完成 ✅

- [x] MultiMesh 批量渲染 (最大500弹体)
- [x] 对象池管理
- [x] 5种修饰符效果 (穿透/追踪/分裂/回响/散射)
- [x] 和弦弹体 (强化弹体/DOT弹体/爆炸弹体/冲击波/蓄力弹体)
- [x] 连射 (EVEN_EIGHTH) 多弹体发射
- [x] 三连发 (TRIPLET) 扇形弹体
- [x] **密度过载精准度惩罚** (弹体方向随机偏移) — *v2.0 新增*
- [x] 弹体发光 Shader (projectile_glow.gdshader)
- [x] 空间哈希碰撞优化 (SpatialHash)

### 待完成 🔲

- [ ] 摇摆弹道 (SWING) S 型轨迹
- [ ] 法阵/区域 (FIELD) 弹体形态
- [ ] 天降打击 (DIVINE_STRIKE) 弹体形态
- [ ] 护盾/治疗 (SHIELD_HEAL) 弹体形态
- [ ] 召唤/构造 (SUMMON) 弹体形态
- [ ] 扩展和弦法术的6种弹体形态
- [ ] 弹体拖尾效果 (Trail)

---

## 敌人系统 (EnemySpawner)

### 已完成 ✅

- [x] 基础敌人框架 (enemy_base.gd)
- [x] Static (静态噪音) — 直线追踪 + 群体加速
- [x] Pulse (脉冲干扰) — 节拍同步冲刺 + 蓄力释放
- [x] Screech (尖啸反馈) — 远程攻击 + 冲刺 + 死亡不和谐爆发
- [x] Silence (寂静吞噬) — 注入疲劳 + 静音光环
- [x] Wall (音墙) — 高血量屏障 + 护盾 + 地震冲击波
- [x] 波次生成系统 (5种波次类型)
- [x] 精英敌人 (HP+50%, 伤害+30%, 金色标记)
- [x] 经验值掉落 (xp_pickup) — 4级分级 + 磁吸 + 合并
- [x] 死亡特效 (death_vfx_manager) — 对象池碎片 + 5种类型差异化
- [x] 敌人场景模板 (5个 .tscn 文件)
- [x] 敌人 Shader (enemy_glitch + silence_aura)
- [x] 难度曲线 (指数递增 + BPM节奏生成)

### 待完成 🔲

- [ ] 更多敌人变体 (如 Echo 回声敌人、Feedback 反馈敌人)
- [ ] 敌人属性随时间/BPM 动态缩放
- [ ] 敌人与疲劳系统的更深交互

---

## Boss 系统

### 已完成 ✅

- [x] Boss 基类框架 (boss_base.gd)
- [x] Boss 生成器 (boss_spawner.gd)
- [x] Boss 血条 UI (boss_health_bar.gd)

### 已归档 📦

- 失谐指挥家 (Dissonance Conductor) — 已移至 `Archive/Boss_Dissonance_Conductor/`
- Max_Issues_Implementation_Report.md — 已移至 `Archive/`

### 待完成 🔲 (按 GDD 音乐史七大 Boss 设计)

- [ ] Boss 1: 古典时期 Boss (对位法大师)
- [ ] Boss 2: 巴洛克时期 Boss (装饰音暴君)
- [ ] Boss 3: 浪漫时期 Boss (情感风暴)
- [ ] Boss 4: 印象派 Boss (和声迷雾)
- [ ] Boss 5: 爵士时期 Boss (即兴之王)
- [ ] Boss 6: 电子时期 Boss (合成器霸主)
- [ ] Boss 7: 终章 Boss (不和谐之王)
- [ ] Boss 战斗阶段系统 (多阶段切换)
- [ ] Boss 专属机制 (与乐理深度交互)
- [ ] Boss 战前/战后叙事

---

## 视觉与 Shader

### 已完成 ✅

- [x] 疲劳滤镜 Shader (fatigue_filter.gdshader) — 色差/噪点/扫描线/去饱和/不和谐紫边/节拍闪烁
- [x] 弹体发光 Shader (projectile_glow.gdshader) — 核心亮点/外层辉光/脉冲动画
- [x] 脉冲网格 Shader (pulsing_grid.gdshader) — 地面节拍响应
- [x] 事件视界 Shader (event_horizon.gdshader) — 竞技场边界
- [x] 敌人故障 Shader (enemy_glitch.gdshader) — 色差/扫描线/水平撕裂
- [x] 寂静光环 Shader (silence_aura.gdshader) — 吸收光环/螺旋纹理
- [x] **疲劳滤镜接入 HUD** (fatigue_level + beat_pulse + dissonance_level) — *v2.0 完善*
- [x] 玩家视觉增强 (player_visual_enhanced.gd)
- [x] 地面网格接入 main_game (pulsing_grid + 疲劳色调变化)
- [x] 事件视界接入 main_game (环形边界 + Shader 参数更新)

### 待完成 🔲

- [ ] 和弦法术的专属视觉效果 (法阵光环、天降光柱等)
- [ ] 单音寂静的视觉反馈 (被禁用音符的 UI 灰化 + 屏幕闪烁)
- [ ] 密度过载的视觉反馈 (屏幕边缘抖动)
- [ ] 和弦进行解决的视觉反馈 (全屏波纹)
- [ ] 敌人死亡粒子效果增强
- [ ] 障碍物 "固化静默" 视觉 (均衡器频谱起伏)

---

## UI 系统

### 已完成 ✅

- [x] HUD 主界面 (hud.gd) — 血条/疲劳度/BPM/时间/等级
- [x] 疲劳仪表 (fatigue_meter.gd)
- [x] 伤害数字系统 (damage_number.gd + damage_number_manager.gd) — 对象池化，4种类型 (普通/暴击/完美/不和谐)
- [x] 弹药环 HUD (ammo_ring_hud.gd)
- [x] 序列器 UI (sequencer_ui.gd)
- [x] 升级面板 (upgrade_panel.gd)
- [x] 暂停菜单 (pause_menu.gd)
- [x] 设置菜单 (settings_menu.gd)
- [x] 局结算界面 (run_results_screen.gd + game_over.gd)
- [x] 和谐殿堂 UI (hall_of_harmony.gd)
- [x] 性能监控 (performance_monitor.gd)
- [x] 恢复建议文字显示 (带淡出动画)

### 待完成 🔲

- [ ] 序列器 UI 的拖拽编辑交互
- [ ] 手动施法槽 UI (冷却进度环)
- [ ] 单音寂静状态的音符 UI 灰化
- [ ] 密度过载状态的 UI 警告指示器
- [ ] 和弦进行效果的 UI 提示 (如 "D→T 解决！爆发治疗！")
- [ ] 音色切换 UI
- [ ] 升级面板稀有度视觉区分 (普通/稀有/史诗/传说)

---

## 音频系统

### 已完成 ✅

- [x] 音符合成器 (note_synthesizer.gd) — 12半音实时合成
- [x] ADSR 包络 (attack/decay/sustain/release)
- [x] 5种音色系别 (合成器/弹拨/拉弦/吹奏/打击)
- [x] 泛音结构 + 波形类型
- [x] 全局音乐管理器 (global_music_manager.gd)
- [x] BGM 管理器 (bgm_manager.gd) — 交叉淡入淡出 + BPM 同步
- [x] 音效管理器 (audio_manager.gd) — 程序化音效 + 对象池 + 信号驱动
- [x] 频谱分析接入 (AudioEffectSpectrumAnalyzer)
- [x] 音频总线布局 (Music/SFX/EnemySFX/PlayerSFX/UI)

### 待完成 🔲

- [ ] 和弦音效 (多音符同时播放)
- [ ] 和弦进行解决音效
- [ ] 单音寂静触发音效 (音符消失的"嗡"声)
- [ ] 密度过载音效 (失真/过载效果)
- [ ] BGM 与疲劳等级的动态混音
- [ ] 实际 BGM 音频文件 (.ogg)

---

## 局外成长 (SaveManager)

### 已完成 ✅

- [x] 共鸣碎片货币系统
- [x] 乐器调优 (5种升级：舞台定力/基础声压/节拍敏锐度/拾音范围/起拍速度)
- [x] 乐理研习 (7种解锁：3个修饰符 + 3个和弦 + 传说乐章)
- [x] 声学降噪 (4种升级：听觉耐受/混响消除/绝对音感/休止符美学)
- [x] 调式/职业选择 (4种：伊奥尼亚/多利亚/五声音阶/布鲁斯)
- [x] 局结算共鸣碎片奖励计算 (时间+击杀+等级)
- [x] 存档持久化 (ConfigFile)
- [x] 局外加成应用接口 (apply_meta_bonuses)
- [x] 修饰符/和弦解锁检查 (is_modifier_available / is_chord_type_available)

### 待完成 🔲

- [ ] 和谐殿堂 UI 的完整交互流程
- [ ] 调式选择对游戏玩法的实际影响 (限制可用音符等)
- [ ] 更多调式/职业解锁
- [ ] 成就系统

---

## 游戏流程

### 已完成 ✅

- [x] 主菜单 → 游戏 → 结算 完整流程
- [x] 游戏开始 (start_game) — 重置状态 + 应用局外加成
- [x] 游戏暂停/恢复
- [x] 游戏结束 (game_over) — 保存进度 + 计算奖励
- [x] **游戏重置 (reset_game)** — 重置所有子系统 (GameManager/FatigueManager/SpellcraftSystem/MusicTheoryEngine) — *v2.0 完善*
- [x] 重试/返回菜单 (game_over.gd)
- [x] 竞技场边界限制
- [x] 碰撞检测 (~30Hz)
- [x] 玩家无敌帧
- [x] 闪避机制
- [x] **不和谐伤害连接** (SpellcraftSystem → GameManager.apply_dissonance_damage) — *v2.0 新增*

### 待完成 🔲

- [ ] 新手引导/教程关卡
- [ ] 难度选择
- [ ] 每局随机事件/变异器
- [ ] 计时里程碑 (5分钟/10分钟/15分钟 Boss 出现)
- [ ] CollisionShape 资源配置 (Player: CircleShape2D 12px, PickupArea: 80px)

---

## 性能优化

### 已完成 ✅

- [x] MultiMesh 弹体批量渲染
- [x] 对象池 (弹体、伤害数字、死亡特效碎片)
- [x] 空间哈希碰撞优化 (SpatialHash)
- [x] 碰撞检测频率控制 (~30Hz)
- [x] 音效对象池 (32个2D播放器 + 8个全局播放器)
- [x] 音效冷却系统

### 待完成 🔲

- [ ] 大量敌人时的性能测试与优化
- [ ] 敌人对象池 (替代 instantiate/queue_free)
- [ ] MultiMesh 高负载验证 (2000+弹体)
- [ ] 移动端适配 (如果需要)

---

## 待设计/待讨论

- [ ] 多人合奏模式 (是否实现？)
- [ ] 排行榜系统
- [ ] Steam 成就集成
- [ ] 自定义序列器预设保存/分享
- [ ] 回放系统 (记录每局的"乐谱")
- [ ] 障碍物系统 ("固化静默" 黑色玄武岩柱体)

---

## 文件变更日志

### 2026-02-08 v2.0 核心玩法完善

**修改文件：**

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `scripts/autoload/fatigue_manager.gd` | 重写 | 新增单音寂静、密度过载、不和谐值连接三维惩罚 |
| `scripts/autoload/spellcraft_system.gd` | 重写 | 完善黑键双重身份、手动施法、和弦进行效果、节奏型修饰 |
| `scripts/systems/projectile_manager.gd` | 编辑 | 新增密度过载精准度偏移（弹体+和弦弹体） |
| `scripts/autoload/game_manager.gd` | 编辑 | 完善 reset_game() 重置所有子系统 |
| `scripts/ui/hud.gd` | 编辑 | 疲劳滤镜接入不和谐度视觉参数 |

**归档文件：**

| 文件 | 移至 |
|------|------|
| `scripts/entities/enemies/boss_dissonance_conductor.gd` | `Archive/Boss_Dissonance_Conductor/` |
| `Max_Issues_Implementation_Report.md` | `Archive/` |

### 2026-02-07 v1.0 初始实现

- 音频系统全面完成 (AudioManager + BGMManager + NoteSynthesizer + 音色系统)
- 敌人系统全面完成 (5种敌人 + 场景模板 + AI行为 + 死亡特效)
- 视觉系统基础完成 (4种Shader + 玩家视觉增强)
- UI系统基础完成 (HUD + 序列器 + 升级面板)
- 局外成长系统完成 (SaveManager + 和谐殿堂)
