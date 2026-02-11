# Project Harmony — 音色系统设计文档

**版本:** 1.1
**最后更新:** 2026-02-11
**状态:** 设计稿
**作者：** Manus AI

---

## 1. 设计概述

### 1.1. 系统定位：法术的第五维度

在 Project Harmony 现有的法术构建体系中，玩家通过**白键音符**（四维参数 DMG/SPD/DUR/SIZE）定义弹体的基础属性，通过**黑键修饰符**（穿透/追踪/分裂/回响/散射）赋予一次性的特殊效果，通过**和弦**（15种和弦类型 → 15种法术形态）触发强力的组合法术，通过**节奏型**（6种模式）修饰弹体的发射行为。这四个维度构成了一套完整的"作曲"系统。

**音色 (Timbre)** 作为第五个维度被引入，它不直接改变法术的基础数值，而是定义弹体的**"攻击质感"**与**"物理行为模式"**。如果说前四个维度解决的是"演奏什么"的问题，那么音色解决的是"用什么乐器来演奏"的问题——它将玩家的体验从"作曲"深化到了"配器"的层面。所有音色系的攻击质感与物理行为模式，其最终的视觉呈现效果，均遵循 [《法术系统视觉增强设计文档》](./Spell_Visual_Enhancement_Design.md) 中定义的规范的统一规范。

### 1.2. 设计原则

**叠加而非替代。** 音色系统是对现有法术系统的补充和扩展。它作为一层"行为滤镜"叠加在音符、和弦和节奏构成的基础法术之上。一个 G 音符（高伤害）的弹体，无论使用何种音色，其基础 50 点伤害不会改变；但弹拨系音色会让它在命中瞬间产生额外的冲击波，而拉弦系音色则会让它在敌人身上留下持续的共振标记。

**声学特性抽象化。** 系统不按具体乐器硬编码，而是将音色划分为基于声学发声原理的四大系别（弹拨、拉弦、吹奏、打击）。每个系别定义了一套核心机制和 ADSR 行为模板，具体乐器则作为系别下的"变体"存在，在共享核心机制的基础上拥有独特的"神韵"效果。这种架构保证了系统的可扩展性——新增一种乐器只需创建一个新的 `TimbreData` 资源文件，而无需修改核心代码。

**ADSR 驱动行为。** 经典的 ADSR 包络（Attack, Decay, Sustain, Release）被映射为弹体在整个生命周期中的物理行为与视觉表现。Attack 定义弹体从生成到达峰值效果的时间；Decay 定义峰值后的衰减速率；Sustain 定义弹体在稳态阶段的效能比例；Release 定义弹体消失后的残留效果时长。这使得"攻击质感"成为一个可被量化设计和精确调优的参数。

**系统性整合。** 音色系统不是一个孤立的模块，它将与和弦形态、节奏型、听感疲劳（AFI）以及局外成长系统（和谐殿堂）产生深度交互，成为影响整体策略的关键一环。

---

## 2. 四大音色系别

### 2.1. 系别总览

| 音色系别 | 核心机制 | ADSR 特征 | 攻击质感 | 代表乐器 |
| :--- | :--- | :--- | :--- | :--- |
| **弹拨系 (Plucked)** | [瞬态爆发] | 极短A, 快D, 低S, 无R | 颗粒感、快速衰减 | 古筝, 琵琶 |
| **拉弦系 (Bowed)** | [连绵共振] | 慢A, 无D, 极高S, 长R | 持续性、连接感 | 二胡, 大提琴 |
| **吹奏系 (Wind)** | [气息聚焦] | 均A, 均D, 变化S, 短R | 穿透性、形态变化 | 笛子, 长笛 |
| **打击系 (Percussive)** | [重音冲击] | 瞬A, 无D, 极高S, 短R | 节奏感、物理冲击 | 钢琴, 贝斯 |

### 2.2. 弹拨系 (Plucked) — 瞬态爆发

> **核心机制 [瞬态爆发 / Transient Burst]**：弹体在生成后的极短时间内（Attack 阶段，约 0.05 秒）获得一次性的伤害与范围加成，随后迅速衰减（Decay）。这模拟了拨弦瞬间声音最大、然后快速减弱的物理特性。弹体在生成时会触发一个短暂（0.1 秒）的小范围冲击波，造成基础伤害的 20%。弹体的飞行伤害在存活期间会以指数曲线轻微衰减。

