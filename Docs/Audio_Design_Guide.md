# Project Harmony: 音频设计与实现指南

**作者：** Manus AI (根据 gdszyy 的设计方案实现)
**版本：** 1.0
**最后更新：** 2026年2月7日
**关联代码：** `scripts/autoload/audio_manager.gd`, `scripts/autoload/bgm_manager.gd`, `audio_bus_layout.tres`

---

## 1. 核心设计哲学：和谐 vs. 噪音

Project Harmony 的音频设计建立在一组核心的对立概念之上，这组对立贯穿了游戏的所有机制、美术与声音表现。它不仅是美学风格，更是驱动游戏玩法与反馈的核心系统。

> **核心对立：**
> - **玩家 = 和谐 (Harmony / Music):** 玩家的一切行为，尤其是法术施放，都旨在创造悦耳、符合乐理的音乐。音效以钢琴、合成器和弦等乐音为主，为玩家提供积极、正向的反馈。
> - **敌人 = 噪音 (Noise / Dissonance):** 敌人是和谐的对立面，是“不和谐的具象化”。它们的音效被设计为“错误的信号”或“损坏的音频”，听起来像是数据错误、电流干扰或机械故障，为玩家制造冲突感与压迫感。

这个核心哲学指导了下述所有的具体设计决策。

---

## 2. 背景音乐 (BGM) 设计

### 2.1. 音乐风格选型：Techno

根据游戏的核心机制与视觉风格，**Techno**（尤其是 Minimal Techno 或 Glitch Techno）被确定为最适合的 BGM 类型。这主要基于以下两点：

1.  **功能性需求：** 游戏的核心战斗是“节奏同步战斗”，玩家的施法时机需要精确对齐音乐节拍。Techno 拥有非常**稳定、清晰且重复性高的 4/4 拍 Kick (底鼓)**，这使其成为一个天然、精准的“节拍器”，为玩家提供了可靠的输入参考。相比之下，自由爵士或变速频繁的古典乐因其节拍难以预测而被排除；而 Drum & Bass 则因节奏过于细碎，可能导致玩家输入窗口过于频繁，也被认为不适合。

2.  **美学契合度：** 游戏的美术风格被定义为“科幻神学 / 故障艺术 (Glitch Art)”。Techno 音乐的**机械感、合成器音色以及重复的 Loop 结构**，与游戏中“量化网格”、“程序化生成”的世界观和“信号崩溃”的视觉语言完美契合。

### 2.2. 技术实现与配置

BGM 系统由 `BGMManager` (`bgm_manager.gd`) 全局单例负责管理，其实现要点如下：

| 功能 | 实现方式 | 关键代码/配置 |
|---|---|---|
| **BGM 播放与切换** | 使用两个 `AudioStreamPlayer` (`_player_a`, `_player_b`) 实现无缝的交叉淡入淡出（Crossfade）。 | `_start_crossfade()`, `_process_crossfade()` |
| **BPM 同步** | `BGMManager` 独立于 `GameManager` 进行节拍计时，确保 BGM 自身的节拍与游戏逻辑节拍源一致。 | `_process_bgm_beat_sync()`, `_update_beat_interval()` |
| **场景适配** | 监听 `GameManager.game_state_changed` 信号，自动为不同游戏场景（菜单、战斗、游戏结束）选择并播放合适的 BGM。 | `_on_game_state_changed()`, `auto_select_bgm_for_state()` |
| **暂停效果** | 游戏暂停时，为 `Music` 音频总线动态添加低通滤波器（Low-pass Filter），制造出“闷音”效果，恢复时则移除。 | `_apply_muffle_effect()` |

#### 音频总线 (Audio Bus) 关键配置

为了让音乐能够驱动游戏内的视觉效果（如地面网格的脉冲），音频总线布局 (`audio_bus_layout.tres`) 进行了如下关键配置：

- **`Music` 总线：** 所有 BGM 都必须输出到此总线。
- **`AudioEffectSpectrumAnalyzer` 效果器：** 在 `Music` 总线上必须挂载此效果器。这是 `GlobalMusicManager` 脚本获取频谱数据、从而计算出节拍能量 (`beat_energy`) 的核心依赖。
- **频率响应配置：** `global_music_manager.gd` 中已定义了低频范围 `LOW_FREQ_MIN` (20.0) 到 `LOW_FREQ_MAX` (200.0)。因此，在选择或制作 BGM 时，必须确保其 **Kick (鼓点) 的主要能量集中在 20-200Hz 区间**。这能保证 `get_beat_energy()` 函数准确地提取出节拍信号，从而驱动地面网格的发光和脉冲效果。

---

## 3. 敌人音效设计：噪音污染 (Noise Pollution)

