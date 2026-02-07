# Project Harmony — Godot 4.6 开发 TODO 清单

**创建日期：** 2026年2月7日
**状态标记：** ⬜ 待开发 | 🔲 部分完成 | ✅ 已完成

---

## 一、音频系统 (Audio System)

### 1.1 音符音效生成 ⬜ `P0-Critical`
**文件：** `scripts/autoload/global_music_manager.gd` (第146-158行)
**现状：** `play_note_sound()` 和 `play_ui_sound()` 为空函数（`pass`），无任何音频输出。
**需求：**
- 使用 `AudioStreamGenerator` 实现实时正弦波/方波音符合成，或加载预制 `.wav`/`.ogg` 音效文件
- 每个白键音符（C-B）需要对应频率的音效
- 和弦音效需支持多音符同时播放（复音）
- UI 音效（按钮点击、升级选择等）需要独立的音效资源

**GDD 参考：** §2.1 节奏同步战斗 — "游戏将采用节奏感强烈的音乐类型作为背景"

### 1.2 背景音乐 (BGM) ⬜ `P0-Critical`
**文件：** `scripts/autoload/global_music_manager.gd`
**现状：** 音频总线和频谱分析器框架已搭建，但无实际 BGM 资源加载和播放逻辑。
**需求：**
- 制作或引入节奏感强烈的 BGM（推荐 Electronic/Synthwave 风格）
- 实现 BGM 的加载、播放、循环控制
- BGM 的 BPM 需与 `GameManager.current_bpm` 同步
- 支持不同游戏阶段的 BGM 切换（菜单、战斗、Boss）

### 1.3 频谱分析实际接入 🔲 `P1-High`
**文件：** `scripts/autoload/global_music_manager.gd`
**现状：** `_analyze_spectrum()` 已实现频段能量提取逻辑，但依赖实际的 `SpectrumAnalyzer` 效果器实例。
**需求：**
- 在 Godot 编辑器中配置 Audio Bus "Music" 并添加 `SpectrumAnalyzer` 效果器
- 验证 `spectrum_analyzer` 实例获取是否正确
- 将频谱能量数据实际传递给 Shader（脉冲网格、弹体发光等）

---

## 二、碰撞与物理 (Collision & Physics)

### 2.1 CollisionShape 资源缺失 ⬜ `P0-Critical`
**文件：** `scenes/main_game.tscn`
**现状：** Player 和 PickupArea 的 `CollisionShape2D` 节点已创建，但未设置具体的 `Shape` 资源。
**需求：**
- 为 Player 设置 `CircleShape2D`（半径约 12px）
- 为 PickupArea 设置 `CircleShape2D`（半径约 80px，用于经验值吸收）
- 为敌人模板设置碰撞形状

### 2.2 弹体碰撞系统优化 🔲 `P1-High`
**文件：** `scripts/systems/projectile_manager.gd` (第407行)
**现状：** 使用简化的距离检测（`_check_collisions()`），逐个遍历弹体与敌人进行距离比较。
**需求：**
- 引入空间分区（如四叉树或 Godot 内置的 `PhysicsServer2D` 查询）优化碰撞检测性能
- 当同屏弹体超过 500 个时，当前 O(n×m) 复杂度将成为瓶颈
- 考虑使用 `PhysicsServer2D.space_get_direct_state()` 进行批量射线/形状查询

### 2.3 敌人碰撞层配置 ⬜ `P1-High`
**文件：** `scripts/entities/enemy_base.gd`
**现状：** 敌人脚本中引用了碰撞层，但实际的 `CollisionShape2D` 和 `Area2D` 节点需要在场景中创建。
**需求：**
- 创建敌人 PackedScene 模板（`.tscn`），包含 `CharacterBody2D` + `CollisionShape2D` + `Area2D`
- 配置碰撞层：Layer 2 (enemies)，Mask 1 (player) + 3 (player_projectiles)

---

