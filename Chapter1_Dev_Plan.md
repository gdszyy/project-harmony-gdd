# Project Harmony: 第一章"律动尊者·毕达哥拉斯"开发计划

**文档目的：** 本文档为《Project Harmony》的第一个垂直切片——第一章"律动尊者·毕达哥拉斯"——提供一份详细、可执行的开发计划。计划基于《关卡与Boss整合设计文档 v3.0》，并严格遵循项目现有的代码架构（`EnemySpawner`、`ChapterManager`、`ChapterData`）进行设计。

**核心目标：** 完整实现一个高质量、可玩的章节体验，作为后续所有章节开发的标准和模板。

---

## 1. 架构理解：随机流与剧本流的混合模型

在深入分析了现有代码后，我们确认了项目的核心生成架构：

> **随机生成是游戏的基础循环。** `EnemySpawner` 在章节模式下，会根据 `ChapterData` 中定义的 `wave_templates`（敌人池、权重、波次类型）持续地、随机地生成敌人。这构成了游戏的"底色"——一个持续的、类 Vampire Survivors 的生存压力。

> **剧本波次是在特定时间点"插入"或"替换"随机流的。** 当 `ChapterManager` 判定需要进行教学引导或叙事推进时，它会通知 `EnemySpawner` **暂停**随机生成，转而执行一段**精确编排的剧本波次**。剧本波次结束后，系统恢复随机生成。

这意味着 v3.0 设计文档中的 6 个教学/考试波次，并非章节的全部内容，而是**嵌入在持续随机流中的关键教学节点**。

### 1.1. 生成流程时间线 (第一章)

下图展示了第一章的完整时间线，阐明了随机流与剧本流的关系：

```
[章节开始 BPM=100]
│
├─ 【剧本】波次 1-1：初识节拍 (教学波, ~30s)
│   └─ 4 只 Static，精确位置和时机
│
├─ [随机流恢复] 波次 1~3 (随机, enemy_pool: static, ~60s)
│   └─ 基于权重的随机 Static 生成，让玩家熟悉基础战斗
│
├─ 【剧本】波次 1-2：音符差异 (教学波, ~40s)
│   └─ 6 只 Static，远近分组，触发 D/G 音符解锁
│
├─ [随机流恢复] 波次 4~5 (随机, enemy_pool: static+screech, ~40s)
│
├─ 【剧本】波次 1-3：完美卡拍 (练习波, ~35s)
│   └─ 8 只 Static 蜂群，BPM 提升至 110
│
├─ [随机流恢复] 波次 6~7 (随机, BPM=110, ~40s)
│
├─ 【剧本】波次 1-4：休止符的力量 (教学波, ~50s)
│   └─ 2 只 Wall，解锁休止符
│
├─ [随机流恢复] 波次 8 (随机, 加入 ch1_grid_static, ~30s)
│
├─ 【剧本】波次 1-5：附点节奏 (练习波, ~45s)
│   └─ 1 只 Wall + 6 只 Static 护卫，解锁附点节奏
│
├─ [随机流恢复] 波次 9 (随机, 加入 ch1_metronome_pulse, ~30s)
│
├─ 【剧本】波次 1-6：综合运用 (考试波, ~60s)
│   └─ 10 Static + 2 Pulse + 1 Wall，BPM=120
│
├─ [Boss 前冲刺] 波次 10 (随机, pre_boss, 高密度, ~30s)
│
└─ 【Boss 战】律动尊者·毕达哥拉斯
```

---

## 2. 核心系统改造

### 2.1. `EnemySpawner` 改造：增加"剧本模式"

现有的 `EnemySpawner` 已经具备了完善的随机生成和章节模式能力。我们需要在其基础上**增加**一个"剧本模式"，而非替换现有逻辑。

**技术方案：**

**Step 1：新增状态和接口**

在 `EnemySpawner.gd` 中新增以下内容：

```gdscript
# 新增状态
var _scripted_wave_active: bool = false
var _scripted_wave_data: Resource = null  # WaveData
var _scripted_wave_timer: float = 0.0
var _scripted_event_index: int = 0

# 新增信号
signal scripted_wave_completed()

## 由 ChapterManager 调用，注入一个剧本波次
func play_scripted_wave(wave_data: Resource) -> void:
    _scripted_wave_active = true
    _scripted_wave_data = wave_data
    _scripted_wave_timer = 0.0
    _scripted_event_index = 0
    # 暂停随机生成
    _is_wave_active = false
    _is_resting = false

## 恢复随机生成
func resume_random_spawning() -> void:
    _scripted_wave_active = false
    _scripted_wave_data = null
    _is_resting = true
    _wave_rest_timer = 2.0
```