**古筝 (Guzheng) — 基础乐器**

古筝是弹拨系的基础乐器，其设计围绕"流水"的意象，强调连续的、流动的攻击感。

神韵效果 **[流水 / Cascading]**：弹体命中敌人或自然消失时，会沿其移动方向的延长线上，额外分裂出 1-2 个衍生弹体。衍生弹体继承原弹体 50% 的伤害和 60% 的碰撞范围，飞行方向带有微小的随机偏移（±15°），形成"刮奏"般的视觉效果。若衍生弹体击杀了敌人，则不会再次触发分裂，以防止无限链式反应。

和弦交互：使用古筝音色施放**区域型 (Field / 属七和弦)** 法术时，法术区域内会每 0.5 秒生成一圈水墨波纹扩散效果，对范围内的敌人造成每秒 5 点持续伤害并施加 15% 的减速效果。

视觉与听觉：弹体呈现为水墨风格的波纹形态，拖尾效果如同墨滴在水中扩散。命中音效为清亮的拨弦声，衍生弹体的音效为更轻柔的泛音。

**琵琶 (Pipa) — 进阶乐器（局内稀有级升级获取）**

琵琶的设计围绕"轮指"技法，强调极高的攻击频率和破盾能力，以"大珠小珠落玉盘"为核心意象。

神韵效果 **[轮指 / Tremolo]**：激活此音色时，玩家的有效施法频率提升 10%（等效于 BPM 提升 10%），但每发弹体的基础伤害降低 15%。作为补偿，所有弹体获得"破盾"属性——对拥有护盾的敌人（如音墙 Wall 敌人）造成 1.5 倍伤害。该效果与黑键修饰符的穿透（C#）效果可叠加，穿透弹体同样享受破盾加成。

和弦交互：使用琵琶音色施放**爆炸型 (Explosive / 增三和弦)** 法术时，爆炸会触发两次——第一次为正常爆炸，第二次在 0.15 秒后触发，范围和伤害均为第一次的 50%，产生"大珠小珠落玉盘"的连环爆破感。

视觉与听觉：弹体呈现为金色的小型光珠，密集排列。命中音效为铿锵有力的弹拨声，连环爆炸时伴随快速的琶音音效。

### 2.3. 拉弦系 (Bowed) — 连绵共振

> **核心机制 [连绵共振 / Sustained Resonance]**：被此系别弹体击中的敌人会被施加"共振"标记（持续 3 秒，可刷新）。当一个带有"共振"标记的敌人再次被拉弦系弹体击中时，会以自身为中心，向半径 120px 内所有其他带有"共振"标记的敌人发射连锁能量弧，造成触发弹体伤害 30% 的传导伤害。连锁弧最多同时连接 3 个目标。弹体在命中后不会立即消失，而是会继续存在一小段时间（Release 阶段，约 0.3 秒），期间弹体变为半透明的光轨，仍可对触碰的敌人造成 50% 伤害。

**二胡 (Erhu) — 基础乐器**

二胡的设计围绕"如泣如诉"的情感表达，将连锁伤害转化为控制效果，强调对敌群的束缚能力。

神韵效果 **[连营 / Soul Bind]**：[连绵共振]的连锁能量弧不再造成直接伤害，而是将被连接的敌人用可视的"琴弦"束缚在一起，持续 2 秒。期间所有被束缚的敌人移动速度降低 30%，且若其中一个被束缚的敌人受到来自任何来源的伤害，其他被束缚的敌人也会受到该伤害 25% 的传导伤害。这使得二胡在面对分散的敌群时具有极高的战术价值。

和弦交互：使用二胡音色施放**持续伤害型 (DOT / 小三和弦)** 法术时，DOT 效果的每一跳都有 25% 的几率将被影响的敌人短暂定身 0.2 秒。若目标同时带有"共振"标记，定身几率提升至 40%。

视觉与听觉：弹体呈现为两根缠绕的丝线形态（模拟二胡的两根弦），飞行时拖拽细长的光轨。束缚效果以暗红色的丝线连接敌人。命中音效为哀怨的拉弦声。

**大提琴 (Cello) — 进阶乐器（局内稀有级升级获取）**

大提琴的设计围绕"共鸣"的厚重感，将连锁效果转化为区域控制，强调持续的场地压制能力。

