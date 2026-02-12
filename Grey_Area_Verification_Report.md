# Project Harmony 技术审计报告：灰色地带验证

- **项目**: `gdszyy/project-harmony-gdd`
- **审计员**: Manus AI
- **日期**: 2026年02月12日
- **目的**: 对三个关键的灰色地带（章节敌人生成、召唤系统触发、OPT系列模块集成）进行代码级验证，明确其实际集成状态。

---

## 总结

本次技术审计深入分析了指定的三个灰色地带。**结论是，所有审查的系统和模块均已在代码层面完全集成**，其实现方式符合 GDD（游戏设计文档）的设计意图，并且模块间的信号/调用链路完整、逻辑清晰。未发现需要创建 GitHub Issue 的未集成或部分集成问题。详细的验证过程和代码证据在以下章节中阐述。

| 灰色地带 | 模块/系统 | 结论 | 核心文件 |
| :--- | :--- | :--- | :--- |
| 1 | 章节敌人生成系统 | **已完全集成** | `enemy_spawner.gd`, `chapter_manager.gd`, `chapter_data.gd` |
| 2 | 召唤系统触发链路 | **已完全集成** | `spellcraft_system.gd`, `summon_manager.gd`, `music_data.gd` |
| 3 | OPT02-OPT08 优化模块 | **已完全集成** | (多个核心文件) |

---

## 灰色地带 1：章节敌人生成系统

此部分旨在验证由 `ChapterManager` 驱动的动态敌人生成系统的集成完整性。

### 1.1. `_preload_chapter_scripts()` 调用链

`enemy_spawner.gd` 中的 `_preload_chapter_scripts()` 方法负责加载特定章节的敌人资源。审计确认其调用链如下：

- **调用起点**: 该方法**并非**在 `_ready()` 函数中全局加载，而是在 `enemy_spawner.gd` 的 `set_chapter_mode()` (L275) 函数中被调用。
- **触发时机**: `set_chapter_mode()` 由 `chapter_manager.gd` 在 `_start_chapter()` (L218) -> `_notify_spawner_chapter_start()` (L264) 的流程中精确触发。这意味着，仅当新章节开始时，系统才会加载对应章节的专属敌人资源。
- **结论**: 调用链正确，符合按需加载的设计原则，避免了不必要的内存占用。

### 1.2. 基础敌人与章节敌人的关系

- **基础敌人**: `enemy_spawner.gd` (L31) 中的 `ENEMY_SCENES` 硬编码了5种全局基础敌人（static, silence, screech, pulse, wall），在 `_ready()` (L161) 中通过 `_preload_enemy_scenes()` 预加载。
- **章节敌人**: `chapter_data.gd` (L769, L798) 中的 `ENEMY_SCENE_PATHS` 和 `ELITE_SCENE_PATHS` 定义了各章节专属的特色敌人和精英敌人。
- **关系**: 两者是**互补关系**。`_preload_chapter_scripts()` (L206) 加载 `ChapterData` 中定义的资源，而 `_preload_enemy_scenes()` 加载全局基础资源。两者在生成逻辑 `_spawn_enemy_at()` (L920) 中被统一处理，不存在覆盖或冲突。

### 1.3. 完整信号/调用链路

从章节切换到敌人生成的完整调用链路清晰且稳固：

1.  `ChapterManager._start_chapter()`: 启动新章节，加载章节配置。
2.  `ChapterManager._notify_spawner_chapter_start()`: 发出通知。
3.  `EnemySpawner.set_chapter_mode()`: 接收通知，切换到章节模式，并调用 `_preload_chapter_scripts()` 加载资源。
4.  `EnemySpawner._start_new_wave()`: 波次开始时，向 `ChapterManager` 请求波次模板 `ChapterData.get_wave_template()`。
5.  `EnemySpawner._select_enemy_type()`: 根据波次模板中的 `enemy_types` 数组选择要生成的敌人。
6.  `EnemySpawner._spawn_enemy_at()`: 实例化并生成敌人，此过程已完全集成对象池系统（Issue #116）。

### 1.4. 结论

章节敌人生成系统 **已完全集成**。其设计逻辑清晰，资源加载和敌人生成流程均由 `ChapterManager` 精确驱动，实现了 GDD 中描述的动态、分章节的敌人生态。

---

## 灰色地带 2：召唤系统触发链路

此部分旨在验证通过施放“小七和弦”触发召唤物的完整链路。

### 2.1. 和弦检测与 `SUMMON` 形态映射