**Step 2：在 `_process` 中分流**

```gdscript
func _process(delta: float) -> void:
    if GameManager.current_state != GameManager.GameState.PLAYING:
        return
    if _boss_phase_active:
        _cleanup_dead_enemies()
        return

    # 剧本模式优先
    if _scripted_wave_active:
        _process_scripted_wave(delta)
    else:
        # 原有的随机生成逻辑
        _update_difficulty()
        if _is_resting:
            _wave_rest_timer -= delta
            if _wave_rest_timer <= 0.0:
                _start_new_wave()
        elif _is_wave_active:
            _process_wave(delta)

    _cleanup_dead_enemies()
```

**Step 3：实现 `_process_scripted_wave`**

```gdscript
func _process_scripted_wave(delta: float) -> void:
    _scripted_wave_timer += delta
    var events: Array = _scripted_wave_data.events

    # 按时间戳触发事件
    while _scripted_event_index < events.size():
        var event: Dictionary = events[_scripted_event_index]
        if _scripted_wave_timer >= event["timestamp"]:
            _execute_scripted_event(event)
            _scripted_event_index += 1
        else:
            break

    # 所有事件已触发，且场上无剧本敌人 → 剧本波次结束
    if _scripted_event_index >= events.size():
        var scripted_enemies_alive := _active_enemies.filter(
            func(e): return is_instance_valid(e) and e.get_meta("scripted", false)
        )
        if scripted_enemies_alive.is_empty():
            scripted_wave_completed.emit()
            resume_random_spawning()
```

### 2.2. `WaveData` 资源类型

创建一个新的 `Resource` 类型，用于定义剧本波次的事件序列。

```gdscript
## wave_data.gd
class_name WaveData
extends Resource

@export var wave_name: String = ""
@export var wave_type: String = "tutorial"  # tutorial / practice / exam
@export var events: Array[Dictionary] = []
```

每个 `event` 字典的结构：

| 字段 | 类型 | 说明 |
| :--- | :--- | :--- |
| `timestamp` | `float` | 从剧本波次开始的秒数 |
| `type` | `String` | 事件类型：`SPAWN`, `SET_BPM`, `SHOW_HINT`, `UNLOCK`, `CONDITIONAL_HINT` |
| `params` | `Dictionary` | 事件参数（因类型而异） |

### 2.3. `ChapterManager` 改造：剧本调度器

`ChapterManager` 需要新增一个**剧本调度表**，定义在哪些时间点或条件下注入剧本波次。

**技术方案：**

在 `ChapterData` 的章节配置中新增 `scripted_waves` 字段：

```gdscript
Chapter.CH1_PYTHAGORAS: {
    # ... 现有配置 ...

    # 新增：剧本波次调度表
    "scripted_waves": [
        {
            "trigger": "chapter_start",        # 章节开始时立即触发
            "wave_data": "res://data/waves/ch1/wave_1_1.tres",
        },
        {
            "trigger": "after_random_wave",     # 在第 3 个随机波次结束后触发
            "trigger_wave": 3,
            "wave_data": "res://data/waves/ch1/wave_1_2.tres",
        },
        {
            "trigger": "after_random_wave",
            "trigger_wave": 5,
            "wave_data": "res://data/waves/ch1/wave_1_3.tres",
        },
        {
            "trigger": "after_random_wave",
            "trigger_wave": 7,
            "wave_data": "res://data/waves/ch1/wave_1_4.tres",
        },
        {
            "trigger": "after_random_wave",
            "trigger_wave": 8,
            "wave_data": "res://data/waves/ch1/wave_1_5.tres",
        },
        {
            "trigger": "after_random_wave",
            "trigger_wave": 9,
            "wave_data": "res://data/waves/ch1/wave_1_6.tres",
        },
    ],
}
```

`ChapterManager` 在每次随机波次结束时，检查调度表，决定是否注入下一个剧本波次：