## 三、敌人系统 (Enemy System)

### 3.1 敌人场景模板 ⬜ `P0-Critical`
**文件：** `scripts/systems/enemy_spawner.gd` (第29行)
**现状：** 注释标注 "在实际项目中，这些会是 PackedScene 引用"，当前使用代码动态创建节点。
**需求：**
- 为 4 种敌人类型（Basic, Fast, Tank, Swarm）分别创建 `.tscn` 场景文件
- 每个场景包含：`CharacterBody2D` + `Polygon2D`（锯齿碎片造型）+ `CollisionShape2D` + `Area2D`
- 在 `EnemySpawner` 中使用 `PackedScene.instantiate()` 替代动态节点创建

### 3.2 敌人 AI 行为扩展 🔲 `P2-Medium`
**文件：** `scripts/entities/enemy_base.gd`
**现状：** 所有敌人类型共享同一个简单的追踪逻辑（朝玩家方向移动）。
**需求：**
- **Fast 敌人**：增加冲刺行为（间歇性加速）
- **Tank 敌人**：增加护盾机制或减伤状态
- **Swarm 敌人**：增加群体行为（Boids 算法或简化版集群移动）
- 所有敌人增加攻击行为（近战碰撞伤害已有，需增加远程攻击变种）

### 3.3 敌人死亡特效与掉落 🔲 `P1-High`
**文件：** `scripts/entities/enemy_base.gd`
**现状：** `die()` 函数仅发出信号并调用 `queue_free()`，无视觉反馈。
**需求：**
- 实现 GDD 美术方向中的死亡效果："瞬间破碎成像素块，或像老式电视关机一样闪烁并消失"
- 生成经验值拾取物（音符符号或正四面体）
- 添加死亡音效

### 3.4 Boss 敌人 ⬜ `P3-Low`
**现状：** 完全未实现。
**需求：**
- 设计并实现至少 1 种 Boss 敌人
- Boss 应具有多阶段行为和独特的攻击模式
- Boss 战应与音乐系统深度结合

---

## 四、法术系统 (Spellcraft System)

### 4.1 小节完成时的处理逻辑 ⬜ `P1-High`
**文件：** `scripts/autoload/spellcraft_system.gd` (第232-234行)
**现状：** `_on_measure_complete()` 为空函数。
**需求：**
- 实现小节完成时的节奏型判定与应用
- 计算小节内的休止符数量，应用"精准蓄力"加成
- 触发小节级别的疲劳度更新

### 4.2 八分音符精度的手动施法 ⬜ `P1-High`
**文件：** `scripts/autoload/spellcraft_system.gd` (第228-230行)
**现状：** `_on_half_beat_tick()` 为空函数。
**需求：**
- GDD §2.3 要求手动施法对齐到八分音符精度（每小节8个施法时机）
- 实现手动施法的节拍对齐判定（允许一定的时间窗口容差）
- 手动施法应消耗手动施法槽

### 4.3 和弦进行效果触发 🔲 `P1-High`
**文件：** `scripts/autoload/spellcraft_system.gd`
**现状：** `_check_chord_progression()` 已实现功能转换检测，但实际效果（爆发治疗、伤害翻倍、冷却缩减）的执行逻辑不完整。
**需求：**
- **D→T（紧张到解决）**：实现全屏伤害或爆发治疗效果
- **T→D（稳定到紧张）**：实现"下一个法术伤害翻倍"的 buff 系统
- **PD→D（准备到紧张）**：实现全体冷却缩减效果
- 添加和弦进行触发时的视觉/音效反馈