- **和弦识别**: `spellcraft_system.gd` 在 `_flush_chord_buffer()` (L461) 中收集玩家输入的音符，并调用 `MusicTheoryEngine.identify_chord()` (L464) 进行识别。
- **形态映射**: `music_data.gd` (L182) 中的 `CHORD_SPELL_MAP` 字典明确将 `ChordType.MINOR_7` (小七和弦) 映射到 `SpellForm.SUMMON`。
- **信号发射**: `spellcraft_system.gd` 的 `_cast_chord()` (L787) 函数在成功识别和弦后，会将 `SpellForm.SUMMON` 打包进 `chord_data` 字典，并通过 `chord_cast.emit(chord_data)` (L904) 信号将信息广播出去。

### 2.2. `SummonManager` 信号连接

- **连接点**: `summon_manager.gd` 在其 `_ready()` (L131) 函数中，主动连接到 `SpellcraftSystem.chord_cast` 信号。
- **处理器**: 连接的目标是 `_on_chord_cast()` (L158) 函数。
- **有效性**: 由于 `SpellcraftSystem` 是 Autoload 单例，而 `SummonManager` 是 `main_game.tscn` 场景树中的节点，这种从场景节点连接到 Autoload 信号的方式是稳定且正确的。

### 2.3. 完整链路追踪

从施法到召唤物出现的完整链路如下：

1.  玩家输入构成小七和弦的音符。
2.  `SpellcraftSystem` 识别和弦，确认为 `MINOR_7`，并获取其法术形态为 `SUMMON`。
3.  `SpellcraftSystem` 发射 `chord_cast` 信号，携带包含 `spell_form: SpellForm.SUMMON` 的数据。
4.  `SummonManager` 的 `_on_chord_cast` 处理器被触发。
5.  该函数检查 `spell_form` 是否为 `SUMMON` (L160)，确认后执行召唤逻辑。
6.  `SummonManager.create_construct()` (L738) 被调用，加载 `summon_construct.gd` 脚本，实例化新的召唤物并添加到场景中。

### 2.4. 结论

召唤系统的触发链路 **已完全集成**。从和弦识别、信号发射、信号接收到最终的召唤物实例化，整个流程的逻辑闭环完整，代码实现与设计意图一致。

---

## 灰色地带 3：OPT02-OPT08 优化模块实际集成度

通过并行代码分析和关键点交叉验证，对7个优化模块的集成状态进行了审查。所有模块均已深度集成到游戏的核心系统中。

| 模块 | 核心文件 | 集成状态 | 简要说明 |
| :--- | :--- | :--- | :--- |
| **OPT02**<br>相对音高 | `relative_pitch_resolver.gd` | **已完全集成** | `AudioManager` 在计算音效的相对音高时，直接调用 `RelativePitchResolver` 的核心方法。 |
| **OPT03**<br>敌人音乐身份 | `enemy_audio_controller.gd`<br>`enemy_audio_profile.gd` | **已完全集成** | `EnemyAudioController` 被动态添加到 `enemy_base.gd` 中，在移动、受击、死亡时触发对应的音乐声效。 |
| **OPT04**<br>章节调性演化 | `bgm_manager.gd` | **已完全集成** | `ChapterManager` 在切换章节时调用 `BGMManager.set_tonality()`，驱动背景音乐和环境音的调性根据章节主题演化。 |
| **OPT05**<br>Rez风格量化 | `audio_event_queue.gd` | **已完全集成** | `AudioManager` 使用 `AudioEventQueue` 将所有游戏内音效（包括敌人脚步声）精确量化到节拍上，是游戏核心听觉体验的一部分。 |
| **OPT06**<br>空间音频 | `spatial_audio_controller.gd` | **已完全集成** | `SpatialAudioController` 被添加到 `enemy_base.gd`，根据敌人的距离、方位和战斗状态（如护盾、低血量）动态调整音效参数。 |
| **OPT07**<br>召唤物音乐性 | `summon_audio_controller.gd`<br>`summon_audio_profile.gd` | **已完全集成** | `summon_construct.gd` 在初始化时会创建并挂载 `SummonAudioController`，使其行为（攻击、待机）能够发出符合当前调性的音乐声。 |
| **OPT08**<br>程序化音色合成 | `synth_manager.gd`<br>`timbre_synth_presets.gd` | **已完全集成** | `SynthManager` 作为 Autoload 单例，被 `GlobalMusicManager` 和 `AudioManager` 广泛调用，用于实时合成玩家法术和部分环境音效，并设计了到文件播放的降级机制。 |

### 3.1. 结论

所有 OPT02-OPT08 优化模块 **已完全集成**。它们不是孤立的代码片段，而是已经深度融入到音频、战斗、AI 和章节流程等核心游戏系统中，共同构成了《Project Harmony》独特的音乐驱动玩法体验。