```gdscript
func _on_wave_completed(wave_number: int) -> void:
    var schedule = _get_next_scripted_wave(wave_number)
    if schedule != null:
        var wave_data = load(schedule["wave_data"]) as WaveData
        _enemy_spawner.play_scripted_wave(wave_data)
    # 否则 EnemySpawner 自行开始下一个随机波次
```

### 2.4. 敌人脚本改造

现有敌人脚本（`Static`, `Wall`, `Pulse`）需要支持从剧本波次接收精确参数。

**改造内容：**

在 `enemy_base.gd` 中新增：

```gdscript
## 由 WaveSpawner 在剧本模式下调用
func initialize_scripted(params: Dictionary) -> void:
    if params.has("speed"):
        move_speed = params["speed"]
    if params.has("hp"):
        max_hp = params["hp"]
        current_hp = params["hp"]
    if params.has("shield"):
        shield_hp = params["shield"]
    # 标记为剧本敌人
    set_meta("scripted", true)
```

---

## 3. 美术与资源清单

| 类型 | 资源名称 | 描述 | 优先级 |
| :--- | :--- | :--- | :--- |
| **Shader** | `PulsingGrid.gdshader` | 背景脉冲网格，根据 BPM 闪烁。 | **高** |
| **Shader** | `ChladniPattern.gdshader` | Boss 战核心。生成克拉尼图形（同心圆、花瓣形），支持叠加。 | **极高** |
| **UI 场景** | `RhythmIndicator.tscn` | 节拍指示器，含完美卡拍金色闪光反馈。 | **高** |
| **UI 脚本** | `TutorialHintManager.gd` | 非侵入式提示（高亮 UI 元素、显示文字）。 | 中 |
| **数据资源** | `wave_1_1.tres` ~ `wave_1_6.tres` | 6 个 `WaveData` 剧本文件。 | **高** |

---

## 4. 开发任务分解 (Milestones)

### Milestone 1: 核心系统改造 (预计 3 天)

*   [ ] **Task 1.1**: 创建 `WaveData.gd` 资源类型。
*   [ ] **Task 1.2**: 在 `EnemySpawner.gd` 中实现 `play_scripted_wave()` / `resume_random_spawning()` 接口和 `_process_scripted_wave()` 逻辑。
*   [ ] **Task 1.3**: 在 `ChapterData.gd` 的 `CH1_PYTHAGORAS` 配置中新增 `scripted_waves` 调度表。
*   [ ] **Task 1.4**: 改造 `ChapterManager.gd`，在随机波次结束时检查调度表并注入剧本波次。
*   [ ] **Task 1.5**: 在 `enemy_base.gd` 中新增 `initialize_scripted(params)` 函数。
*   [ ] **Task 1.6**: **(集成测试)** 创建一个最简单的测试剧本（生成 1 只 Static），验证"随机→暂停→剧本→恢复随机"的完整流程。

### Milestone 2: 波次 1-1 & 1-2 实现 (教学波 - 节奏与音符) (预计 1 天)

*   [ ] **Task 2.1**: 创建 `wave_1_1.tres` 和 `wave_1_2.tres` 数据文件。
*   [ ] **Task 2.2**: 实现 `PulsingGrid.gdshader`，并与 `GameManager.current_bpm` 同步。
*   [ ] **Task 2.3**: 实现 `RhythmIndicator.tscn` 的基础功能和完美卡拍反馈。
*   [ ] **Task 2.4**: **(集成测试)** 完整运行：随机流 → 剧本波次 1-1 → 随机流 → 剧本波次 1-2 → 随机流。验证教学意图。

### Milestone 3: 波次 1-3 & 1-4 & 1-5 实现 (练习波 - 节奏型) (预计 2 天)

*   [ ] **Task 3.1**: 创建 `wave_1_3.tres`, `wave_1_4.tres`, `wave_1_5.tres` 数据文件。
*   [ ] **Task 3.2**: 实现 `UNLOCK` 事件类型（在剧本中触发休止符和附点节奏的解锁）。
*   [ ] **Task 3.3**: 实现 `TutorialHintManager.gd`，支持 `SHOW_HINT` 和 `CONDITIONAL_HINT` 事件。
*   [ ] **Task 3.4**: 验证 Static 蜂群加速、Wall 护盾、附点击退等机制在剧本波次中的表现。
*   [ ] **Task 3.5**: **(集成测试)** 完整运行并通过波次 1-3 至 1-5，确认教学引导有效。