神韵效果 **[共鸣场 / Resonance Field]**：[连绵共振]的连锁能量弧在传导路径上会留下短暂的（1.5 秒）低频伤害区域（半径 40px），对进入的敌人每秒造成弹体基础伤害 20% 的持续伤害并施加 10% 减速。该效果取代了直接的传导伤害，但提供了更强的区域控制能力。

和弦交互：使用大提琴音色施放**护盾/治疗型 (Shield/Heal / 大七和弦)** 法术时，法阵的持续时间增加 25%，且法阵会以玩家移动速度的 50% 缓慢地跟随玩家移动，而非固定在原地。

视觉与听觉：弹体呈现为宽厚的扇形声波，飞行时有明显的低频震动视觉效果。共鸣场区域以深蓝色的同心圆波纹呈现。命中音效为厚重的低音弦乐声。

### 2.4. 吹奏系 (Wind) — 气息聚焦

> **核心机制 [气息聚焦 / Breath Focus]**：弹体在飞行过程中，其物理形态会发生动态变化——弹体越飞越远，其碰撞体积 (SIZE) 会逐渐缩小，但飞行速度 (SPD) 和穿透能力会随之提升。具体而言：飞行 0.5 秒后，碰撞半径缩小 30%，速度提升 20%，获得 +1 穿透次数；飞行 1.0 秒后，碰撞半径缩小 50%，速度提升 40%，穿透次数再 +2。这模拟了气息从宽广到聚焦的过程。

**笛子 (Dizi) — 基础乐器**

笛子的设计围绕"颤音"和"穿透"的意象，强调在直线上清理敌人的能力，是吹奏系中最具攻击性的选择。

神韵效果 **[颤音 / Vibrato]**：弹体在飞行时会呈现微小的正弦波轨迹（振幅 8px，频率 3Hz），增加了视觉表现力的同时也略微扩大了有效扫掠范围。当[气息聚焦]效果触发、弹体获得穿透加成后，每次成功穿透一个敌人，弹体的伤害会提升 10%（最多叠加 5 次，即最高 +50%）。这使得笛子在面对成排的敌人时，后排敌人反而会受到更高的伤害。

和弦交互：使用笛子音色施放**冲击波型 (Shockwave / 减三和弦)** 法术时，冲击波的最远端（外圈 20% 的范围）会获得额外 30% 的伤害加成，体现了气息在远端聚焦后的爆发力。

视觉与听觉：弹体呈现为半透明的气流形态，随着飞行距离增加逐渐变细变亮。穿透敌人时会留下竹叶飘落的粒子效果。命中音效为清脆的笛声，穿透时音调逐渐升高。

**长笛 (Flute) — 进阶乐器（局内稀有级升级获取）**

长笛的设计围绕"气旋"的控制力，将穿透能力转化为聚怪能力，是吹奏系中偏向辅助/控制的选择。

神韵效果 **[气旋 / Vortex]**：弹体在飞行过程中，会对半径 60px 内的敌人施加微弱的牵引力，将其朝弹道中心靠拢（牵引速度约 30px/s）。该效果在弹体因[气息聚焦]变细后逐渐减弱（牵引力与碰撞半径成正比）。这使得长笛非常适合与区域型法术配合使用——先用长笛弹体聚拢敌人，再用区域法术一网打尽。

和弦交互：使用长笛音色施放**天降打击型 (Divine Strike / 减七和弦)** 法术时，法术的延迟时间缩短 30%（从标准的 1.0 秒缩短至 0.7 秒），但影响范围也相应缩小 20%，体现了"聚焦"的特性。

视觉与听觉：弹体呈现为圆润的长条状气流，周围有可见的气旋纹理。聚怪效果以螺旋状的风纹呈现。命中音效为深沉圆润的长笛声。

### 2.5. 打击系 (Percussive) — 重音冲击

> **核心机制 [重音冲击 / Accent Impact]**：此系别弹体的效果与节奏系统深度绑定。当弹体在小节的**强拍**（4/4 拍的第 1、3 拍，即序列器位置 pos % 2 == 0）上生成时，会获得显著的击退 (Knockback) 和眩晕 (Stun) 效果加成：击退距离 x2.0，50% 几率造成 0.5 秒眩晕。在弱拍上生成的弹体则无此加成。这直接奖励玩家在序列器的强拍位置放置核心法术，强化了游戏与音乐节奏的互动。

