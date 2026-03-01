# SignalBridge P1 修复方案

## 1. 清理空回调函数
目前 `signal_bridge.gd` 中有多个空回调函数，它们不仅增加了运行时的开销，还可能掩盖潜在的问题。
需要处理的空回调包括：
- `_on_player_died` -> 添加 `TODO: 补充玩家死亡统计/UI处理逻辑` 和 `push_warning("SignalBridge: _on_player_died not implemented")`
- `_on_wave_completed` -> 添加 `TODO` 和 `push_warning`
- `_on_wave_started` -> 添加 `TODO` 和 `push_warning`
- `_on_chapter_timer_updated` -> 由于已注明“由 HUD 轮询处理，此处仅作为备用连接点”，保留但可以添加 `pass` 和明确注释
- `_on_wave_started_in_chapter` -> 添加 `TODO` 和 `push_warning`
- `_on_elite_wave_triggered` -> 添加 `TODO` 和 `push_warning`
- `_on_endless_mode_started` -> 添加 `TODO` 和 `push_warning`
- `_on_boss_health_changed` -> 由于已注明“Boss 血条由 BossHpBarUI 处理，此处仅作为备用”，保留但可以添加 `pass` 和明确注释
- `_on_bgm_intensity_changed` -> 保留现有注释
- `_on_bgm_layer_toggled` -> 保留现有注释
- `_on_tonality_changed` -> 保留现有注释
- `_on_progression_triggered` -> 添加 `TODO` 和 `push_warning`
- `_on_transpose_changed` -> 添加 `TODO` 和 `push_warning`
- `_on_mode_unlocked` -> 添加 `TODO` 和 `push_warning`
- `_on_mode_selected` -> 添加 `TODO` 和 `push_warning`
- `_on_theory_unlocked` -> 添加 `TODO` 和 `push_warning`
- `_on_resonance_changed` -> 添加 `TODO` 和 `push_warning`

## 2. 补充 Boss 核心信号监听
在 `_connect_chapter_signals` 中，监听 Boss 相关的信号。Boss 信号主要由 `ChapterManager` 和 `BossSpawner` 发出，或直接在 Boss 节点上。

新增一个方法 `_connect_boss_signals()` 专门处理：
```gdscript
func _connect_boss_signals() -> void:
    var chapter_mgr = null
    if Engine.has_singleton("ChapterManager"):
        chapter_mgr = Engine.get_singleton("ChapterManager")
    elif has_node("/root/ChapterManager"):
        chapter_mgr = get_node("/root/ChapterManager")
        
    if chapter_mgr and chapter_mgr.has_signal("boss_spawned"):
        if not chapter_mgr.boss_spawned.is_connected(_on_boss_spawned):
            chapter_mgr.boss_spawned.connect(_on_boss_spawned)
            
    # 从场景树中查找 BossSpawner
    var spawner = get_tree().get_first_node_in_group("boss_spawner") if get_tree() else null
    if spawner:
        if spawner.has_signal("boss_fight_started"):
            if not spawner.boss_fight_started.is_connected(_on_boss_fight_started):
                spawner.boss_fight_started.connect(_on_boss_fight_started)
```

回调函数：
```gdscript
func _on_boss_spawned(boss_node: Node) -> void:
    # 动态连接 Boss 节点的内部信号
    if boss_node.has_signal("boss_vulnerability_started"):
        if not boss_node.boss_vulnerability_started.is_connected(_on_boss_vulnerability_started):
            boss_node.boss_vulnerability_started.connect(_on_boss_vulnerability_started)
            
    if boss_node.has_signal("boss_vulnerability_ended"):
        if not boss_node.boss_vulnerability_ended.is_connected(_on_boss_vulnerability_ended):
            boss_node.boss_vulnerability_ended.connect(_on_boss_vulnerability_ended)
            
    if boss_node.has_signal("boss_phase_changed"):
        if not boss_node.boss_phase_changed.is_connected(_on_boss_phase_changed):
            boss_node.boss_phase_changed.connect(_on_boss_phase_changed)
            
    # 通知UI显示血条
    var hp_bars = get_tree().get_nodes_in_group("boss_health_bar")
    for bar in hp_bars:
        if bar.has_method("show_boss_bar"):
            bar.show_boss_bar(boss_node)

func _on_boss_vulnerability_started(duration: float) -> void:
    push_warning("SignalBridge: _on_boss_vulnerability_started not fully implemented. Duration: %f" % duration)

func _on_boss_vulnerability_ended() -> void:
    push_warning("SignalBridge: _on_boss_vulnerability_ended not fully implemented.")

func _on_boss_phase_changed(phase_index: int, phase_name: String) -> void:
    push_warning("SignalBridge: _on_boss_phase_changed not fully implemented. Phase: %d" % phase_index)
```

## 3. 优化节点查找方式
将 `_find_node_in_tree` 的实现替换为基于 Group 的查找，或直接访问 Autoload。
对于特定的节点如 `CircleOfFifthsUpgradeV3`、`EnemySpawner`，应该使用 Group 查找。

修改 `_find_node_in_tree`：
```gdscript
func _find_node_in_tree(node_name: String) -> Node:
    if not is_inside_tree():
        return null
        
    # 优先检查 Autoload
    if Engine.has_singleton(node_name):
        return Engine.get_singleton(node_name)
    if has_node("/root/" + node_name):
        return get_node("/root/" + node_name)
        
    # 根据常用节点名映射到组名
    var group_name = ""
    match node_name:
        "EnemySpawner": group_name = "enemy_spawner"
        "BossSpawner": group_name = "boss_spawner"
        "CircleOfFifthsUpgradeV3": group_name = "upgrade_ui"
        
    if group_name != "":
        var nodes = get_tree().get_nodes_in_group(group_name)
        if nodes.size() > 0:
            return nodes[0]
            
    # 回退到旧的查找方式（给出警告）
    push_warning("SignalBridge: _find_node_in_tree using slow recursive search for '%s'. Please use Groups." % node_name)
    return _search_children(get_tree().root, node_name)
```
或者，更彻底地在 `_connect_upgrade_signals` 和 `_connect_chapter_signals` 中直接使用 `get_tree().get_first_node_in_group`。
对于 `CircleOfFifthsUpgradeV3`，由于可能没有注册 group，保留回退查找。
对于 `EnemySpawner`，修改 `_connect_chapter_signals`：`
```gdscript
var spawner: Node = get_tree().get_first_node_in_group("enemy_spawner") if get_tree().has_group("enemy_spawner") else _find_node_in_tree("EnemySpawner")
```