### 4.4 扩展和弦法术形态 ⬜ `P2-Medium`
**文件：** `scripts/systems/projectile_manager.gd`
**现状：** 数据定义已完成（`music_data.gd`），但 6 种扩展和弦法术形态的实际弹体行为未实现。
**需求：**
- **风暴区域**（属九）：区域内敌人减速 30%
- **圣光领域**（大九）：领域内持续回血 2/秒
- **湮灭射线**（减九）：直线贯穿，无视防御
- **时空裂隙**（属十一）：区域内时间减速 50%
- **交响风暴**（属十三）：全屏持续 AOE + 随机元素效果
- **终焉乐章**（减十三）：延迟后全屏毁灭打击 + 施法者自损 20% HP

### 4.5 节奏型行为修饰实际应用 🔲 `P1-High`
**文件：** `scripts/autoload/spellcraft_system.gd`
**现状：** `_determine_rhythm_pattern()` 已实现简化的节奏型判定，但部分行为修饰未完全应用到弹体。
**需求：**
- **摇摆弹道**：实现 S 型/波浪形轨迹（需在 `projectile_manager.gd` 中添加正弦偏移）
- **闪避射击**：实现发射时玩家向后微小位移
- **三连发**：实现扇形散射的弹体生成
- **精准蓄力**：实现休止符对同小节其他弹体的加成累积

### 4.6 黑键作为和弦构成音 🔲 `P2-Medium`
**文件：** `scripts/autoload/spellcraft_system.gd`
**现状：** 黑键目前仅作为修饰符使用，其"作为和弦构成音改变和弦性质"的第二身份未完全实现。
**需求：**
- GDD §3.2 描述黑键拥有双重身份
- 在和弦构建窗口内，黑键输入应参与和弦类型判定
- 例如：C + E + G# 应识别为增三和弦（而非 C 大三 + G# 修饰符）

---

## 五、视觉效果 (Visual Effects)

### 5.1 玩家视觉完善 🔲 `P1-High`
**文件：** `scripts/entities/player.gd`
**现状：** 使用简单的 `Polygon2D` 六边形作为占位视觉。
**需求：**
- GDD 美术方向：正十二面体能量核心 + 三道旋转金环
- 实现节拍脉冲视觉效果（已有 `_pulse_visual()` 框架，需完善）
- 添加神圣几何 Shader 材质
- 实现受伤时的故障（Glitch）效果

### 5.2 敌人视觉完善 🔲 `P1-High`
**文件：** `scripts/entities/enemy_base.gd`
**现状：** 使用代码生成的随机锯齿多边形，无 Shader 效果。
**需求：**
- 应用故障效果 Shader（已有 `sacred_geometry.gdshader` 的 `glitch_intensity` 参数）
- 实现 12 FPS 量化步进动画的视觉表现
- 不同敌人类型应有不同的颜色和形态特征

### 5.3 伤害数字显示 ⬜ `P2-Medium`
**现状：** 完全未实现。
**需求：**
- GDD §2.2 伤害数字规范：
  - **暴击/完美节拍**：金色波纹扩散 + 故障艺术效果
  - **普通伤害**：白色像素字体，快速上浮消散
  - **不和谐伤害（自伤）**：紫色，向下流淌效果
- 创建 `DamageNumber` 场景和脚本

### 5.4 经验值拾取物 ⬜ `P1-High`
**现状：** 完全未实现。
**需求：**
- GDD §2.3 拾取物设计：漂浮的音符符号或微小正四面体
- 被玩家吸收时化作光线汇入玩家核心
- 创建 `XPPickup` 场景，包含 `Area2D` + 视觉效果 + 吸附逻辑

### 5.5 障碍物系统 ⬜ `P2-Medium`
**现状：** 完全未实现。
**需求：**
- GDD §1.2 障碍物："固化静默"— 高耸黑色玄武岩状柱体
- 表面带有均衡器频谱起伏的动态视觉效果
- 受击时短暂亮起并发出低沉共振声
- 创建 `Obstacle` 场景和 Shader