**钢琴 (Grand Piano) — 基础乐器**

钢琴是打击系的基础乐器，也是整个音色系统中最"均衡"的选择，其设计围绕"延音踏板"的概念，强调击杀后的能量延续。

神韵效果 **[踏板 / Sustain Pedal]**：在强拍上生成的弹体，如果成功击杀敌人，会在击杀位置留下一个持续 2 秒的"延音标记"（视觉上为一个缓慢扩散的金色光环，半径 30px）。后续任何弹体经过该标记的范围时，会吸收其能量，获得 15% 的伤害加成和 10% 的碰撞范围加成。每个延音标记只能被吸收一次。

和弦交互：使用钢琴音色施放**召唤/构造型 (Summon / 小七和弦)** 法术时，召唤物的持续时间延长 20%，且召唤物的攻击也会遵循强弱拍机制——在强拍时攻击力提升 30%。

视觉与听觉：弹体呈现为纯净的白色/金色光球，形态规整。强拍弹体体积略大，带有明显的冲击波纹。命中音效为清晰的钢琴音，强拍命中时音量更大、音色更饱满。

**贝斯 (Bass) — 进阶乐器（局内稀有级升级获取）**

贝斯的设计围绕"根音"的低频震动，将打击系的击退效果推向极致，同时引入"易伤"的团队增益概念。

神韵效果 **[根音 / Root Note]**：弹体本身的基础伤害降低 20%，但[重音冲击]的击退距离和眩晕效果翻倍（即强拍击退 x4.0，眩晕几率 100%，眩晕时长 0.5 秒）。被强拍弹体击中的敌人会获得"低频共振"Debuff，持续 2 秒，期间受到的所有来源的伤害增加 10%。此外，贝斯弹体命中地面时会留下短暂的（1.0 秒）"低频陷阱"区域（半径 40px），经过的敌人移动速度降低 25%。

和弦交互：使用贝斯音色施放**爆炸型 (Explosive / 增三和弦)** 法术时，若在强拍触发，爆炸范围扩大 30%，并将范围内所有敌人向外推开，同时施加"低频共振"易伤效果。

视觉与听觉：弹体呈现为深色的、带有可见震动波纹的低频脉冲。低频陷阱区域以地面震荡波呈现。命中音效为低沉的贝斯拨弦声，强拍命中时伴随明显的低频震动。

---

## 3. ADSR 包络数值表

下表列出了每种乐器的 ADSR 参数默认值，这些参数定义了弹体在生命周期各阶段的行为特征。

| 乐器 | 系别 | Attack (s) | Decay (s) | Sustain (%) | Release (s) | 稀有度 |
| :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| 古筝 | 弹拨 | 0.05 | 0.3 | 40% | 0.0 | 基础 |
| 琵琶 | 弹拨 | 0.03 | 0.2 | 30% | 0.0 | 稀有 |
| 二胡 | 拉弦 | 0.2 | 0.0 | 90% | 0.3 | 基础 |
| 大提琴 | 拉弦 | 0.3 | 0.0 | 95% | 0.5 | 稀有 |
| 笛子 | 吹奏 | 0.1 | 0.15 | 70% | 0.1 | 基础 |
| 长笛 | 吹奏 | 0.15 | 0.1 | 75% | 0.15 | 稀有 |
| 钢琴 | 打击 | 0.02 | 0.0 | 85% | 0.05 | 基础 |
| 贝斯 | 打击 | 0.02 | 0.0 | 90% | 0.1 | 稀有 |

> **ADSR 对弹体的具体影响**：在 Attack 阶段，弹体的视觉尺寸和伤害效能从 0 线性增长到 100%（峰值）；在 Decay 阶段，效能从 100% 衰减到 Sustain 百分比；在 Sustain 阶段，效能保持在 Sustain 百分比不变；弹体消失后进入 Release 阶段，残留视觉效果（光轨、冲击波等）持续 Release 时长，期间仍可造成 Sustain 百分比 × 50% 的伤害。

---

## 4. 系统整合

### 4.1. 与和弦系统的交互

