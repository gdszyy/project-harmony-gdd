# Project Harmony — 开发待办清单 (TODO)

> **重要规范**：每次对代码或设计文档进行修改后，**必须同步更新本文件**以反映最新的开发状态。  
> 最后更新时间：2026-02-12 v10.0 (TODO.md 全面同步更新 — 基于 Feature_Completeness_Report v3.0 / Grey_Area_Verification_Report / Verification_Summary_Report 权威结论)

---

## 目录

1. [核心系统状态总览](#核心系统状态总览)
2. [第一章垂直切片开发状态](#第一章垂直切片开发状态)
3. [法术构建系统 (SpellcraftSystem)](#法术构建系统-spellcraftsystem)
4. [音符经济与升级系统](#音符经济与升级系统)
5. [听感疲劳系统 (FatigueManager)](#听感疲劳系统-fatiguemanager)
6. [召唤系统 (SummonManager)](#召唤系统-summonmanager)
7. [调式系统 (ModeSystem)](#调式系统-modesystem)
8. [音乐理论引擎 (MusicTheoryEngine)](#音乐理论引擎-musictheoryengine)
9. [弹体系统 (ProjectileManager)](#弹体系统-projectilemanager)
10. [敌人系统 (EnemySpawner)](#敌人系统-enemyspawner)
11. [Boss 系统](#boss-系统)
12. [精英敌人系统](#精英敌人系统)
13. [章节敌人系统](#章节敌人系统)
14. [视觉与 Shader](#视觉与-shader)
15. [UI 系统](#ui-系统)
16. [音频系统](#音频系统)
17. [局外成长 (SaveManager)](#局外成长-savemanager)
18. [游戏流程](#游戏流程)
19. [性能优化](#性能优化)
20. [技术债务](#技术债务)
21. [待设计/待讨论](#待设计待讨论)

---

## 核心系统状态总览

| 系统 | 状态 | 完成度 | 说明 |
|------|------|--------|------|
| 法术构建系统 | ✅ 核心完成 | 85% | 序列器、手动施法、和弦、进行效果、调式集成、留白奖励；扩展和弦/节奏型修饰/黑键双重身份待完善 |
| 音符经济系统 | ✅ 已完成 | 100% | NoteInventory 自动加载、库存管理、装备/卸下、法术书、信号系统 |
| 和弦炼成系统 | ✅ 已完成 | 100% | 炼成台 UI、音程识别、11种和弦模式、拖拽操作、音符永久消耗 |
| 五度圈罗盘升级 | ✅ 已完成 | 100% | 12刻度圆盘、三方向选项、24种升级、4种稀有度、调性注入 |
| 听感疲劳系统 | ✅ 核心完成 | 90% | 八维AFI、三维惩罚、单音寂静+密度过载已完成；疲劳滤镜视觉/恢复建议UI/不和谐腐蚀连接待完善 |
| 召唤系统 | ✅ 已完成 | 100% | v7.0 双模式架构（音色驱动+根音构造体）、共鸣网络、玩家指挥机制 |
| 调式/职业系统 | ✅ 核心完成 | 95% | 4种调式+角色职业系统（属性修正、初始序列器、被动能力、视觉风格） |
| 音乐理论引擎 | ✅ 完成 | 95% | 和弦识别、功能判定、进行分析、不和谐度计算均已实现 |
| 弹体系统 | ✅ 核心完成 | 85% | MultiMesh渲染、修饰符、和弦弹体、摇摆弹道、拖尾效果 |
| 敌人系统 | ✅ 核心完成 | 75% | 5种基础敌人已实现，6种章节特色敌人待实现 |
| Boss 系统 | ✅ 框架+触发完成 | 40% | boss_base.gd + 失谐指挥家已完成；Boss战触发流程已完成；音乐史七大Boss内容待实现 |
| 精英敌人 | ✅ 核心完成 | 85% | 8个精英脚本(.gd)+场景文件(.tscn)均已创建，待完善专属机制与视觉效果 |
| 章节敌人 | ✅ 核心完成 | 85% | 13个脚本+场景文件均已创建，章节敌人生成系统已完全集成 |
| 视觉/Shader | ✅ 核心完成 | 98% | 疲劳滤镜、弹体发光、七大层级视觉增强、修饰符VFX、音色弹体、频谱相位、惩罚效果、和弦进行VFX |
| UI 系统 | ✅ 核心完成 | 97% | HUD全面完善 + 统一调色板 + 按钮交互增强 + 面板动画 + Boss血条主题化 + 序列器交互优化 + 和弦构建器 |
| 音频系统 | ✅ 核心完成 | 97% | 音符合成、ADSR、音色、寂静/过载/暴击/清洗音效、OPT01-OPT08全部已集成 |
| 局外成长 | ✅ 已完成 | 95% | 和谐殿堂四大模块（乐器调优/乐理研习/调式风格/声学降噪）+ 共鸣碎片货币 + 存档联动 |
| 游戏流程 | ✅ 核心完成 | 85% | 完整流程 + 碰撞层配置 + 调式集成 + Boss战触发流程已完成 |

---

## 第一章垂直切片开发状态

> *基于《Chapter1_Dev_Plan.md》的垂直切片开发已于 2026-02-10 完成。*

### 已完成 ✅

- [x] **Milestone 1: 核心系统改造** — *2026-02-10 完成*
  - 创建 `WaveData.gd` 资源类型
  - 改造 `EnemySpawner.gd` 增加剧本模式（`play_scripted_wave()` / `resume_random_spawning()` / `_process_scripted_wave()`）
  - 改造 `ChapterManager.gd` 增加剧本调度器
  - 改造 `enemy_base.gd` 增加 `initialize_scripted()` 方法
  - 在 `ChapterData.gd` 中为 CH1 配置 `scripted_waves` 调度表
- [x] **Milestone 2-4: 波次实现** — *2026-02-10 完成*
  - 6个剧本波次数据文件（`wave_1_1.gd` ~ `wave_1_6.gd`）
  - 分别对应“初识节拍”、“音符差异”、“完美卡拍”、“休止符的力量”、“附点节奏”、“综合运用”
- [x] **Milestone 5: Boss 战** — *2026-02-10 完成*
  - 完整重写 `boss_pythagoras.gd`
  - 两阶段设计（简单图形/复杂图形）
  - 六种攻击模式：八度共振/五度震荡/节拍考验/四度叠加/不和谐脉冲/终焉和弦
  - 和谐护盾机制 + 风格排斥（噪音惩罚）系统
  - 克拉尼图形视觉系统
- [x] **美术资源** — *2026-02-10 完成*
  - `ChladniPattern.gdshader`（克拉尼图形Shader）
  - `RhythmIndicator.gd`（节拍指示器UI）
  - `TutorialHintManager.gd`（非侵入式教学提示管理器）

### 待完成 🔲

- [ ] 为 `RhythmIndicator.gd` 创建对应的 `.tscn` 场景文件
- [ ] 为 `TutorialHintManager.gd` 创建对应的 `.tscn` 场景文件
- [ ] 精细调优 `ChladniPattern.gdshader` 的视觉参数
- [ ] 为 Boss 毕达哥拉斯设计专属的多层旋转光环精灵/动画
- [ ] 集成测试所有视觉效果在 60 FPS 下的性能表现

---

## 法术构建系统 (SpellcraftSystem)

### 已完成 ✅

- [x] 16拍序列器 (4小节 × 4拍)
- [x] 7个白键音符，每个有独立四维属性 (DMG/SPD/DUR/SIZE)
- [x] 5个黑键修饰符 (穿透/追踪/分裂/回响/散射)
- [x] **黑键双重身份（基础）**：和弦缓冲窗口内参与和弦构建，否则作为修饰符 (Issue #18) — *v2.0*
- [x] 和弦构建缓冲区 (0.3秒窗口)
- [x] 9种基础和弦 → 9种法术形态映射
- [x] 6种扩展和弦 → 6种传说法术形态映射
- [x] **6种节奏型识别与行为修饰** (连射/重击/闪避射击/摇摆弹道/三连发/精准蓄力) — *v2.0*
- [x] **手动施法槽** (3槽，带冷却，八分音符精度对齐，时机奖励+15%) — *v2.0*
- [x] **和弦进行效果完整实现** — *v2.0*
  - D→T: 爆发治疗（低血量）或全屏伤害（高血量），受完整度加成
  - T→D: 增伤Buff（下一法术伤害翻倍），受完整度加成
  - PD→D: 全体手动施法槽冷却缩减50%，受完整度加成
- [x] 音色系统接口 (切换音色、疲劳代价)
- [x] **单音寂静检查集成** — *v2.0*
- [x] **密度过载精准度惩罚集成** — *v2.0*
- [x] **不和谐法术缓解单调值的交互** — *v2.0*
- [x] **调式系统集成** — *v3.0 新增*
  - 调式不可用音符自动跳过
  - 调式伤害倍率应用
  - 多利亚自动回响被动
  - 布鲁斯暴击被动
  - 五声音阶不和谐度减半
- [x] **留白奖励集成** — *v3.0 新增*
  - 休止符记录 → FatigueManager.record_rest()
  - 施法时重置休止符计数 → FatigueManager.reset_rest_counter()
- [x] **系统重置接口** (含调式重置) — *v3.0 完善*
- [x] **序列器 UI 拖拽编辑交互** — *v5.2 新增*
  - 从调色板拖拽音符到序列器
  - 序列器内音符拖拽移动
  - 拖拽目标位置预览
- [x] **序列器预设模板系统** — *v5.2 新增*
  - 6种节奏型预设模板（连射/重击/闪避/蓄力/三连/摇摆）
  - 一键填充到空小节
- [x] **序列器快捷键体系** — *v5.2 新增*
  - Q/W/E 切换编辑模式
  - 1-7 快捷选择音符
  - H 显示快捷键覆盖层
  - Ctrl+C/V/Z/Y 复制粘贴撤销重做
- [x] **和弦炼成台面板** (chord_alchemy_panel.gd) — *v5.2 新增，替代旧版 chord_builder_panel*
  - 音符库存拖拽放入原材料槽
  - 实时和弦识别预览
  - 法术形态/伤害倍率/不和谐度效果预览
  - 和弦进行引导（功能推荐）
  - 合成后音符永久消耗，和弦法术入法术书
- [x] **音符库存UI** (note_inventory_ui.gd) — *v5.2 新增*
  - 显示7种白键音符的持有数量
  - 支持拖拽音符到序列器/炼成台
- [x] **法术书UI** (spellbook_ui.gd) — *v5.2 新增*
  - 展示所有已合成的和弦法术
  - 支持拖拽到序列器或手动施法槽

### 待完成 🔲

- [x] 序列器 UI 的拖拽编辑交互 — *v5.2 已完成*
- [ ] 音色切换的快捷键绑定 (UI 已在 v4.0 完成)
- [ ] ⚬ **扩展和弦形态（九/十一/十三和弦等6种）** — 数值文档已定义，高级法术形态未实现
- [ ] 🔲 **黑键双重身份完善** — 作为和弦构成音来改变和弦性质的功能未完全实现
- [ ] 🔲 **节奏型行为修饰完善** — 摇摆弹道、闪避射击等行为修饰未完全应用到弹体

---

## 音符经济与升级系统

> *基于 Feature_Completeness_Report v3.0 确认，音符经济系统、和弦炼成系统、五度圈罗盘升级系统均已完整实现。*

### 音符经济系统 (NoteInventory) ✅ 已完成

- [x] NoteInventory 自动加载脚本 (`scripts/autoload/note_inventory.gd`) — 含库存管理、装备/卸下、法术书、信号系统
- [x] 库存 HUD 显示 (`scripts/ui/note_inventory_ui.gd`) — 紧凑横向条，显示7种白键音符数量，含获取闪烁动画
- [x] 法术书 UI (`scripts/ui/spellbook_ui.gd`) — 可滚动列表，显示和弦法术状态
- [x] SpellcraftSystem 集成 — 序列器编辑时调用 equip/unequip，reset 时归还所有音符
- [x] GameManager 集成 — 升级时自动发放随机音符，重置时清空库存
- [x] project.godot 注册 — NoteInventory 注册为自动加载，位于 SpellcraftSystem 之前

### 和弦炼成系统 (ChordAlchemy) ✅ 已完成

- [x] 炼成台 UI 面板 (`scripts/ui/chord_alchemy_panel.gd`) — 6个炼成槽，拖拽操作，实时预览
- [x] 和弦识别引擎 — 基于半音音程的模式匹配，支持11种和弦类型
- [x] 法术形态映射 — 每种和弦对应唯一法术形态和效果描述
- [x] 音符永久消耗 — 合成后音符不可逆消耗
- [x] 法术书存储 — 和弦法术以 Dictionary 形式存入 spellbook 数组

### 五度圈罗盘升级系统 (CircleOfFifthsCompass) ✅ 已完成

- [x] 五度圈罗盘 UI (`scripts/ui/circle_of_fifths_upgrade.gd`) — 12刻度圆盘，指针旋转动画，出现动画
- [x] 三方向选项生成 — 顺时针/当前/逆时针三个升级池独立抽取
- [x] 升级池内容 — 共24种升级，含4种稀有度
- [x] 调性注入 — 音符属性升级自动绑定当前调性
- [x] 音符获取集成 — 升级基础奖励 + 选项内音符获取
- [x] GameState 联动 — 监听 UPGRADE_SELECT 状态自动弹出

### 手动施法惩罚机制 ✅ 已完成

- [x] `trigger_manual_cast()` 已正确应用寂静 (silence) 和密度 (density) 惩罚 — *Verification_Summary_Report 确认*
- [x] 手动施法槽配置 UI (`scripts/ui/manual_slot_config.gd`) — 3个槽位图标，显示内容和冷却进度
- [x] 音符/和弦法术绑定 + 右键清空 + SpellcraftSystem 联动

---

## 听感疲劳系统 (FatigueManager)

### 已完成 ✅

- [x] 八维 AFI 计算 (音高熵/转移熵/节奏熵/和弦多样性/模式递归/密度/留白缺失/持续压力)
- [x] 滑动窗口 + 指数时间衰减
- [x] 五级疲劳等级 (NONE/MILD/MODERATE/SEVERE/CRITICAL)
- [x] 三种惩罚模式 (WEAKEN/LOCKOUT/GLOBAL_DEBUFF)
- [x] **单音寂静惩罚** — *v2.0*
  - 短窗口(8秒)内同一音符使用 ≥4次 → 该音符暂时禁用
  - 基础寂静时间3秒 + 每多用1次额外+1秒
  - 受单调抗性升级减免
- [x] **密度过载惩罚** — *v2.0*
  - 3秒内施法次数超过动态阈值 → 弹体精准度下降
  - 轻度过载：0.3弧度散射偏移 / 严重过载：0.6弧度散射偏移
  - 阈值随BPM动态调整，受密度抗性升级加成
- [x] **不和谐值连接** — *v2.0*
  - 不和谐法术直接扣血 (生命腐蚀)
  - 不和谐度 > 2.0 时触发
- [x] **不和谐法术缓解单调值** — *v2.0*
- [x] **留白奖励机制** — *v3.0 新增*
  - 连续2个休止符触发"留白清洗"
  - 减少所有被寂静音符的剩余时间 (1.5秒/次)
  - 减少总体疲劳度 (0.03/次)
  - 缓解密度过载 (精准度惩罚 -0.15)
  - 信号：rest_cleanse_triggered
- [x] 每个音符的独立疲劳度查询
- [x] 恢复建议系统
- [x] 外部疲劳注入/减少接口
- [x] 升级抗性接口
- [x] **系统重置接口** (含留白计数器重置) — *v3.0 完善*

### 待完成 🔲

- [ ] 调优：单音寂静触发阈值的平衡性测试
- [ ] 调优：密度过载阈值与 BPM 的动态关系微调
- [ ] 疲劳等级变化时的视觉/音效反馈增强
- [ ] 🔲 **疲劳滤镜视觉连接** — Shader 已编写，但未与 AFI 值完全连接以实现三级视觉效果
- [ ] 🔲 **恢复建议 UI 连接** — FatigueManager 已有建议生成逻辑，但未连接到 HUD 显示
- [ ] 🔲 **不和谐值生命腐蚀连接** — 伤害逻辑已实现，但未与和弦施放流程完全连接

---

## 召唤系统 (SummonManager)

> *基于 Feature_Completeness_Report v3.0 及 Grey_Area_Verification_Report 确认，召唤系统已在 v7.0 中完整实现。*

### 已完成 ✅

- [x] **v7.0 双模式架构** (`summon_manager.gd`) — 兼容旧的音色驱动召唤 + 基于7种根音的构造体系统
- [x] **小七和弦触发链路** — SpellcraftSystem 识别 MINOR_7 → SpellForm.SUMMON → SummonManager 信号连接 — *Grey_Area_Verification_Report 确认已完全集成*
- [x] **共鸣网络** — 召唤物之间的共鸣交互机制
- [x] **玩家指挥机制** — 玩家可指挥召唤物行为
- [x] **召唤物音频集成** — SummonAudioController + SummonAudioProfile — *OPT07 实现*

### 待完成 🔲

- [ ] 召唤物的视觉效果增强
- [ ] 召唤物与更多系统的深度交互（如特定Boss战中的作用）

---

## 调式系统 (ModeSystem)

> *v3.0 新增模块*

### 已完成 ✅

- [x] **4种调式定义与实际影响** — *v3.0 新增*
  - 伊奥尼亚 (均衡者): 全套白键 (CDEFGAB)，无特殊被动
  - 多利亚 (民谣诗人): 全套白键，每3次施法自动附加回响修饰符
  - 五声音阶 (东方行者): 仅 CDEGA，剩余音符伤害+20%，不和谐度减半
  - 布鲁斯 (爵士乐手): 全套白键，不和谐值转化为暴击率 (每点+3%，上限30%)
- [x] **可用白键限制** (五声音阶移除 F 和 B)
- [x] **调式伤害倍率** (五声音阶 1.2x)
- [x] **调式不和谐度倍率** (五声音阶 0.5x)
- [x] **多利亚自动回响被动** (每3次施法自动附加 ECHO 修饰符)
- [x] **布鲁斯暴击被动** (不和谐度 → 暴击率转化，暴击伤害2x)
- [x] **与 SpellcraftSystem 完整集成** (音符可用性检查、伤害倍率、被动效果)
- [x] **与 GameManager 完整集成** (start_game/reset_game 时应用/重置调式)
- [x] **信号系统** (mode_changed, crit_from_dissonance)

- [x] **角色/职业系统基础实现** (Issue #28) — *v7.0 新增*
  - character_class.gd: 4种职业完整数据定义（属性修正、被动能力、初始序列器、视觉配置、解锁条件、背景故事）
  - character_class_manager.gd: 职业管理器（属性应用、序列器配置、视觉风格、被动更新）
  - main_game.tscn/gd: 集成 CharacterClassManager 节点

### 待完成 🔲

- [ ] 更多调式/职业解锁 (如利底亚、混合利底亚)
- [ ] 调式选择界面的视觉增强
- [ ] 角色专属动画和音效

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

- [x] 调性感知：根据当前调式动态调整和弦功能判定 (OPT04 已实现)
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
- [x] **密度过载精准度惩罚** (弹体方向随机偏移) — *v2.0*
- [x] 弹体发光 Shader (projectile_glow.gdshader)
- [x] 空间哈希碰撞优化 (SpatialHash)
- [x] **摇摆弹道 (SWING) S型正弦轨迹** — *v3.0 新增*
  - 正弦波垂直偏移 (振幅20px, 频率3Hz)
  - 弹体存活时间内持续摇摆
- [x] **弹体拖尾效果 (Trail)** — *v3.0 新增*
  - 摇摆弹体：8帧拖尾历史
  - 普通弹体：4帧短拖尾
  - 渐变透明度渲染

### 待完成 🔲

- [ ] 法阵/区域 (FIELD) 弹体形态
- [ ] 天降打击 (DIVINE_STRIKE) 弹体形态
- [ ] 护盾/治疗 (SHIELD_HEAL) 弹体形态
- [ ] 召唤/构造 (SUMMON) 弹体形态
- [ ] 扩展和弦法术的6种弹体形态

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
- [x] 经验值掉落 + 死亡特效 + 敌人 Shader

### 待完成 🔲

- [ ] ⚬ **6种章节特色敌人** — 《关卡与Boss设计》中定义的新敌人类型尚未实现
  - 唱诗班 (Choir) — 第二章特色敌人
  - 对位爬虫 (Counterpoint Crawler) — 第三章特色敌人
  - 小步舞者 (Minuet Dancer) — 第四章特色敌人
  - 命运叩门者 (Fate Knocker) — 第五章特色敌人
  - 即兴歌手 (Scat Singer) — 第六章特色敌人
  - 比特破碎虫 (Bitcrusher Worm) — 第七章特色敌人
- [ ] 更多敌人变体 (如 Echo 回声敌人、Feedback 反馈敌人)
- [ ] 敌人属性随时间/BPM 动态缩放
- [ ] 敌人与疲劳系统的更深交互

---

## Boss 系统

### 已完成 ✅

- [x] **Boss 基类框架** (boss_base.gd) — 多阶段状态机、攻击模式管理器、护盾系统、脆弱状态、狂暴模式、音乐联动
- [x] **失谐指挥家** (boss_dissonant_conductor.gd) — 三乐章设计（不和谐序曲/混乱赋格/终章狂想）— *已归档至 `Archive/Boss_Dissonance_Conductor/`*
- [x] **Boss 生成器** (boss_spawner.gd) — 每5波触发Boss战，暂停普通敌人生成，击败后发放共鸣碎片
- [x] **Boss 血条 UI** (boss_health_bar.gd) — HP条延迟伤害动画、护盾条、阶段指示器
- [x] **Boss 战触发流程** — `chapter_manager.gd` 的 `_spawn_boss()` 已完整实现脚本加载、节点实例化、难度应用和信号连接 — *Verification_Summary_Report 确认*
- [x] **Boss 1-7 脚本文件创建** (.gd) — *v4.0 补全*
- [x] **Boss 1-7 场景文件创建** (.tscn) — *v7.0 新增*
- [x] **boss_spawner.gd 更新** (BOSS_SCENES 字典添加七大Boss场景路径) — *v7.0 新增*

### 已归档 📦

- 失谐指挥家 (Dissonance Conductor) → `Archive/Boss_Dissonance_Conductor/`
- Max_Issues_Implementation_Report.md → `Archive/`

### 待完成 🔲

- [ ] ⚬ **音乐史七大 Boss 内容实现** — 脚本/场景框架已创建，但具体战斗内容、专属机制、战前叙事等内容层面完全未实现
  - Pythagoras (律动尊者): 克拉尼图形 + 频率脉冲
  - Guido (圣咏宗师): 四线谱战场 + 唱名弹幕
  - Bach (大构建师): 赋格引擎 + 多声部模仿
  - Mozart (古典完形): 奏鸣曲式阶段 + 优雅反击
  - Beethoven (狂想者): 命运动机 + 动态力度系统
  - Jazz (切分行者): 摇摆力场 + Call & Response
  - Noise (合成主脑): 波形战争 + 单一诅咒
- [ ] Boss 战前/战后叙事对话
- [ ] Boss 专属的 BGM 资源文件 (.ogg)
- [ ] 各章节 Boss 专属的场景环境装饰视觉效果

---

## 精英敌人系统

> *8个精英敌人脚本+场景文件均已创建，核心框架完成，待完善专属机制与视觉效果。*

### 已完成 ✅ (脚本)

- [x] `elite_base.gd` — 精英敌人基类框架
- [x] `ch1_frequency_sentinel.gd` — 第一章精英：频率哨兵
- [x] `ch1_harmony_guardian.gd` — 第一章精英：和声守卫者
- [x] `ch2_cantor_commander.gd` — 第二章精英：唱诗班指挥官
- [x] `ch3_fugue_weaver.gd` — 第三章精英：赋格织者
- [x] `ch4_court_kapellmeister.gd` — 第四章精英：宫廷乐长
- [x] `ch5_symphony_commander.gd` — 第五章精英：交响指挥官
- [x] `ch6_bebop_virtuoso.gd` — 第六章精英：Bebop大师
- [x] `ch7_frequency_overlord.gd` — 第七章精英：频率霸主

### 待完成 🔲 (场景文件补全)

| 精英敌人 | 脚本(.gd) | 场景(.tscn) | 状态 |
|------|------|------|------|
| ch1_frequency_sentinel | ✅ | ✅ 已有 | 完成 |
| ch1_harmony_guardian | ✅ | ✅ 已有 | 完成 |
| ch2_cantor_commander | ✅ | ✅ 已有 | 完成 |
| ch3_fugue_weaver | ✅ | ✅ 已有 | 完成 |
| ch4_court_kapellmeister | ✅ | ✅ 已有 | 完成 |
| ch5_symphony_commander | ✅ | ✅ 已有 | 完成 |
| ch6_bebop_virtuoso | ✅ | ✅ 已有 | 完成 |
| ch7_frequency_overlord | ✅ | ✅ 已有 | 完成 |

---

## 章节敌人系统

> *13个章节敌人脚本+场景文件均已创建，章节敌人生成系统已完全集成（Grey_Area_Verification_Report 确认）。*

### 已完成 ✅

- [x] 13个章节敌人脚本已创建（位于 `scripts/entities/enemies/chapter_enemies/`）
- [x] **章节敌人生成系统已完全集成** — `enemy_spawner.gd` 的 `_preload_chapter_scripts()` 动态加载 + `chapter_manager.gd` 精确驱动 — *Grey_Area_Verification_Report 确认*
- [x] **第2-7章波次数据** — `chapter_data.gd` 中各章节的 `ENEMY_SCENE_PATHS`、`ELITE_SCENE_PATHS` 和 `get_wave_template()` 均已配置

### 场景文件状态详细列表

| 章节敌人 | 脚本(.gd) | 场景(.tscn) | 状态 |
|------|------|------|------|
| ch1_grid_static | ✅ | ✅ 已有 | 完成 |
| ch1_metronome_pulse | ✅ | ✅ 已有 | 完成 |
| ch2_choir | ✅ | ✅ 已有 | 完成 |
| ch2_scribe | ✅ | ✅ 已有 | 完成 |
| ch3_counterpoint_crawler | ✅ | ✅ 已有 | 完成 |
| ch4_minuet_dancer | ✅ | ✅ 已有 | 完成 |
| ch5_crescendo_surge | ✅ | ✅ 已有 | 完成 |
| ch5_fate_knocker | ✅ | ✅ 已有 | 完成 |
| ch5_fury_spirit | ✅ | ✅ 已有 | 完成 |
| ch6_scat_singer | ✅ | ✅ 已有 | 完成 |
| ch6_walking_bass | ✅ | ✅ 已有 | 完成 |
| ch7_bitcrusher_worm | ✅ | ✅ 已有 | 完成 |
| ch7_glitch_phantom | ✅ | ✅ 已有 | 完成 |

### 待完成 🔲

- [x] 为 10 个缺失场景文件的章节敌人创建 `.tscn` 场景 — *v9.1 已完成*
- [ ] 根据《关卡与Boss整合设计文档_v3.0.md》补全剩余章节专属敌人
- [ ] 敌人属性随时间/BPM 动态缩放

---

## 视觉与 Shader

### 已完成 ✅

- [x] 疲劳滤镜 Shader (fatigue_filter.gdshader)
- [x] 弹体发光 Shader (projectile_glow.gdshader)
- [x] 脉冲网格 Shader (pulsing_grid.gdshader)
- [x] 事件视界 Shader (event_horizon.gdshader)
- [x] 敌人故障 Shader (enemy_glitch.gdshader)
- [x] 寂静光环 Shader (silence_aura.gdshader)
- [x] **疲劳滤镜接入 HUD** (fatigue_level + beat_pulse + dissonance_level) — *v2.0*
- [x] **单音寂静视觉反馈** (被禁用音符UI灰化 + 红色闪烁 + 屏幕微震) — *v3.0 新增*
- [x] **密度过载视觉反馈** (屏幕顶部闪烁警告文字) — *v3.0 新增*
- [x] **和弦进行解决视觉反馈** (提示文字 + 颜色脉冲动画) — *v3.0 新增*
- [x] **留白清洗视觉反馈** (青色脉冲 + 滤镜短暂变亮) — *v3.0 新增*
- [x] 玩家视觉增强 + 地面网格 + 事件视界
- [x] **UI扫光Shader** (scanline_glow.gdshader) — 周期性斜向扫光效果 — *v4.0 新增*
- [x] **流动能量Shader** (flowing_energy.gdshader) — Boss血条能量流动效果 — *v4.0 新增*
- [x] **和弦进行冲击波Shader** (progression_shockwave.gdshader) — 全屏冲击波VFX — *v4.0 新增*
- [x] **调式切换边框Shader** (mode_border.gdshader) — 调式专属风格化屏幕边框 — *v4.0 新增*
- [x] **比特破碎Shader** (bitcrush.gdshader) — 第七章降采样/色彩量化/数据损坏效果 — *v4.0 新增*
- [x] **敌人死亡音符粒子** — 死亡时分解为音符形状粒子 — *v4.0 新增*
- [x] **Boss多阶段崩坏特效** — 闪烁→粒子波→最终爆发→淡出 — *v4.0 新增*
- [x] **和弦法术视觉效果** — 法阵光环、全屏冲击波、穿透震荡波反馈 — *v4.0 新增*
- [x] **法术系统视觉增强七大层级** (spell_visual_manager.gd v2.0) — *v6.0 新增*
  - 层级一：一次性修饰层（黑键修饰符）— 5种修饰符独立视觉（穿透刀锋/追踪准星/分裂电弧/回响残影/散射扇形）
  - 层级二：法术形态层（和弦法术）— 9种基础+6种扩展和弦法术全面增强（圣光金/暗蓝粘稠/烈焰橙/深紫内爆等）
  - 层级三：攻击质感层（音色系别）— 弹拨/拉弦/吹奏/打击4系施法反馈+弹体修饰
  - 层级四：行为模式层（节奏型）— 连射/重击/闪避/摇摆/三连/蓄力6种节奏型视觉反馈
  - 层级五：组合效果层（和弦进行）— D→T金色冲击波/T→D琥珀边框/PD→D紫色加速线 + 音色×和弦交互
  - 层级六：环境与惩罚层 — 单调寂静(去饱和)/噪音过载(像素化故障)/不和谐腐蚀(紫色病毒)
  - 层级七：频谱相位层（共鸣切片）— 高通(冷色调锐化)/低通(暖色调液态化)/全频切换
- [x] **修饰符视觉增强 Shader** (modifier_vfx.gdshader) — *v6.0 新增*
- [x] **音色弹体质感 Shader** (timbre_projectile.gdshader) — *v6.0 新增*
  - 弹拨系水墨波纹 + 拉弦系缠绕丝线 + 吹奏系半透明气流 + 打击系坚实方形
- [x] **频谱相位全局后处理 Shader** (spectral_phase.gdshader) — *v6.0 新增*
  - 高通：冷色调偏移 + 亮度提升 + 边缘锐化
  - 低通：暖色调偏移 + 亮度降低 + 轻微模糊
- [x] **惩罚效果后处理 Shader** (penalty_effects.gdshader) — *v6.0 新增*
  - 噪音过载：像素化 + 色差分离
  - 不和谐腐蚀：紫色边缘光 + 脉冲
  - 单调寂静：去饱和 + 灰暗
- [x] **和弦进行全屏增强 Shader** (chord_progression_vfx.gdshader) — *v6.0 新增*
  - D→T：金色冲击波 + 暖色调染色
  - T→D：琥珀色边框收缩 + 鱼眼畸变
  - PD→D：紫色径向加速线条
- [x] **全局VFX管理器增强** (vfx_manager.gd v2.0) — *v6.0 新增*
  - 频谱相位全局后处理切换
  - 惩罚效果全局后处理（自然衰减）
  - 和弦进行增强全屏特效

### 待完成 🔲

- [ ] 障碍物 "固化静默" 视觉
- [ ] 各章节Boss专属血条容器纹理
- [ ] 玩家受击时的屏幕抖动与边缘红色渐变反馈

---

## UI 系统

### 已完成 ✅

- [x] HUD 主界面 (hud.gd) — 血条/疲劳度/BPM/时间/等级
- [x] 疲劳仪表 (fatigue_meter.gd)
- [x] 伤害数字系统 (damage_number.gd + damage_number_manager.gd)
- [x] 弹药环 HUD / 序列器 UI / 升级面板 / 暂停菜单 / 设置菜单
- [x] 局结算界面 / 和谐殿堂 UI / 性能监控
- [x] 恢复建议文字显示 (带淡出动画)
- [x] **手动施法槽冷却 UI** (覆盖层从上到下缩小表示冷却进度) — *v3.0 新增*
- [x] **单音寂静灰化指示** (7个白键对应的灰化/红色闪烁标记) — *v3.0 新增*
- [x] **密度过载警告指示器** (屏幕顶部橙红色闪烁文字) — *v3.0 新增*
- [x] **和弦进行效果提示** (D→T/T→D/PD→D + 效果描述 + chain计数) — *v3.0 新增*
- [x] **调式信息显示** (调式名称 + 副标题 + 可用键位) — *v3.0 新增*
- [x] **布鲁斯暴击率显示** (仅布鲁斯调式可见) — *v3.0 新增*
- [x] **留白清洗提示** (青色脉冲文字 + 音效 + 滤镜变亮) — *v3.0 新增*
- [x] **全局UI色彩规范** (ui_colors.gd) — 统一调色板单一事实来源 — *v4.0 新增*
- [x] **UI动画辅助工具** (ui_animation_helper.gd) — 按钮交互增强/面板入场/节拍脉动/故障闪烁 — *v4.0 新增*
- [x] **全局VFX管理器** (vfx_manager.gd) — 冲击波/调式边框/全屏闪光/Boss阶段转换 — *v4.0 新增*
- [x] **Boss血条主题化** — 流动能量Shader + 专属容器纹理 + 阶段转换动画 — *v4.0 新增*
- [x] **主菜单优化** — 统一调色板 + 入场动画 + VBoxContainer布局 — *v4.0 新增*
- [x] **和谐殿堂重构** — "神圣音乐工作站"布局 + 机架模块化标签页 — *v4.0 新增*
- [x] **谐振法典重构** — "魔法书"视觉风格 + 翻页动画 + 星图纹理背景 — *v4.0 新增*
- [x] **结算界面增强** — 统一调色板 + 评价等级差异化背景特效 (S级金/D级红) — *v4.0 新增*
- [x] **游戏结束界面统一调色板** — 应用全局色彩规范 — *v4.0 新增*
- [x] **升级面板增强** — 稀有度颜色视觉区分 (普通/稀有/史诗/传说) — *v4.0 新增*
- [x] **音色切换 UI** (timbre_wheel_ui.gd) — 轮盘式选择界面 — *v4.0 新增*
- [x] **序列器 UI 交互优化** (sequencer_ui.gd v3.0) — *v5.2 新增*
  - 增强模式切换按钮（图标+文字+快捷键提示+动画反馈）
  - 预设模板系统（6种节奏型模板一键填充）
  - 实时节奏型预览（编辑时即时显示效果说明）
  - 小节级批量操作（右键菜单：复制/清空/填充/模板）
  - 增强音符信息面板（四维属性条形图+音符描述）
  - 拖拽交互增强（调色板拖入+音符移动+目标预览）
  - 快捷键覆盖层（按H显示所有快捷键）
  - 增强工具提示（多行信息+操作提示）
- [x] **和弦炼成台面板** (chord_alchemy_panel.gd) — *v5.2 新增，替代旧版 chord_builder_panel*
  - 音符库存拖拽放入原材料槽
  - 实时和弦类型识别预览
  - 法术形态/伤害倍率/不和谐度效果预览
  - 和弦功能判定（T/PD/D）可视化
  - 和弦进行引导（推荐下一个和弦功能）
  - 合成后音符永久消耗，和弦法术入法术书
  - 扩展和弦标记与解锁状态显示
- [x] **音符库存UI** (note_inventory_ui.gd) — *v5.2 新增*
  - 显示7种白键音符的持有数量
  - 支持拖拽音符到序列器/炼成台
- [x] **法术书UI** (spellbook_ui.gd) — *v5.2 新增*
  - 展示所有已合成的和弦法术
  - 支持拖拽到序列器或手动施法槽

### 待完成 🔲

- [x] 序列器 UI 的拖拽编辑交互 — *v5.2 已完成*
- [ ] 和谐殿堂各模块的详细交互实现 (旋钮/推子/技能树)
- [ ] 谐振法典的完整数据填充和条目详情页

---

## 音频系统

### 已完成 ✅

- [x] 音符合成器 (note_synthesizer.gd) — 12半音实时合成
- [x] ADSR 包络 + 5种音色系别 + 泛音结构
- [x] 全局音乐管理器 / BGM 管理器 / 音效管理器
- [x] 频谱分析接入 + 音频总线布局
- [x] **单音寂静音效** (低沉下行音 + 消音) — *v3.0 新增*
- [x] **密度过载音效** (电流干扰 + 警告嵼嵼声) — *v3.0 新增*
- [x] **暴击音效** (布鲁斯调式专用：明亮金属撞击 + 上行音阶) — *v3.0 新增*
- [x] **留白清洗音效** (柔和"叮"声 + 上行纯音) — *v3.0 新增*
- [x] **信号自动连接** (spell_blocked_by_silence → 寂静音效, accuracy_penalized → 过载音效, is_crit → 暴击音效) — *v3.0 新增*
- [x] **OPT01: 全局动态和声指挥官** (Global Dynamic Harmony Conductor) — *v8.0 新增*
  - BGMManager 升级为和声指挥官，维护全局和弦上下文
  - 玩家和弦实时响应: MusicTheoryEngine.chord_identified → 小节边界同步切换 Pad/Bass 声部
  - 马尔可夫链自动演进: 玩家静默 2 小节后自动生成符合调式的和弦进行
  - 全局和声上下文广播: harmony_context_changed 信号供下游系统监听
  - 公共查询 API: get_current_chord(), get_current_scale(), quantize_to_scale()
  - MusicData 新增马尔可夫链转移概率矩阵、音高频率映射表
- [x] **OPT02: 法术音效相对音高系统** (Relative Pitch System) — *v8.1 新增*
  - 新增 RelativePitchResolver 核心解析器：度数解析、和弦音吸附、MIDI/频率转换、pitch_scale 计算
  - AudioManager 集成：_on_spell_cast 和 _on_chord_cast 接入相对音高，确保法术音效与 BGM 和谐
  - SpellcraftSystem 扩展：spell_data 新增 pitch_degree 和 white_key 字段
  - MusicData 新增 WHITE_KEY_PITCH_DEGREE、DEGREE_FUNCTION_ROLES、SCALE_DEFINITIONS、build_scale()
- [x] **OPT04: 章节调性进化系统** (Chapter-Based Tonality Evolution) — *v8.2 新增*
  - 7章调式演进: Ionian → Dorian → Mixolydian → Phrygian → Locrian → Blues → Chromatic
  - 共同音过渡算法: 旧音阶与新音阶的共同音作为 2 小节过渡桥梁
  - 7套独立马尔可夫链矩阵: 每种调式独立的和声进行概率
  - ChapterManager 直接调用 BgmManager.set_tonality() 确保可靠切换
  - 所有回退值从 A 小调统一更新为 C 大调 (Ch1 Ionian)

- [x] **召唤物音频配置资源** (summon_audio_profile.gd) — *OPT07 新增*
  - 7种构造体音色配置（Pluck/Delay Echo/Gate Pulse/Sweep/Sub-Bass/Pad/Hi-hat）
  - 触发模式枚举（PER_BEAT/PER_STRONG_BEAT/PER_SIXTEENTH/ON_EVENT/SUSTAINED）
  - 音高策略枚举（CHORD_ROOT/CHORD_ARPEGGIO/CHORD_FIFTH/SCALE_DESCEND/CHORD_FULL/NO_PITCH）
  - 静态工厂方法 `get_profile_for_root()` 统一映射
- [x] **召唤物音频控制器** (summon_audio_controller.gd) — *OPT07 新增*
  - 程序化音色合成引擎（7种音色）
  - 节拍信号自动连接（sixteenth_tick/bgm_beat_synced）
  - 和声上下文感知（实时音高量化）
  - 空间化播放（AudioStreamPlayer2D）
- [x] **BgmManager 和声指挥官 API** — *OPT07 新增*
  - `sixteenth_tick` 和 `harmony_context_changed` 信号
  - `get_current_chord()` / `get_current_scale()` / `quantize_to_scale()` API
  - 和弦进行表（Am → G → F → Em 循环）
- [x] **构造体音频集成** (summon_construct.gd) — *OPT07 新增*
  - `_ready()` 自动初始化 SummonAudioController
  - 行为触发/激励/淡出时同步音频事件
- [x] **OPT02-OPT08 全部已完全集成** — *Grey_Area_Verification_Report 确认*
  - OPT02: 相对音高系统 (`relative_pitch_resolver.gd`)
  - OPT03: 敌人音乐身份 (`enemy_audio_controller.gd`)
  - OPT04: 章节调性演化 (`bgm_manager.gd`)
  - OPT05: Rez风格量化 (`audio_event_queue.gd`)
  - OPT06: 空间音频 (`spatial_audio_controller.gd`)
  - OPT07: 召唤物音乐性 (`summon_audio_controller.gd`)
  - OPT08: 程序化音色合成 (`synth_manager.gd`)

### 待完成 🔲

- [ ] 和弦音效 (多音符同时播放)
- [ ] BGM 与疲劳等级的动态混音
- [ ] 实际 BGM 音频文件 (.ogg)

---

## 局外成长 (SaveManager)

> *基于 Max_Issues_Implementation_Report (Issue #31) 确认，局外成长系统已完整实现，和谐殿堂四大模块均已落地。*

### 已完成 ✅

- [x] **和谐殿堂四大模块** — *Issue #31 完成*
  - 模块A: 乐器调优 (Instrument Tuning) — 5种基础属性永久升级
  - 模块B: 乐理研习 (Theory Archives) — 解锁型升级，含前置条件树
  - 模块C: 调式风格 (Mode Mastery) — 4种调式选择，各有独特被动效果
  - 模块D: 声学降噪 (Acoustic Treatment) — 疲劳系统缓解升级
- [x] **共鸣碎片货币系统** — 局结算自动计算奖励（存活时间/击杀数/Boss击败/等级/高和谐度加成）
- [x] **调式/职业选择** (4种) — 通过 ModeSystem 实现对游戏玩法的实际影响
- [x] **局结算奖励** / 存档持久化 (`ConfigFile` → `user://meta_progression.cfg`) / 局外加成应用
- [x] **和谐殿堂 UI** (`scripts/ui/hall_of_harmony.gd`) — “神圣音乐工作站”布局 + 机架模块化标签页
- [x] **局结算界面** (`scripts/ui/run_results_screen.gd`) — 评价等级差异化背景特效

### 待完成 🔲

- [ ] 和谐殿堂各模块的详细交互实现 (旋钮/推子/技能树)
- [ ] 更多调式/职业解锁
- [ ] 成就系统

---

## 游戏流程

### 已完成 ✅

- [x] 主菜单 → 游戏 → 结算 完整流程
- [x] 游戏开始 — 重置状态 + 应用局外加成 + **应用调式系统** — *v3.0 完善*
- [x] 游戏暂停/恢复 / 游戏结束 / 重试/返回菜单
- [x] **游戏重置** — 重置所有子系统 (含 ModeSystem) — *v3.0 完善*
- [x] 竞技场边界限制 / 碰撞检测 / 玩家无敌帧 / 闪避机制
- [x] **不和谐伤害连接** — *v2.0*
- [x] **碰撞层配置文档** (collision_layers.md) — *v3.0 新增*
- [x] **Boss 战触发流程** — `chapter_manager.gd` 的 `_spawn_boss()` 已完整实现 — *Verification_Summary_Report 确认*

### 待完成 🔲

- [ ] 新手引导/教程关卡
- [ ] 难度选择
- [ ] 每局随机事件/变异器
- [ ] 计时里程碑 (5分钟/10分钟/15分钟 Boss 出现)

---

## 性能优化

### 已完成 ✅

- [x] MultiMesh 弹体批量渲染
- [x] 对象池 (弹体、伤害数字、死亡特效碎片、音效播放器)
- [x] 空间哈希碰撞优化 / 碰撞检测频率控制
- [x] 音效冷却系统

### 待完成 🔲

- [ ] 大量敌人时的性能测试与优化
- [ ] 敌人对象池
- [ ] MultiMesh 高负载验证 (2000+弹体)

---

## 技术债务

> *基于 2026-02-12 项目评估报告发现的技术债务问题。需要在后续开发中逐步解决。*

### 信号连接问题

项目中存在大量信号声明（~206个）和连接调用（~1016处），部分信号存在以下问题：

- [ ] **信号审计**: 全面审计所有 `signal` 声明与 `connect`/`emit` 调用的匹配情况，识别未连接的信号
- [ ] **历史修复残留**: v4.1/v5.1 修复过多个信号连接问题（InvincibilityTimer、PickupArea、player_damaged 等），需确认是否还有类似问题残留
- [ ] **场景树信号连接验证**: 检查所有 `.tscn` 文件中的信号连接是否有效（目标节点是否存在、方法名是否正确）
- [ ] **自动化信号连接测试**: 创建脚本自动检测信号声明与连接的不匹配

### 孤岛代码问题

部分脚本文件缺少对应的场景文件，导致代码无法被游戏实际使用：

- [x] **精英敌人场景补全**: 8个精英敌人脚本均无场景文件，代码处于孤岛状态 — *v9.1 已完成*
- [x] **章节敌人场景补全**: 10个章节敌人脚本缺少场景文件 — *v9.1 已完成*
- [ ] **未使用脚本清理**: 审计所有脚本文件，识别并清理未被任何场景引用的孤立脚本
- [ ] **场景引用完整性检查**: 验证所有 `.tscn` 文件中引用的脚本路径是否有效

### 其他技术债务

- [ ] **听感疲劳惩罚机制完善**: 疲劳系统已实现三维惩罚，但实际游戏体验中的惩罚强度和触发阈值尚未经过充分测试
- [ ] **文档与代码同步**: 部分设计文档描述的功能与实际代码实现存在差异（如 Feature_Completeness_Report.md 中记录的多项差距）
- [ ] **Godot 4.6 兼容性检查**: 确保所有代码均兼容 Godot 4.6 API

---

## 待设计/待讨论

- [ ] 多人合奏模式
- [ ] 排行榜系统
- [ ] Steam 成就集成
- [ ] 自定义序列器预设保存/分享
- [ ] 回放系统 (记录每局的"乐谱")
- [ ] 障碍物系统 ("固化静默" 黑色玄武岩柱体)

---

## 文件变更日志

### 2026-02-12 v10.0 TODO.md 全面同步更新（基于权威报告结论）

**更新依据：**
- Feature_Completeness_Report.md v3.0
- Grey_Area_Verification_Report.md
- Verification_Summary_Report.md
- Max_Issues_Implementation_Report.md

**已完成项状态更新：**

| 功能 | 更新内容 |
|------|------|
| Boss 敌人设计与实现 | ✅ boss_base.gd + 失谐指挥家已完成，Boss战触发流程已完成 |
| 局外成长系统 | ✅ 和谐殿堂四大模块已完成 |
| 听感疲劳核心机制 | ✅ 单音寂静 + 密度过载已完成 |
| 召唤系统 | ✅ v7.0 双模式架构已完成 |
| 和弦进行效果 | ✅ D→T/T→D/PD→D 全部实现 |
| 手动施法惩罚 | ✅ 寂静+密度惩罚已正确应用 |
| 音符经济系统 | ✅ NoteInventory 完整实现 |
| 和弦炼成系统 | ✅ 11种和弦模式 + 炼成台UI |
| 五度圈罗盘升级 | ✅ 24种升级 + 三方向选项 |
| 章节敌人生成系统 | ✅ 已完全集成 |
| OPT02-OPT08 优化模块 | ✅ 全部已完全集成 |
| 第2-7章波次数据 | ✅ chapter_data.gd 已配置 |

**新增待办项：**

| 功能 | 状态 | 说明 |
|------|------|------|
| 扩展和弦形态（九/十一/十三和弦等6种） | ⚬ 未实现 | 数值文档已定义，高级法术形态未实现 |
| 黑键双重身份 | 🔲 部分完成 | 作为和弦构成音改变和弦性质未完全实现 |
| 节奏型行为修饰 | 🔲 部分完成 | 摇摆弹道、闪避射击等未完全应用到弹体 |
| 疲劳滤镜视觉连接 | 🔲 部分完成 | Shader已编写，未与AFI值完全连接 |
| 恢复建议 UI 连接 | 🔲 部分完成 | 建议生成逻辑已有，未连接到HUD |
| 不和谐值生命腐蚀连接 | 🔲 部分完成 | 伤害逻辑已实现，未与和弦施放流程完全连接 |
| 6种章节特色敌人 | ⚬ 未实现 | 设计文档已定义，代码未实现 |
| 音乐史七大 Boss 内容 | ⚬ 未实现 | 脚本/场景框架已创建，内容层面未实现 |

**结构变更：**
- 新增「音符经济与升级系统」独立章节（含音符经济/和弦炼成/五度圈罗盘/手动施法惩罚）
- 新增「召唤系统 (SummonManager)」独立章节
- 更新核心系统状态总览表格，新增音符经济/和弦炼成/五度圈/召唤系统行
- Boss 系统完成度从 75% 调整为 40%（反映内容层面的实际状态）
- 局外成长完成度从 90% 调整为 95%（反映和谐殿堂四大模块已完成）

---

### 2026-02-12 v9.0 项目文档同步与TODO全面更新 (Issue #94)

**文档更新：**

| 文档 | 变更内容 |
|------|------|
| `godot_project/TODO.md` | 新增第一章垂直切片状态、精英敌人系统、章节敌人系统、技术债务章节；更新Boss系统状态 |
| `ProjectHarmony-项目待办事项.md` | 标记任务3完成；新增基于评估报告的待办任务；更新依赖关系 |
| `DOCUMENTATION_INDEX.md` | 新增章节开发计划索引、评估报告引用；确认文档状态准确性 |
| `GDD_Evaluation_TODO_v2.md` | 移入 `Archive/` 目录 |

---

### 2026-02-12 v8.1 OPT07 召唤系统音乐性深化

**新增文件：**

| 文件 | 说明 |
|------|------|
| `scripts/entities/summon_audio_profile.gd` | 召唤物音频配置资源 — 7种构造体音色/触发模式/音高策略配置 |
| `scripts/entities/summon_audio_controller.gd` | 召唤物音频控制器 — 程序化音色合成引擎 + 节拍同步 + 和声感知 |

---

### 2026-02-12 v8.0 OPT01 全局动态和声指挥官实现

**修改文件：**

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `scripts/autoload/bgm_manager.gd` | 编辑 | OPT07: 新增 sixteenth_tick/harmony_context_changed 信号；新增和声指挥官 API（get_current_chord/get_current_scale/quantize_to_scale）；新增和弦进行系统 |
| `scripts/entities/summon_construct.gd` | 编辑 | 集成 SummonAudioController；_ready() 初始化音频控制器；行为触发/激励/淡出同步音频事件 |
| `scripts/systems/summon_manager.gd` | 编辑 | OPT07 注释；构造体信息增加 audio_info 字段 |

**文档更新：**

| 文档 | 变更内容 |
|------|------|
| `Docs/Optimization_Modules/OPT07_SummoningSystemMusicality.md` | 状态更新为“已实现”，新增实现报告章节 |
| `DOCUMENTATION_INDEX.md` | 新增优化模块章节，OPT07 标记为“已实现” |

---

### 2026-02-12 v8.0 OPT01 全局动态和声指挥官实现

**修改文件：**

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `scripts/autoload/bgm_manager.gd` | 编辑 (新增~200行) | OPT01 和声指挥官核心逻辑：玩家和弦响应、马尔可夫链自动演进、动态 Pad/Bass 声部调整、全局和声上下文广播、公共查询 API |
| `scripts/data/music_data.gd` | 编辑 (新增~130行) | 新增马尔可夫链转移概率矩阵 (A小调)、自然和弦映射、音高类到频率映射表 (Bass/Pad 八度) |
| `scripts/autoload/game_manager.gd` | 编辑 (新增2行) | reset_game() 中添加和声指挥官重置调用 |
| `Docs/Optimization_Modules/OPT01_GlobalDynamicHarmonyConductor.md` | 编辑 | 状态从“设计稿”更新为“已实现” |

---

### 2026-02-10 v6.0 法术系统视觉增强 — 七大层级全面实现

**新增文件：**

| 文件 | 说明 |
|------|------|
| `shaders/modifier_vfx.gdshader` | 修饰符视觉增强 Shader — 穿透刀锋环/追踪准星/分裂电弧/回响残影/散射扇形 |
| `shaders/timbre_projectile.gdshader` | 音色弹体质感 Shader — 弹拨水墨/拉弦丝线/吹奏气流/打击方形 |
| `shaders/spectral_phase.gdshader` | 频谱相位全局后处理 Shader — 高通冷色调/低通暖色调/全频切换 |
| `shaders/penalty_effects.gdshader` | 惩罚效果后处理 Shader — 噪音像素化/不和谐紫光/单调去饱和 |
| `shaders/chord_progression_vfx.gdshader` | 和弦进行全屏增强 Shader — D→T金色冲击波/T→D鱼眼畸变/PD→D加速线 |

**重写文件：**

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `scripts/systems/spell_visual_manager.gd` | 重写 (860→…1808行) | v2.0 全面重构：七大层级视觉增强完整实现，新增音色反馈/节奏型反馈/惩罚视觉/频谱相位切换 |
| `scripts/systems/vfx_manager.gd` | 重写 (220→440行) | v2.0 增强：新增频谱相位后处理/惩罚效果后处理/和弦进行增强特效 |

---

### 2026-02-08 v5.1 v5.0 代码审查与修复

**审查范围：** v5.0 提交的 15 个文件（3860 行新增代码），涵盖音频系统、弹体系统、UI 系统、Shader 等四大模块。详细报告见 [BUG_FIX_REPORT_v5.0_2026_02_08.md](../BUG_FIX_REPORT_v5.0_2026_02_08.md)。

**关键问题修复：**
- 受击反馈完全失效 (GameManager 缺少 player_damaged 信号)
- 和谐殿堂功能失效 (MetaProgressionManager 缺少 6 个 UI 适配方法)
- 护盾无法吸收伤害 (shield_hp 未与 GameManager.damage_player 集成)
- HitFeedbackManager 未注册为 autoload
- 图鉴解锁状态无法加载 (CodexManager 缺少 get_unlocked_entries)
- PAD_CHORDS 类型声明不兼容 Godot 4.x

**修复文件：** project.godot, game_manager.gd, meta_progression_manager.gd, codex_manager.gd, bgm_manager.gd, player.gd, enemy_base.gd, projectile_manager.gd

---

### 2026-02-08 v4.1 Bug 修复与核心模块审查

**修复概述：** 修复 20 个关键问题，涵盖 UI 页面、游戏功能完整性、信号连接、经验值系统等。详细报告见 [BUG_FIX_REPORT_2026_02_08.md](../BUG_FIX_REPORT_2026_02_08.md)。

**关键问题修复：**
- 暂停功能失效 (player.gd 与 main_game.gd 重复处理)
- 无敌帧永不解除 (InvincibilityTimer 信号未连接)
- 经验值无法拾取 (PickupArea 信号类型错误)
- 经验值双倍计算 (enemy_spawner 重复 add_xp)
- HUD 节点找不到 ManualSlots
- GameManager 缺少 is_test_mode 属性

**修复文件：** game_manager.gd, fatigue_manager.gd, player.gd, enemy_base.gd, xp_pickup.gd, enemy_spawner.gd, test_chamber.gd, main_game.gd, hud.gd, main_game.tscn, test_chamber.tscn, pause_menu.tscn

---

### 2026-02-08 v4.0 UI与美术风格优化

**新增文件：**

| 文件 | 说明 |
|------|------|
| `scripts/autoload/ui_colors.gd` | 全局UI色彩规范 — 统一调色板单一事实来源 |
| `scripts/ui/ui_animation_helper.gd` | UI动画辅助工具 — 按钮交互增强/面板入场/节拍脉动/故障闪烁 |
| `scripts/systems/vfx_manager.gd` | 全局VFX管理器 — 冲击波/调式边框/全屏闪光/Boss阶段转换 |
| `shaders/scanline_glow.gdshader` | UI扫光Shader — 周期性斜向扫光效果 |
| `shaders/flowing_energy.gdshader` | 流动能量Shader — Boss血条能量流动效果 |
| `shaders/progression_shockwave.gdshader` | 和弦进行冲击波Shader — 全屏冲击波VFX |
| `shaders/mode_border.gdshader` | 调式切换边框Shader — 调式专属风格化屏幕边框 |
| `shaders/bitcrush.gdshader` | 比特破碎Shader — 第七章降采样/色彩量化/数据损坏效果 |
| `themes/GlobalTheme.tres` | 全局UI主题资源文件 (占位) |
| `Docs/UI_Art_Style_Enhancement_Proposal.md` | UI与美术风格优化提案文档 |

**修改文件：**

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `scripts/ui/boss_health_bar.gd` | 重写 | 主题化Boss血条：流动能量Shader + 专属容器纹理 + 阶段转换动画 |
| `scripts/ui/codex_ui.gd` | 重写 | "魔法书"视觉风格：星图纹理背景 + 翻页动画 + 统一调色板 |
| `scripts/ui/hall_of_harmony.gd` | 重写 | "神圣音乐工作站"布局：机架模块化标签页 + 统一调色板 |
| `scripts/ui/run_results_screen.gd` | 编辑 | 应用全局色彩规范 |
| `scripts/scenes/game_over.gd` | 编辑 | 应用全局色彩规范 |
| `scripts/scenes/main_menu.gd` | 重写 | 统一调色板 + 入场动画 + VBoxContainer布局 |
| `scripts/systems/death_vfx_manager.gd` | 编辑 | 音符粒子死亡特效 + Boss多阶段崩坏特效 |

### 2026-02-08 v3.0 系统完善（排除敌人/Boss）

**新增文件：**

| 文件 | 说明 |
|------|------|
| `scripts/autoload/mode_system.gd` | 调式系统 — 4种调式定义、可用音符限制、伤害倍率、被动效果 |
| `collision_layers.md` | 碰撞层配置文档 — 8层碰撞矩阵定义 |

**修改文件：**

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `scripts/autoload/spellcraft_system.gd` | 编辑 | 集成调式系统（音符可用性、伤害倍率、被动效果）+ 留白奖励 |
| `scripts/autoload/fatigue_manager.gd` | 编辑 | 新增留白奖励机制（休止符清洗：减寂静/减疲劳/缓过载） |
| `scripts/autoload/game_manager.gd` | 编辑 | start_game/reset_game 集成 ModeSystem |
| `scripts/autoload/audio_manager.gd` | 编辑 | 新增4种状态音效（寂静/过载/暴击/清洗）+ 信号自动连接 |
| `scripts/ui/hud.gd` | 重写 | 全面完善：冷却UI/寂静灰化/过载警告/进行提示/调式信息/暴击率/留白反馈 |
| `scripts/systems/projectile_manager.gd` | 编辑 | 摇摆弹道S型轨迹 + 弹体拖尾效果 |

### 2026-02-08 v2.0 核心玩法完善

**修改文件：**

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `scripts/autoload/fatigue_manager.gd` | 重写 | 单音寂静、密度过载、不和谐值连接三维惩罚 |
| `scripts/autoload/spellcraft_system.gd` | 重写 | 黑键双重身份、手动施法、和弦进行效果、节奏型修饰 |
| `scripts/systems/projectile_manager.gd` | 编辑 | 密度过载精准度偏移 |
| `scripts/autoload/game_manager.gd` | 编辑 | reset_game() 重置所有子系统 |
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