### 5.6 事件视界边界视觉接入 🔲 `P1-High`
**文件：** `shaders/event_horizon.gdshader`
**现状：** Shader 已编写，但未在主游戏场景中实际创建边界节点并应用。
**需求：**
- 在 `main_game.tscn` 中创建环形边界节点
- 应用 `event_horizon.gdshader`
- 实现玩家靠近时的画面干扰效果
- 实现碰撞阻挡（防止玩家走出边界）

### 5.7 脉冲网格地面接入 🔲 `P1-High`
**文件：** `shaders/pulsing_grid.gdshader`
**现状：** Shader 已编写，但未在主游戏场景中创建地面节点并应用。
**需求：**
- 在 `main_game.tscn` 中创建全屏地面 `ColorRect` 或 `Sprite2D`
- 应用 `pulsing_grid.gdshader`
- 将 `GlobalMusicManager.get_beat_energy()` 传递给 Shader 的 `beat_energy` 参数
- 实现玩家移动时的水波纹顶点位移效果

### 5.8 弹体 Shader 接入 🔲 `P1-High`
**文件：** `shaders/projectile_glow.gdshader`
**现状：** Shader 已编写，但 `ProjectileManager` 的 `MultiMeshInstance2D` 未应用该 Shader。
**需求：**
- 为 `MultiMeshInstance2D` 创建 `ShaderMaterial` 并应用 `projectile_glow.gdshader`
- 通过 `instance_custom_data` 传递每个弹体的颜色和能量参数
- 确保不同音符的弹体显示对应的颜色（参照 `MusicData.NOTE_COLORS`）

---

## 六、UI 系统 (User Interface)

### 6.1 序列器 UI 交互完善 🔲 `P1-High`
**文件：** `scripts/ui/sequencer_ui.gd`
**现状：** 序列器网格的绘制和播放头动画已实现，但缺少编辑交互。
**需求：**
- 实现点击/拖拽在序列器格子中放置音符
- 实现右键清除格子
- 实现和弦放置（选择多个音符后放置到整小节）
- 实现休止符放置
- 显示当前格子的音符/和弦信息 tooltip
- 实现序列器的展开/折叠动画

### 6.2 升级面板完善 🔲 `P2-Medium`
**文件：** `scripts/ui/upgrade_panel.gd`
**现状：** 基础的三选一升级面板已实现，但升级池不完整。
**需求：**
- 补充 GDD 数值文档中的全部升级项（当前仅有 12 种，GDD 描述 25+ 种）
- 实现升级稀有度的视觉区分（普通/稀有/史诗/传说）
- 实现升级描述的详细信息面板
- 添加升级选择时的音效和动画反馈
- 实现"扩展和弦解锁"传说级升级的特殊展示效果

### 6.3 暂停菜单 ⬜ `P2-Medium`
**现状：** `GameManager.pause_game()` 已实现暂停逻辑，但无暂停菜单 UI。
**需求：**
- 创建暂停菜单场景（继续、设置、退出到主菜单）
- 实现设置面板（音量调节、按键重映射）
- 暂停时显示当前游戏统计

### 6.4 弹药/冷却环形 HUD ⬜ `P2-Medium`
**现状：** 完全未实现。
**需求：**
- GDD §2.1 HUD 设计：围绕玩家核心旋转的环形刻度
- 自动施法点：亮起的光点随节拍扫过圆环
- 手动施法就绪：对应快捷键图标高亮 + 电流特效

### 6.5 设置/选项菜单 ⬜ `P3-Low`
**现状：** 主菜单的 Settings 按钮无功能。
**需求：**
- 音量控制（Master、Music、SFX）
- 分辨率和窗口模式切换
- 按键重映射
- 游戏难度选择
- 设置持久化（保存到文件）

---

## 七、听感疲劳系统 (Fatigue System)