### Milestone 4: 波次 1-6 实现 (考试波) (预计 1 天)

*   [ ] **Task 4.1**: 创建 `wave_1_6.tres`，精确配置混合波的敌人入场时间和方向。
*   [ ] **Task 4.2**: 验证 Pulse 的环形弹幕按 4 拍周期释放。
*   [ ] **Task 4.3**: **(集成测试)** 完整运行并通过波次 1-6，感受其综合考验的压力。

### Milestone 5: Boss 战实现 (律动尊者·毕达哥拉斯) (预计 3 天)

*   [ ] **Task 5.1**: **(核心难点)** 实现 `ChladniPattern.gdshader`。
*   [ ] **Task 5.2**: 改造 `boss_pythagoras.gd`，使其控制克拉尼图形和安全节点。
*   [ ] **Task 5.3**: 实现 Boss 的"节拍考验"机制（完美卡拍才能造成伤害）。
*   [ ] **Task 5.4**: 实现 Boss 的阶段转换逻辑（P1 → P2），包括"不和谐脉冲"。
*   [ ] **Task 5.5**: 实现 Boss 的"风格排斥"机制（惩罚无效输入，浮现"亵渎！"）。
*   [ ] **Task 5.6**: **(最终测试)** 完整挑战并通过 Boss 战。

### Milestone 6: 章节收尾 (预计 1 天)

*   [ ] **Task 6.1**: 实现 Boss 击败后的奖励逻辑（解锁和弦炼成系统）。
*   [ ] **Task 6.2**: 实现引导玩家合成第一个大三和弦的教程。
*   [ ] **Task 6.3**: 对整个章节进行全面的 Bug 测试和体验调优。

---

**总计预估开发时间：** 11 天。

---

## 5. 波次剧本详细设计 (WaveData Specifications)

以下是每个剧本波次的详细设计，可直接转化为 `WaveData` 资源文件。**注意：这些剧本波次之间穿插着由 `EnemySpawner` 自动运行的随机波次。**

### 5.1. 波次 1-1：初识节拍 (教学波)

**文件名：** `res://data/waves/ch1/wave_1_1.tres`

**触发时机：** 章节开始时立即触发（`trigger: "chapter_start"`）

**BPM：** 100

**预计时长：** ~30 秒

**事件序列：**

| 时间戳 (秒) | 事件类型 | 参数 |
| :--- | :--- | :--- |
| 0.0 | SET_BPM | `{"bpm": 100}` |
| 0.0 | SHOW_HINT | `{"text": "跟随地面的脉冲节奏进行攻击", "duration": 4.0}` |
| 2.4 | SPAWN | `{"enemy": "static", "position": "NORTH", "speed": 80}` |
| 4.8 | SPAWN | `{"enemy": "static", "position": "EAST", "speed": 80}` |
| 7.2 | SPAWN | `{"enemy": "static", "position": "SOUTH", "speed": 80}` |
| 9.6 | SPAWN | `{"enemy": "static", "position": "WEST", "speed": 80}` |

**成功条件：** 击杀所有 4 只 Static 后，剧本波次结束，恢复随机流。

**设计验证点：**
- 地面脉冲网格是否与 BPM=100 精确同步？
- 节拍指示器的完美卡拍反馈是否醒目？
- Static 的移动速度是否足够慢，让新手玩家有充足时间瞄准？

---

### 5.2. 波次 1-2：音符差异 (教学波)

**文件名：** `res://data/waves/ch1/wave_1_2.tres`

**触发时机：** 第 3 个随机波次结束后（`trigger: "after_random_wave", trigger_wave: 3`）

**BPM：** 100

**预计时长：** ~40 秒

**事件序列：**