音色对和弦法术的影响已在第 2 节各乐器的"和弦交互"中详细描述。总体设计思路是：音色不改变和弦法术的基础类型和伤害，而是为其附加额外的行为特征或数值修正。下表汇总了所有音色-和弦交互效果：

| 乐器 | 受影响的和弦形态 | 交互效果 |
| :--- | :--- | :--- |
| 古筝 | 区域型 (属七) | 区域内生成水墨波纹，附加 5 DPS + 15% 减速 |
| 琵琶 | 爆炸型 (增三) | 爆炸触发两次，第二次为 50% 效果 |
| 二胡 | DOT型 (小三) | 每跳 25% 几率定身 0.2s（共振目标 40%） |
| 大提琴 | 护盾/治疗型 (大七) | 持续时间 +25%，法阵跟随玩家移动 |
| 笛子 | 冲击波型 (减三) | 外圈 20% 范围伤害 +30% |
| 长笛 | 天降打击型 (减七) | 延迟 -30%，范围 -20% |
| 钢琴 | 召唤/构造型 (小七) | 持续时间 +20%，召唤物强拍攻击力 +30% |
| 贝斯 | 爆炸型 (增三) | 强拍时范围 +30%，附加推开 + 易伤 |

### 4.2. 与黑键修饰符的叠加

音色提供的是持续性的行为修饰，黑键修饰符提供的是一次性的特殊效果，两者可以自由叠加。以下是一些值得注意的组合：

| 音色 | 修饰符 | 组合效果 |
| :--- | :--- | :--- |
| 笛子 [颤音] | C# 穿透 | 穿透次数叠加（聚焦穿透 + 修饰符穿透），每次穿透伤害 +10% |
| 古筝 [流水] | F# 分裂 | 弹体先分裂为 3 个，每个分裂弹体消失时再触发流水衍生 |
| 二胡 [连营] | D# 追踪 | 追踪弹体自动寻找未标记的敌人，快速建立共振网络 |
| 贝斯 [根音] | A# 散射 | 散射的多个弹体均享受强拍加成，大范围击退 + 易伤 |
| 琵琶 [轮指] | G# 回响 | 高频弹体 + 回响延迟弹体，形成密集的弹幕覆盖 |

### 4.3. 与听感疲劳系统的交互

音色系统与疲劳系统的交互体现在两个方面：

**切换成本。** 每次玩家在局内切换当前激活的音色时，都会立即增加 0.05 的听感疲劳指数（AFI）。这相当于一次轻微的"不和谐"行为。频繁切换（例如在 10 秒内切换 3-4 次）足以将玩家的疲劳等级推高一级，从而触发惩罚效果。该数值（`TIMBRE_SWITCH_FATIGUE_COST = 0.05`）经过与现有疲劳阈值的对照设计：轻度疲劳阈值为 0.3，中度为 0.5，因此玩家在一局游戏中有约 6 次"免费"切换的空间。

**疲劳对音色效果的影响。** 当玩家的疲劳等级达到"中度"（AFI > 0.5）时，音色的核心机制效能会降低 20%（例如，弹拨系的冲击波伤害从 20% 降至 16%，拉弦系的传导伤害从 30% 降至 24%）。当疲劳等级达到"严重"（AFI > 0.8）时，音色的核心机制效能降低 50%，且神韵效果完全失效。这鼓励玩家在高疲劳状态下优先处理疲劳问题，而非依赖音色效果。

### 4.4. 与局外成长系统的整合

音色系统将被整合到"和谐殿堂"的成长体系中，具体方案如下：

**模块 B（乐理研习）扩展 — "音色图鉴"**：作为一个新的解锁分支，玩家可以消耗"共鸣碎片"来解锁不同的音色系别。解锁顺序建议为：打击系（初始解锁）→ 弹拨系 → 吹奏系 → 拉弦系。一旦系别解锁，该系别下的基础乐器（古筝、二胡、笛子、钢琴）将自动获得。

**局内获取**：进阶乐器（琵琶、大提琴、长笛、贝斯）将作为稀有级的局内升级选项出现在升级面板中。玩家需要先在局外解锁对应的音色系别，才能在局内的升级池中刷出该系别的进阶乐器。

**音色强化升级**：可以设计专门的局内升级项，用于强化当前激活音色的核心机制或神韵效果。例如：