### 7.1 疲劳滤镜 Shader 接入 🔲 `P1-High`
**文件：** `scripts/ui/hud.gd` + `shaders/fatigue_filter.gdshader`
**现状：** HUD 中有 `FatigueFilter` 的 `ColorRect` 节点，Shader 已编写，但未实际连接 `FatigueManager` 的 AFI 值。
**需求：**
- 在 HUD 的 `_process()` 中读取 `FatigueManager.current_afi` 并传递给 Shader
- 实现 GDD 美术方向中的三级视觉效果：
  - AFI < 0.3：清澈（Bloom）
  - AFI 0.3-0.6：浑浊（Film Grain + 光晕抖动）
  - AFI > 0.8：过载（色差 + 扫描线 + 去饱和）

### 7.2 疲劳恢复建议 UI 🔲 `P2-Medium`
**文件：** `scripts/ui/hud.gd`
**现状：** HUD 中有 `SuggestionPanel`，`FatigueManager` 已实现 `get_recovery_suggestions()`，但两者未连接。
**需求：**
- 实时显示疲劳恢复建议文字
- 建议文字应有淡入淡出动画
- 高疲劳时建议应更加醒目（颜色变化、闪烁）

### 7.3 单音寂静机制 ⬜ `P1-High`
**现状：** GDD §2.2 的"单调值"惩罚（重复同一音符导致该音符进入"寂静"暂时禁用）未实现。
**需求：**
- 在 `FatigueManager` 中追踪每个音符的独立使用频率
- 当某音符的单调值超过阈值时，触发"寂静"状态
- 寂静状态下该音符无法施放，UI 上对应按键变灰
- 使用不同音符或适度不和谐可缓解单调值

### 7.4 密度值/噪音过载 ⬜ `P1-High`
**现状：** GDD §2.2 的"密度值"惩罚（音符堆太满导致"噪音过载"Debuff）未作为独立机制实现。
**需求：**
- 密度疲劳维度已在 AFI 中计算，但需要将其转化为具体的游戏效果
- 噪音过载 Debuff：降低精准度（弹体散射角度增大）
- 编入休止符可降低密度值

### 7.5 不和谐值生命腐蚀 🔲 `P1-High`
**文件：** `scripts/autoload/game_manager.gd`
**现状：** `apply_dissonance_damage()` 已实现基础逻辑，但未与实际的和弦施放流程连接。
**需求：**
- 在 `SpellcraftSystem` 施放和弦时，自动计算不和谐度并调用 `apply_dissonance_damage()`
- 施放和谐法术或"解决和弦"（D→T 进行）应降低不和谐值
- 添加不和谐伤害的视觉反馈（紫色数字 + 向下流淌效果）

---

## 八、游戏流程 (Game Flow)

### 8.1 游戏重置逻辑 🔲 `P1-High`
**文件：** `scripts/autoload/game_manager.gd`
**现状：** `reset_game()` 方法未定义（`game_over.gd` 中调用了它）。
**需求：**
- 在 `GameManager` 中实现 `reset_game()` 方法
- 重置所有游戏状态：HP、等级、XP、升级、疲劳度
- 重置 `FatigueManager`、`SpellcraftSystem` 的内部状态
- 重置序列器内容

### 8.2 难度曲线调优 🔲 `P2-Medium`
**文件：** `scripts/systems/enemy_spawner.gd`
**现状：** 基础的时间-难度递增已实现，但参数需要调优。
**需求：**
- 根据 GDD 数值文档调整敌人 HP、速度、生成频率的成长曲线
- 实现波次系统（每 N 秒一波，波间有短暂休息）
- 实现精英敌人（增强版普通敌人）的生成逻辑

### 8.3 游戏结束统计完善 🔲 `P2-Medium`
**文件：** `scripts/scenes/game_over.gd`
**现状：** 显示基础统计（存活时间、等级、XP、最大疲劳度），但缺少更多维度。
**需求：**
- 增加统计维度：击杀数、使用最多的音符、最长和弦进行、最高单次伤害
- 实现评价系统（基于音乐多样性评分）
- 保存历史最佳记录（本地持久化）

---

## 九、扩展性与长线设计 (Extensibility)