| 时间戳 (秒) | 事件类型 | 参数 |
| :--- | :--- | :--- |
| 0.0 | UNLOCK | `{"type": "note", "note": "D", "message": "获得 D 音符（极速远程）"}` |
| 0.5 | UNLOCK | `{"type": "note", "note": "G", "message": "获得 G 音符（爆发伤害）"}` |
| 1.0 | SHOW_HINT | `{"text": "不同音符有不同的速度、射程和伤害", "duration": 5.0}` |
| 3.0 | SPAWN | `{"enemy": "static", "position": "Vector2(0, -800)", "speed": 60}` |
| 3.5 | SPAWN | `{"enemy": "static", "position": "Vector2(100, -800)", "speed": 60}` |
| 4.0 | SPAWN | `{"enemy": "static", "position": "Vector2(-100, -800)", "speed": 60}` |
| 5.0 | SPAWN | `{"enemy": "static", "position": "Vector2(0, -300)", "speed": 150}` |
| 5.5 | SPAWN | `{"enemy": "static", "position": "Vector2(80, -300)", "speed": 150}` |
| 6.0 | SPAWN | `{"enemy": "static", "position": "Vector2(-80, -300)", "speed": 150}` |

**成功条件：** 击杀所有 6 只 Static。

**设计验证点：**
- 远处的 Static（800px）是否用 C 音符难以命中，但用 D 音符（射程 1500px）轻松击杀？
- 近处快速的 Static 是否用 G 音符（高伤害 50）能一击秒杀？

---

### 5.3. 波次 1-3：完美卡拍 (练习波)

**文件名：** `res://data/waves/ch1/wave_1_3.tres`

**触发时机：** 第 5 个随机波次结束后

**BPM：** 110

**预计时长：** ~35 秒

**事件序列：**

| 时间戳 (秒) | 事件类型 | 参数 |
| :--- | :--- | :--- |
| 0.0 | SET_BPM | `{"bpm": 110}` |
| 0.0 | SHOW_HINT | `{"text": "完美卡拍可获得 1.5 倍伤害和 2.5 倍击退", "duration": 4.0}` |
| 2.0 | SPAWN_SWARM | `{"enemy": "static", "count": 8, "formation": "LINE", "direction": "NORTH", "speed": 100, "swarm_enabled": true}` |

**成功条件：** 击杀所有 8 只 Static 蜂群。

**设计验证点：**
- Static 的"群体加速"机制是否生效（8 只聚集时应达到约 1.4x 速度）？
- 完美卡拍的击退效果是否能有效将蜂群推回？

---

### 5.4. 波次 1-4：休止符的力量 (教学波)

**文件名：** `res://data/waves/ch1/wave_1_4.tres`

**触发时机：** 第 7 个随机波次结束后

**BPM：** 110

**预计时长：** ~50 秒

**事件序列：**

| 时间戳 (秒) | 事件类型 | 参数 |
| :--- | :--- | :--- |
| 0.0 | UNLOCK | `{"type": "feature", "feature": "REST_NOTE", "message": "解锁：休止符"}` |
| 0.5 | SHOW_HINT | `{"text": "在序列器中编入休止符可增强其他音符", "duration": 5.0, "highlight_ui": "REST_BUTTON"}` |
| 3.0 | SPAWN | `{"enemy": "wall", "position": "Vector2(0, -400)", "speed": 25, "hp": 200, "shield": 50}` |
| 18.0 | CONDITIONAL_HINT | `{"condition": "NO_REST_USED_FOR_15s", "text": "尝试在序列器中使用休止符", "highlight_ui": "REST_BUTTON"}` |
| 25.0 | SPAWN | `{"enemy": "wall", "position": "Vector2(200, -400)", "speed": 25, "hp": 200, "shield": 50}` |

**成功条件：** 击杀所有 2 只 Wall。

**设计验证点：**
- 不使用休止符时，用 C 音符击破 Wall 是否需要约 9 发，感到吃力？
- 使用"G - 休止 - G - 休止"序列后，效率是否显著提升？

---

### 5.5. 波次 1-5：附点节奏 (练习波)

**文件名：** `res://data/waves/ch1/wave_1_5.tres`

**触发时机：** 第 8 个随机波次结束后

**BPM：** 110

**预计时长：** ~45 秒

**事件序列：**

| 时间戳 (秒) | 事件类型 | 参数 |
| :--- | :--- | :--- |
| 0.0 | UNLOCK | `{"type": "rhythm", "rhythm": "DOTTED", "message": "解锁：附点节奏（伤害+1，击退+1）"}` |
| 0.5 | SHOW_HINT | `{"text": "附点节奏的击退效果可以推开敌人", "duration": 4.0}` |
| 3.0 | SPAWN | `{"enemy": "wall", "position": "Vector2(0, -400)", "speed": 30, "hp": 200, "shield": 50}` |
| 3.5 | SPAWN_ESCORT | `{"enemy": "static", "count": 6, "orbit_target": "LAST_SPAWNED", "orbit_radius": 80, "speed": 100}` |