| 升级名称 | 稀有度 | 效果 |
| :--- | :--- | :--- |
| 弦振共鸣 | 普通 | [连绵共振] 传导伤害 +15% |
| 气息延长 | 普通 | [气息聚焦] 形态变化延迟 +0.2s（更晚变细） |
| 瞬态过载 | 稀有 | [瞬态爆发] 冲击波范围 +30%，伤害 +10% |
| 节拍大师 | 稀有 | [重音冲击] 弱拍也获得 50% 的强拍效果 |
| 双音色共存 | 史诗 | 可同时激活两种音色，弹体交替使用 |

---

## 5. 玩家策略与 Build 构建

音色系统的引入为玩家提供了更丰富的 Build 构建空间。以下是几种典型的策略流派分析：

| 流派名称 | 核心音色 | 核心音符 | 核心和弦 | 策略描述 |
| :--- | :--- | :--- | :--- | :--- |
| **穿透割草** | 笛子 | D (极速) / B (高速高伤) | 减三 (冲击波) | 利用笛子的穿透递增伤害，配合高速弹体清理直线敌群 |
| **控场大师** | 二胡 | E (大范围) / F (区域控制) | 小三 (DOT) | 利用二胡的束缚和传导伤害，控制大量分散敌人 |
| **爆发一击** | 古筝/琵琶 | G (爆发伤害) | 增三 (爆炸) | 利用瞬态爆发的高初始伤害，配合爆炸和弦一击清场 |
| **节奏坦克** | 贝斯 | C (均衡) / A (持久高伤) | 增三 (爆炸) | 利用贝斯的超强击退和易伤效果，在强拍上创造安全空间 |
| **持续压制** | 大提琴 | F (区域控制) / E (大范围) | 大七 (护盾/治疗) | 利用共鸣场的区域控制，配合跟随护盾法阵持续压制 |

---

## 6. 代码实现方案

### 6.1. 数据结构扩展 — `music_data.gd`

在现有的 `MusicData` 类中新增音色系别枚举和相关常量：

```gdscript
# scripts/data/music_data.gd

# ============================================================
# 音色系统枚举与数据
# ============================================================

## 音色系别枚举
enum TimbreType {
    NONE,           # 默认/无音色
    PLUCKED,        # 弹拨系
    BOWED,          # 拉弦系
    WIND,           # 吹奏系
    PERCUSSIVE,     # 打击系
}

## 音色切换疲劳代价
const TIMBRE_SWITCH_FATIGUE_COST: float = 0.05

## 疲劳对音色效能的影响
const TIMBRE_FATIGUE_PENALTY: Dictionary = {
    FatigueLevel.NONE: 1.0,       # 无衰减
    FatigueLevel.MILD: 1.0,       # 无衰减
    FatigueLevel.MODERATE: 0.8,   # 效能降低20%
    FatigueLevel.SEVERE: 0.5,     # 效能降低50%，神韵失效
    FatigueLevel.CRITICAL: 0.2,   # 效能降低80%，神韵失效
}
```

### 6.2. 新增资源类型 — `timbre_data.gd`

创建一个新的 `Resource` 类型，用于定义每一种具体的音色（乐器）：

```gdscript
# scripts/resources/timbre_data.gd
class_name TimbreData
extends Resource

@export_group("Identity")
## 乐器名称
@export var timbre_name: String = "Grand Piano"
## 所属音色系别
@export var timbre_type: MusicData.TimbreType = MusicData.TimbreType.PERCUSSIVE
## 乐器图标 (用于UI显示)
@export var icon: Texture2D
## 乐器描述
@export_multiline var description: String = "富有节奏感的冲击力。"
## 稀有度 (0=基础, 1=稀有, 2=史诗)
@export var rarity: int = 0

@export_group("ADSR Envelope")
## Attack: 弹体从生成到最大效果的时间 (秒)
@export var attack_time: float = 0.05
## Decay: 达到峰值后衰减到Sustain的时间 (秒)
@export var decay_time: float = 0.2
## Sustain: 持续阶段的效能百分比 (0.0 ~ 1.0)
@export var sustain_level: float = 0.8
## Release: 弹体消失后视觉/效果残留的时间 (秒)
@export var release_time: float = 0.1

@export_group("Unique Mechanic Parameters")
## 神韵效果的主要数值参数
## 古筝: 衍生弹体数量 | 琵琶: 射速加成比例
## 二胡: 束缚减速比例 | 大提琴: 共鸣场持续时间
## 笛子: 穿透伤害递增比例 | 长笛: 牵引力强度
## 钢琴: 延音标记持续时间 | 贝斯: 易伤比例
@export var unique_param_1: float = 0.0
## 神韵效果的次要数值参数
@export var unique_param_2: float = 0.0

@export_group("Visual & Audio")
## (可选) 覆盖默认弹体Shader
@export var projectile_shader_override: Shader
## 命中音效
@export var hit_sfx: AudioStream
## 施法音效
@export var cast_sfx: AudioStream

## 计算当前疲劳等级下的效能倍率
func get_efficacy_multiplier(fatigue_level: MusicData.FatigueLevel) -> float:
    return MusicData.TIMBRE_FATIGUE_PENALTY.get(fatigue_level, 1.0)

## 判断神韵效果是否因疲劳而失效
func is_unique_disabled(fatigue_level: MusicData.FatigueLevel) -> bool:
    return fatigue_level >= MusicData.FatigueLevel.SEVERE
```