敌人的音效设计严格遵循“噪音”原则，听起来像是“错误的数据”或“损坏的音频”，与玩家悦耳的法术音效形成强烈对比。

### 3.1. 声音风格

| 行为 | 音效风格 | 具体描述与建议 |
|---|---|---|
| **移动 (Movement)** | 机械卡顿 / 电流干扰 | 低沉的电流嗡嗡声 (`low_hum`)、静电噪音 (`noise_click`)，或类似拨号上网时的数据传输音。通过在敌人每次“量化步进”时播放一个极短的、机械质感的“卡顿声”，让敌人的移动听起来像一个坏掉的时钟，增强“不和谐”的压迫感。 |
| **受击 (Damaged)** | 数据丢失 / 位元破碎 | 短促的 **Bitcrush (位元破碎)** 声音 (`bitcrush_short`)、刺耳的故障音 (`glitch_sound`)，或黑胶唱片刮擦声。视觉上敌人会闪烁，音效上则像是数据包丢失。 |
| **死亡 (Died)** | 信号崩溃 / 系统过载 | 较响亮的“崩塌” (`structure_collapse`) 或“爆裂” (`glitch_burst_large`) 噪音。美术文档中提到敌人死亡是“瞬间破碎成像素块”或“老式电视关机”，音效与此对应，模拟信号彻底中断的瞬间。 |

### 3.2. 技术实现

敌人的音效系统完全由 `AudioManager` (`audio_manager.gd`) 统一管理，遵循**高内聚、低耦合**的原则，敌人本身不处理任何音频播放逻辑。

1.  **全局音频管理器 (`AudioManager`)**
    - **程序化音效生成：** 在游戏启动时，`AudioManager` 会使用 `AudioStreamWAV` 实时生成所有需要的“噪音”音效，如白噪音、位元破碎、故障音等。这避免了依赖外部音频文件，减小了包体，并保证了音效风格的高度统一。 (`_generate_procedural_sounds()`)
    - **对象池：** 管理 `AudioStreamPlayer2D` 和 `AudioStreamPlayer` 的对象池，在需要播放音效时从池中获取一个播放器，播放完毕后回收。这极大地降低了频繁创建和销毁节点的性能开销。 (`_get_pooled_2d()`, `_get_pooled_global()`)
    - **音效冷却：** 内置了简单的冷却系统，防止因过于频繁地触发（如大量敌人同时移动）而导致音效过于嘈杂、刺耳。 (`_check_cooldown()`)

2.  **信号驱动机制**
    - 敌人脚本 (`enemy_base.gd`) 在 `_ready()` 函数中会调用 `AudioManager.register_enemy(self)`，将自己的信号注册到管理器中。
    - `AudioManager` 监听这些信号，并在信号触发时播放对应的音效：
        - **`enemy_damaged` 信号** → `play_enemy_hit_sfx()`
        - **`enemy_died` 信号** → `play_enemy_death_sfx()`
        - **`enemy_stunned` 信号** → `play_enemy_stun_sfx()`

3.  **量化移动音效**
    - 在 `enemy_base.gd` 的 `_quantized_movement()` 函数中，每当敌人完成一次“跳变”移动后，会直接调用 `AudioManager.play_enemy_move_sfx()` 来播放对应的移动音效。这确保了音效与视觉表现的完美同步。

---

## 4. 总结配置清单

下表总结了完整的音频系统设计与技术实现要点：

| 类别 | 风格 / 类型 | 技术关键点 | 作用 |
|---|---|---|---|
| **BGM** | Minimal Techno / Glitch Techno | 4/4 拍，Kick 频率 20-200Hz，输出到 `Music` 总线，由 `BGMManager` 管理。 | 作为游戏时钟，驱动场景脉冲，营造科幻与节奏感。 |
| **玩家音效** | 钢琴、合成器 (和弦) | 基于乐理 (大调/小调)，由 `AudioManager` 播放程序化生成的和谐乐音。 | 构建旋律，为玩家提供积极、正向的反馈。 |
| **敌人音效** | 白噪音、Bitcrush、电流声 | 基于信号触发，由 `AudioManager` 播放程序化生成的噪音，与 BGM 不合拍。 | 制造冲突感，提供清晰的受击、死亡等负反馈。 |
| **音频总线** | Master, Music, SFX (Enemy, Player, UI) | `Music` 总线挂载频谱分析器，`SFX` 下有子总线分类管理音量。 | 隔离音乐与音效，便于混音与效果处理。 |
| **实现架构** | 全局单例 (AudioManager, BGMManager) | 对象池、程序化音效生成、信号驱动。 | 高性能、低耦合、易于扩展和维护。 |