**成功条件：** 击杀 Wall 和所有 6 只 Static 护卫。

**设计验证点：**
- 附点节奏的击退效果是否能将 Static 护卫推开，为后续弹体打开通路？

---

### 5.6. 波次 1-6：综合运用 (考试波)

**文件名：** `res://data/waves/ch1/wave_1_6.tres`

**触发时机：** 第 9 个随机波次结束后

**BPM：** 120

**预计时长：** ~60 秒

**事件序列：**

| 时间戳 (秒) | 事件类型 | 参数 |
| :--- | :--- | :--- |
| 0.0 | SET_BPM | `{"bpm": 120}` |
| 0.0 | SHOW_HINT | `{"text": "综合运用所有技巧", "duration": 3.0}` |
| 2.0 | SPAWN_SWARM | `{"enemy": "static", "count": 10, "formation": "SCATTERED", "direction": "NORTH", "speed": 110, "swarm_enabled": true}` |
| 8.0 | SPAWN | `{"enemy": "pulse", "position": "EAST", "speed": 50, "attack_interval": 4.0}` |
| 12.0 | SPAWN | `{"enemy": "wall", "position": "SOUTH", "speed": 30, "hp": 200, "shield": 50}` |
| 18.0 | SPAWN | `{"enemy": "pulse", "position": "WEST", "speed": 50, "attack_interval": 4.0}` |

**成功条件：** 击杀所有敌人（10 Static + 2 Pulse + 1 Wall）。

**设计验证点：**
- 三个方向的敌人是否在不同时间到达，给玩家逐一处理的机会？
- 这一波是否让玩家感到"有挑战但可控"？

---

## 6. Boss 战详细设计

### 6.1. Boss 概述

| 项目 | 内容 |
| :--- | :--- |
| **Boss 名称** | 律动尊者·毕达哥拉斯 |
| **形态** | 位于场景中心的多层旋转光环几何体，不移动 |
| **HP** | 阶段一 800 / 阶段二 1200 |
| **核心机制** | 克拉尼图形致死区域 + 节点安全区 |
| **时代特征** | 【绝对频率】——地面生成不断变化的克拉尼图形，线条致死，节点安全 |
| **风格排斥** | 惩罚无效输入（胡乱按键产生"噪音"，Boss 全屏微弱伤害 + 屏幕浮现"亵渎！"） |

### 6.2. 阶段一：简单图形 (HP 800 → 0)

**攻击模式循环：** 八度共振 → 五度震荡 → 节拍考验 (循环)

#### 攻击 1：八度共振

| 参数 | 值 |
| :--- | :--- |
| **持续时间** | 16 拍 (BPM=120, 约 8 秒) |
| **克拉尼图形** | 同心圆（最简单） |
| **安全节点** | 4 个固定点（东、南、西、北） |
| **玩家应对** | 站在节点上持续输出 Boss |

**实现要点：** `ChladniPattern.gdshader` 生成同心圆图案。Boss 脚本标记 4 个安全节点位置，检测玩家是否在节点上（不在则造成持续伤害）。

#### 攻击 2：五度震荡

| 参数 | 值 |
| :--- | :--- |
| **持续时间** | 24 拍 (约 12 秒) |
| **克拉尼图形** | 花瓣形 |
| **安全节点** | 6 个点，每 8 拍切换位置 |
| **玩家应对** | 观察图形变化规律，提前移动到新节点 |

**实现要点：** 每 8 拍触发节点位置切换，新节点提前 2 拍开始发光预警。

#### 攻击 3：节拍考验

| 参数 | 值 |
| :--- | :--- |
| **持续时间** | 16 拍 (约 8 秒) |
| **特殊机制** | Boss 每 4 拍释放全屏脉冲。只有完美卡拍时刻攻击才能造成伤害，其他时刻被"和谐护盾"反弹。 |
| **玩家应对** | 严格在完美卡拍时刻释放攻击 |

**实现要点：** Boss 需要"和谐护盾"状态，非完美卡拍时刻免疫所有伤害。

### 6.3. 阶段二：复杂图形 (HP 1200 → 0)