### 6.3. 法术系统注入 — `spellcraft_system.gd`

在生成法术数据时，注入当前激活的音色信息：

```gdscript
# scripts/autoload/spellcraft_system.gd

## 当前激活的音色
var current_timbre: TimbreData = null

func _cast_single_note_from_sequencer(slot: Dictionary, pos: int) -> void:
    var white_key: MusicData.WhiteKey = slot["note"]
    var stats := GameManager.get_note_effective_stats(white_key)

    # ... (原有的节奏修饰和疲劳惩罚逻辑)

    var spell_data := {
        # ... (原有数据字段)
        "note": white_key,
        "damage": stats["dmg"] * MusicData.PARAM_CONVERSION["dmg_per_point"] * damage_mult,
        "speed": stats["spd"] * MusicData.PARAM_CONVERSION["spd_per_point"],
        "duration": stats["dur"] * MusicData.PARAM_CONVERSION["dur_per_point"],
        "size": stats["size"] * MusicData.PARAM_CONVERSION["size_per_point"],
        "color": MusicData.NOTE_COLORS.get(white_key, Color.WHITE),
        "modifier": _consume_modifier(),
        "rhythm_pattern": rhythm,
        # === 音色系统新增字段 ===
        "timbre_type": current_timbre.timbre_type if current_timbre else MusicData.TimbreType.NONE,
        "timbre_data": current_timbre,
        "is_strong_beat": (pos % 2 == 0),  # 偶数拍位为强拍
    }

    spell_cast.emit(spell_data)
```

### 6.4. 弹体行为处理 — `projectile_manager.gd`

在弹体更新逻辑中，根据音色类型应用不同的行为修饰：