### 9.1 角色/职业系统 ⬜ `P3-Low`
**现状：** 完全未实现。
**需求：**
- GDD §4.1：不同"调性"或"音阶"作为不同角色/职业
- 例如：C 大调英雄（和谐型）、布鲁斯音阶英雄（不和谐高潜力型）
- 每个角色应有独特的初始序列器配置和被动能力

### 9.2 存档系统 ⬜ `P3-Low`
**现状：** 完全未实现。
**需求：**
- Meta 进度存档（解锁的角色、永久升级）
- 设置存档（音量、按键映射）
- 使用 Godot 的 `ConfigFile` 或 `JSON` 进行本地持久化

### 9.3 成就系统 ⬜ `P3-Low`
**现状：** 完全未实现。
**需求：**
- 基于音乐创作的成就（如"连续 4 小节无重复音符"、"完成一次完美 D→T 解决"）
- 成就解锁通知 UI

---

## 十、性能优化 (Performance)

### 10.1 对象池系统 ⬜ `P2-Medium`
**现状：** 敌人使用 `instantiate()` + `queue_free()` 模式，无对象池。
**需求：**
- 实现敌人对象池，避免频繁的节点创建和销毁
- 实现经验值拾取物对象池
- 实现伤害数字对象池

### 10.2 MultiMesh 性能验证 ⬜ `P2-Medium`
**文件：** `scripts/systems/projectile_manager.gd`
**现状：** MultiMesh 弹体系统已实现，但未在实际高负载下测试。
**需求：**
- 在 2000+ 弹体同屏时进行性能测试
- 验证 `instance_count` 动态调整是否导致卡顿
- 考虑预分配最大实例数并使用 `visible_instance_count` 控制显示

### 10.3 敌人生成性能 ⬜ `P2-Medium`
**文件：** `scripts/systems/enemy_spawner.gd`
**现状：** 敌人视觉使用代码动态生成 `Polygon2D`，每次生成都会创建新节点。
**需求：**
- 使用预制场景替代动态节点创建
- 实现敌人对象池
- 考虑使用 `MultiMeshInstance2D` 渲染大量 Swarm 类型敌人

---

## 优先级总览

| 优先级 | 数量 | 说明 |
|:---|:---:|:---|
| **P0-Critical** | 4 | 游戏无法正常运行的阻塞项 |
| **P1-High** | 15 | 核心游戏体验所必需的功能 |
| **P2-Medium** | 11 | 提升游戏品质和完整度的功能 |
| **P3-Low** | 4 | 长线扩展和锦上添花的功能 |
| **总计** | **34** | |

---

## 文件级标注索引

| 文件 | 待完善项数 | 关键问题 |
|:---|:---:|:---|
| `global_music_manager.gd` | 3 | 音效生成空函数、BGM 缺失、频谱接入 |
| `spellcraft_system.gd` | 4 | 小节完成处理、手动施法、和弦进行效果、黑键双重身份 |
| `projectile_manager.gd` | 3 | 碰撞优化、扩展和弦形态、Shader 接入 |
| `enemy_spawner.gd` | 2 | PackedScene 模板、性能优化 |
| `enemy_base.gd` | 3 | AI 扩展、死亡特效、视觉完善 |
| `player.gd` | 1 | 视觉完善 |
| `game_manager.gd` | 2 | reset_game()、不和谐伤害连接 |
| `fatigue_manager.gd` | 3 | 单音寂静、密度过载、滤镜接入 |
| `hud.gd` | 2 | 疲劳滤镜接入、建议 UI 连接 |
| `sequencer_ui.gd` | 1 | 编辑交互 |
| `upgrade_panel.gd` | 1 | 升级池完善 |
| `main_game.tscn` | 3 | CollisionShape、地面网格、事件视界 |
| 新文件 | 7 | 伤害数字、拾取物、障碍物、暂停菜单、Boss、角色系统、存档 |