**触发条件：** 阶段一 HP 归零后，Boss 进入短暂无敌过渡动画（约 3 秒），然后恢复至 HP 1200。

#### 攻击 1：四度叠加

| 参数 | 值 |
| :--- | :--- |
| **持续时间** | 24 拍 (约 12 秒) |
| **克拉尼图形** | 两组图形叠加 |
| **安全节点** | 仅 3 个点 |
| **玩家应对** | 精准走位，或利用 D 音符远射程在安全区外输出 |

#### 攻击 2：不和谐脉冲

| 参数 | 值 |
| :--- | :--- |
| **持续时间** | 16 拍 (约 8 秒) |
| **特殊机制** | Boss 释放不规则节奏的脉冲（3 拍、5 拍、2 拍随机间隔） |
| **玩家应对** | 适应变化的节奏，依赖节拍指示器 |

#### 攻击 3：终焉和弦 (HP < 20% 触发)

| 参数 | 值 |
| :--- | :--- |
| **持续时间** | 持续至 Boss 被击败 |
| **克拉尼图形** | 所有图形同时激活（3-4 组叠加） |
| **安全节点** | 仅 2 个点，每 4 拍切换位置 |
| **玩家应对** | 精准走位 + 完美卡拍 + 正确音符选择 |

### 6.4. 风格排斥：惩罚无效输入

**机制：** 如果玩家在 2 秒内连续按下 5 次以上攻击键，但全部为 OFF_BEAT 或 WEAK_BEAT，Boss 判定为"无效输入"：

| 效果 | 描述 |
| :--- | :--- |
| **伤害** | 全屏微弱伤害（约 5% 玩家最大 HP） |
| **视觉** | 屏幕浮现红色文字"亵渎！" |
| **音效** | 刺耳的噪音 |

### 6.5. Boss 击败奖励

1.  **解锁和弦炼成系统**：`ChordCraftingSystem` 全局单例被激活。
2.  **获得音符**：玩家自动获得足够的 C、E、G 音符。
3.  **引导教程**：弹出和弦炼成台界面，引导玩家合成第一个大三和弦（C-E-G → 强化弹体）。
4.  **章节完成**：`ChapterManager` 发出 `chapter_completed` 信号。

---

## 7. 风险管理

### 7.1. 最高优先级任务（阻塞性）

1.  **`ChladniPattern.gdshader`**：Boss 战的核心机制，技术难度最高。如果无法实时渲染，可降级为预渲染纹理动画。
2.  **剧本/随机混合流程**：这是整个架构的关键创新点，必须在 Milestone 1 中完成验证。

### 7.2. 技术风险点

| 风险点 | 描述 | 缓解方案 |
| :--- | :--- | :--- |
| **克拉尼图形 Shader** | 实时渲染可能存在性能问题。 | 提前技术原型验证。降级方案：预渲染纹理动画。 |
| **剧本/随机切换的流畅性** | 暂停随机流后恢复时，可能出现敌人密度突变。 | 恢复时设置 2 秒缓冲期，逐步恢复生成速率。 |
| **完美卡拍判定窗口** | 过窄导致挫败，过宽失去挑战性。 | 提供可调节参数，在波次 1-3 中大量测试。 |
| **教学提示的侵入性** | 过于频繁破坏沉浸感，过于隐晦玩家可能错过。 | 采用"柔和高亮"和"延迟触发"策略。 |

---

## 8. 成功标准 (Definition of Done)

1.  **功能完整性**：所有 6 个剧本波次和 Boss 战均可完整游玩，无阻断性 Bug。剧本波次与随机波次的切换流畅自然。
2.  **教学有效性**：至少 3 名未接触过游戏的测试玩家能够在不依赖文字教程的情况下，通过"环境即教程"的设计，自然地掌握节奏型、音符差异和完美卡拍。
3.  **难度曲线**：随机波次提供持续的基础压力，剧本波次在此基础上引入新机制。测试玩家在教学波中死亡次数不超过 1 次，在考试波和 Boss 战中感受到明显挑战（死亡 2-5 次后通关）。
4.  **技术性能**：在目标平台上稳定运行在 60 FPS。
5.  **叙事与氛围**：Boss 战的视觉、音效和机制能让玩家感受到"古希腊几何学的神圣秩序"这一主题。

---

**文档结束。** 此开发计划可作为第一章实现的完整蓝图。