```gdscript
# scripts/systems/projectile_manager.gd

func _update_projectiles(delta: float) -> void:
    for proj in _projectiles:
        if not proj["active"]:
            continue

        # ... (原有生命周期和位置更新逻辑)

        # === 音色系统逻辑 ===
        _apply_timbre_behavior(proj, delta)

        # ... (原有碰撞检测逻辑)

func _apply_timbre_behavior(proj: Dictionary, delta: float) -> void:
    var timbre_type = proj.get("timbre_type", MusicData.TimbreType.NONE)
    if timbre_type == MusicData.TimbreType.NONE:
        return

    match timbre_type:
        MusicData.TimbreType.PLUCKED:
            _process_plucked(proj, delta)
        MusicData.TimbreType.BOWED:
            _process_bowed(proj, delta)
        MusicData.TimbreType.WIND:
            _process_wind(proj, delta)
        MusicData.TimbreType.PERCUSSIVE:
            _process_percussive(proj, delta)

func _process_plucked(proj: Dictionary, _delta: float) -> void:
    # 瞬态爆发：生成时触发冲击波 (仅在首帧)
    if not proj.get("_plucked_init", false):
        proj["_plucked_init"] = true
        _trigger_transient_burst(proj)
    # 飞行伤害衰减
    var adsr = proj.get("timbre_data")
    if adsr:
        var decay_rate = 1.0 - (proj["time_alive"] / max(proj["duration"], 0.1))
        proj["damage"] = proj.get("base_damage", proj["damage"]) * max(adsr.sustain_level, decay_rate)

func _process_bowed(proj: Dictionary, _delta: float) -> void:
    # 拉弦系弹体在Release阶段继续存在
    if proj["time_alive"] >= proj["duration"]:
        var adsr = proj.get("timbre_data")
        if adsr and proj["time_alive"] < proj["duration"] + adsr.release_time:
            proj["active"] = true  # 延长存活
            proj["damage"] = proj.get("base_damage", proj["damage"]) * adsr.sustain_level * 0.5

func _process_wind(proj: Dictionary, _delta: float) -> void:
    # 气息聚焦：根据飞行时间调整大小和速度
    var life_ratio = clamp(proj["time_alive"] / max(proj["duration"], 0.1), 0.0, 1.0)
    var base_size = proj.get("base_size", proj["size"])
    var base_speed = proj.get("base_speed", proj["velocity"].length())
    proj["size"] = lerp(base_size, base_size * 0.5, life_ratio)
    var new_speed = lerp(base_speed, base_speed * 1.4, life_ratio)
    proj["velocity"] = proj["velocity"].normalized() * new_speed
    # 穿透次数随飞行时间增加
    if proj["time_alive"] > 0.5 and not proj.get("_wind_pierce_1", false):
        proj["_wind_pierce_1"] = true
        proj["pierce"] = true
        proj["max_pierce"] = proj.get("max_pierce", 0) + 1
    if proj["time_alive"] > 1.0 and not proj.get("_wind_pierce_2", false):
        proj["_wind_pierce_2"] = true
        proj["max_pierce"] = proj.get("max_pierce", 1) + 2

func _process_percussive(proj: Dictionary, _delta: float) -> void:
    # 重音冲击：强拍加成
    if proj.get("is_strong_beat", false) and not proj.get("_perc_init", false):
        proj["_perc_init"] = true
        proj["knockback"] = true
        proj["knockback_scale"] = 2.0
        proj["stun_chance"] = 0.5
        proj["stun_duration"] = 0.5
```

### 6.5. 音色管理 — `game_manager.gd`

在 GameManager 中管理音色的获取、切换，并与疲劳系统联动：

```gdscript
# scripts/autoload/game_manager.gd

# ============================================================
# 音色系统
# ============================================================
signal timbre_changed(new_timbre: TimbreData)

var active_timbre: TimbreData = null
var available_timbres: Array[TimbreData] = []

## 切换音色
func switch_timbre(new_timbre: TimbreData) -> void:
    if new_timbre == active_timbre:
        return
    active_timbre = new_timbre
    SpellcraftSystem.current_timbre = new_timbre
    # 应用切换疲劳代价
    FatigueManager.apply_manual_fatigue(MusicData.TIMBRE_SWITCH_FATIGUE_COST)
    timbre_changed.emit(active_timbre)

## 添加可用音色 (通过升级获取)
func unlock_timbre(timbre: TimbreData) -> void:
    if timbre not in available_timbres:
        available_timbres.append(timbre)
    # 如果是第一个音色，自动激活
    if active_timbre == null:
        active_timbre = timbre
        SpellcraftSystem.current_timbre = timbre
```

---

## 7. 总结与展望

本设计方案将"音色"作为法术系统的一个全新层次化模块。它与现有的四维参数、和弦、节奏等系统并行运作，通过独特的系别核心机制、ADSR 行为模型和乐器神韵效果，极大地丰富了战斗的策略深度和视觉表现力。

通过将音色抽象为声学特性系别，我们为未来扩展留下了充足的空间。新的乐器可以作为新的 `TimbreData` 资源被轻松添加——只需创建一个 `.tres` 资源文件并填写参数，而无需修改核心代码逻辑。未来可以考虑的扩展方向包括：

- **合奏系统**：允许玩家同时激活两种不同系别的音色，弹体交替使用两种音色的行为模式，形成"二重奏"效果。
- **音色进化**：在局内通过特定条件（如使用同一音色击杀 100 个敌人），触发音色的"进化"，解锁更强力的神韵效果变体。
- **Boss 专属音色**：击败特定 Boss 后获得其专属音色，拥有独特的核心机制（如"不和谐系"音色，以自伤换取极高伤害）。

这套系统将使玩家的"编曲"过程不仅停留在"作曲"层面，更深入到了"配器"的维度，完美契合了《Project Harmony》的核心设计哲学。
