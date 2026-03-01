## signal_bridge.gd
## 信号桥接器 (Autoload) — Issue #86 信号系统审计
##
## 【架构说明 — ADR 002 (P2)】
## 本模块处于向 EventBus 统一架构的过渡期。
## 职责边界：
##   - 负责：场景内动态节点（EnemySpawner、CircleOfFifthsUpgradeV3 等）的信号适配
##   - 负责：原生 Signal 对象的连接管理（防重复连接、防御性检查）
##   - 不负责：Autoload 之间的逻辑事件通信（应使用 EventBus）
##
## 设计原则：
##   - 使用 has_signal() 防御性检查，避免因信号不存在导致崩溃
##   - 使用 is_connected() 防止重复连接
##   - 所有回调函数以 _on_ 前缀命名，清晰标识信号来源
##   - 使用防重入标志（_is_processing_xxx）防止信号链循环
##
## P1 修复记录 (tsk-491969c1-ad1):
##   1. 清理12个空回调函数 — 添加 TODO 注释和 push_warning() 替代纯空体
##   2. 补充 Boss 核心信号监听 — 新增 _connect_boss_signals() 方法
##   3. 优化 _find_node_in_tree() — 优先 Autoload 直接访问，其次 Group 查找
##
## P2 修复记录 (tsk-d643a7a8-9f4):
##   1. 移除 _on_upgrade_chosen_v3 中的危险桥接 — 消除双重触发问题
##   2. 新增防重入标志 _is_processing_upgrade — 防止信号链循环
##   3. 添加架构说明注释 — 明确本模块的过渡期职责边界
extends Node

# ============================================================
# 防重入标志 (Reentrancy Guards)
# 防止信号链中的双重触发或潜在循环
# ============================================================
## 防止 upgrade_selected 在同一帧内被重复触发
var _is_processing_upgrade: bool = false

# ============================================================
# 生命周期
# ============================================================
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 延迟连接，确保所有 Autoload 已初始化
	call_deferred("_connect_all_signals")

func _connect_all_signals() -> void:
	_connect_combat_signals()
	_connect_upgrade_signals()
	_connect_resource_signals()
	_connect_chapter_signals()
	_connect_audio_signals()
	_connect_meta_progression_signals()
	# Boss 信号需要在场景树就绪后连接（ChapterManager 可能已是 Autoload）
	_connect_boss_signals()

# ============================================================
# 战斗事件信号
# ============================================================
func _connect_combat_signals() -> void:
	# enemy_killed → 统计数据已由 GameManager._ready 自连接
	# enemy_killed → VFX 已由 main_game.gd / death_vfx_manager.gd 连接
	# enemy_killed → 音效已由 damage_number_manager.gd 连接
	# player_damaged → HitFeedbackManager 已连接
	# 此处补充：player_damaged → 音效反馈（全局层面）
	if GameManager.has_signal("player_damaged"):
		if not GameManager.player_damaged.is_connected(_on_player_damaged):
			GameManager.player_damaged.connect(_on_player_damaged)
	# player_died → 统计记录
	if GameManager.has_signal("player_died"):
		if not GameManager.player_died.is_connected(_on_player_died):
			GameManager.player_died.connect(_on_player_died)

func _on_player_damaged(amount: float, source_position: Vector2) -> void:
	# 播放受击音效（通过 AudioManager）
	var audio_mgr := _get_audio_manager()
	if audio_mgr and audio_mgr.has_method("play_sfx_at_position"):
		audio_mgr.play_sfx_at_position("player_hit", source_position)

func _on_player_died() -> void:
	# TODO(P1): 补充玩家死亡时的全局统计记录或 UI 触发逻辑
	push_warning("SignalBridge: _on_player_died 收到信号，但尚未实现具体处理逻辑。")

# ============================================================
# 升级事件信号
# ============================================================
## 【P2 修复说明 — ADR 002 循环依赖消除】
##
## 原始问题（双重触发链路）：
##   CircleOfFifthsUpgradeV3._select_option()
##     -> GameManager.apply_upgrade(option)        [line 768]
##        -> GameManager.upgrade_selected.emit()   [在 apply_upgrade 内部，line 343]
##           -> SignalBridge._on_upgrade_selected() [播放音效 ①]
##     -> upgrade_chosen.emit(option)              [line 770]
##        -> SignalBridge._on_upgrade_chosen_v3()
##           -> GameManager.upgrade_selected.emit() [再次触发！]
##              -> SignalBridge._on_upgrade_selected() [播放音效 ② — 重复！]
##
## 根本原因：
##   CircleOfFifthsUpgradeV3 已在调用 apply_upgrade() 之前/之后 emit upgrade_chosen。
##   apply_upgrade() 内部已经 emit upgrade_selected。
##   因此 SignalBridge 不应再次 emit upgrade_selected，否则会造成双重触发。
##
## 修复方案：
##   1. 移除 _on_upgrade_chosen_v3 中对 GameManager.upgrade_selected.emit() 的调用。
##      理由：upgrade_selected 已由 GameManager.apply_upgrade() 内部负责触发，
##            SignalBridge 不应承担此桥接职责（违反单一职责原则）。
##   2. 保留防重入标志 _is_processing_upgrade 作为防御性保障。
##   3. 如果将来需要在 upgrade_chosen 时做额外处理，直接在此回调中实现，
##      而不是通过 emit 另一个信号来间接触发。
func _connect_upgrade_signals() -> void:
	# upgrade_chosen (CircleOfFifthsUpgradeV3) → 仅用于 SignalBridge 自身的适配逻辑
	# 【P2 注意】不再桥接到 GameManager.upgrade_selected，避免双重触发
	# CircleOfFifthsUpgradeV3 已在内部调用 GameManager.apply_upgrade()，
	# apply_upgrade() 会自动 emit upgrade_selected。
	var co5_upgrade := _find_node_in_tree("CircleOfFifthsUpgradeV3")
	if co5_upgrade and co5_upgrade.has_signal("upgrade_chosen"):
		if not co5_upgrade.upgrade_chosen.is_connected(_on_upgrade_chosen_v3):
			co5_upgrade.upgrade_chosen.connect(_on_upgrade_chosen_v3)

	# upgrade_selected (GameManager) → 更新 HUD、触发音效
	if GameManager.has_signal("upgrade_selected"):
		if not GameManager.upgrade_selected.is_connected(_on_upgrade_selected):
			GameManager.upgrade_selected.connect(_on_upgrade_selected)
	# inscription_acquired (GameManager) → 通知 UI
	if GameManager.has_signal("inscription_acquired"):
		if not GameManager.inscription_acquired.is_connected(_on_inscription_acquired):
			GameManager.inscription_acquired.connect(_on_inscription_acquired)
	# easter_egg_triggered (GameManager) → 通知 UI
	if GameManager.has_signal("easter_egg_triggered"):
		if not GameManager.easter_egg_triggered.is_connected(_on_easter_egg_triggered):
			GameManager.easter_egg_triggered.connect(_on_easter_egg_triggered)

func _on_upgrade_selected(upgrade: Dictionary) -> void:
	# 防重入保护：防止信号链中的意外重复触发
	if _is_processing_upgrade:
		push_warning("SignalBridge: _on_upgrade_selected 被重入调用，已忽略。检查信号链是否存在循环。")
		return
	_is_processing_upgrade = true

	# 播放升级音效
	var audio_mgr := _get_audio_manager()
	if audio_mgr and audio_mgr.has_method("play_global_sfx"):
		audio_mgr.play_global_sfx("upgrade_confirm")

	_is_processing_upgrade = false

func _on_upgrade_chosen_v3(upgrade: Dictionary) -> void:
	## 【P2 修复】此回调不再桥接到 GameManager.upgrade_selected。
	## 原因：GameManager.apply_upgrade() 已在 CircleOfFifthsUpgradeV3 内部被调用，
	##       apply_upgrade() 末尾会自动 emit upgrade_selected。
	## 如果需要在 upgrade_chosen 时执行额外的 SignalBridge 专属逻辑，在此处实现。
	## 当前：无需额外操作，此回调保留为扩展点。
	pass

func _on_inscription_acquired(inscription: Dictionary) -> void:
	var ins_name: String = inscription.get("name", "未知词条")
	# TODO(P1): 补充词条获取时的全局通知逻辑（如 HUD 提示、音效）
	push_warning("SignalBridge: _on_inscription_acquired 收到信号 '%s'，但尚未实现具体处理逻辑。" % ins_name)

func _on_easter_egg_triggered(egg: Dictionary) -> void:
	var egg_name: String = egg.get("name", "未知彩蛋")
	# TODO(P1): 补充彩蛋触发时的全局通知逻辑（如特效、成就解锁）
	push_warning("SignalBridge: _on_easter_egg_triggered 收到信号 '%s'，但尚未实现具体处理逻辑。" % egg_name)

# ============================================================
# 资源事件信号
# ============================================================
func _connect_resource_signals() -> void:
	# insufficient_notes (NoteInventory) → 播放警告音效、显示提示
	if NoteInventory and NoteInventory.has_signal("insufficient_notes"):
		if not NoteInventory.insufficient_notes.is_connected(_on_insufficient_notes):
			NoteInventory.insufficient_notes.connect(_on_insufficient_notes)
	# chord_spell_crafted (NoteInventory) → 播放合成音效
	if NoteInventory and NoteInventory.has_signal("chord_spell_crafted"):
		if not NoteInventory.chord_spell_crafted.is_connected(_on_chord_spell_crafted):
			NoteInventory.chord_spell_crafted.connect(_on_chord_spell_crafted)
	# inventory_changed (NoteInventory) → 日志记录
	if NoteInventory and NoteInventory.has_signal("inventory_changed"):
		if not NoteInventory.inventory_changed.is_connected(_on_inventory_changed):
			NoteInventory.inventory_changed.connect(_on_inventory_changed)

func _on_insufficient_notes(note_key: int) -> void:
	var audio_mgr := _get_audio_manager()
	if audio_mgr and audio_mgr.has_method("play_global_sfx"):
		audio_mgr.play_global_sfx("error_buzz")

func _on_chord_spell_crafted(chord_spell: Dictionary) -> void:
	var spell_name: String = chord_spell.get("name", "未知和弦")
	var audio_mgr := _get_audio_manager()
	if audio_mgr and audio_mgr.has_method("play_global_sfx"):
		audio_mgr.play_global_sfx("chord_craft_success")

func _on_inventory_changed(note_key: int, new_count: int) -> void:
	# 轻量级日志，不做重操作
	# 此回调为备用监听点，实际 UI 更新由各 HUD 组件自行处理
	pass

# ============================================================
# 章节事件信号
# ============================================================
func _connect_chapter_signals() -> void:
	# 延迟查找 ChapterManager（可能不是 Autoload）
	call_deferred("_deferred_connect_chapter_signals")

func _deferred_connect_chapter_signals() -> void:
	var chapter_mgr: Node = _get_chapter_manager()
	if not chapter_mgr:
		return

	# wave_completed / wave_started (EnemySpawner) → 更新 HUD 波次信息
	# 优先通过 Group 查找 EnemySpawner，避免低效递归遍历
	var spawner: Node = null
	if get_tree().has_group("enemy_spawner"):
		var spawners := get_tree().get_nodes_in_group("enemy_spawner")
		if spawners.size() > 0:
			spawner = spawners[0]
	if not spawner:
		spawner = _find_node_in_tree("EnemySpawner")

	if spawner:
		if spawner.has_signal("wave_completed"):
			if not spawner.wave_completed.is_connected(_on_wave_completed):
				spawner.wave_completed.connect(_on_wave_completed)
		if spawner.has_signal("wave_started"):
			if not spawner.wave_started.is_connected(_on_wave_started):
				spawner.wave_started.connect(_on_wave_started)

	# chapter_timer_updated → HUD 更新计时器
	if chapter_mgr.has_signal("chapter_timer_updated"):
		if not chapter_mgr.chapter_timer_updated.is_connected(_on_chapter_timer_updated):
			chapter_mgr.chapter_timer_updated.connect(_on_chapter_timer_updated)

	# bpm_changed → 同步 GameManager 的 BPM
	if chapter_mgr.has_signal("bpm_changed"):
		if not chapter_mgr.bpm_changed.is_connected(_on_bpm_changed):
			chapter_mgr.bpm_changed.connect(_on_bpm_changed)

	# wave_started_in_chapter → 日志
	if chapter_mgr.has_signal("wave_started_in_chapter"):
		if not chapter_mgr.wave_started_in_chapter.is_connected(_on_wave_started_in_chapter):
			chapter_mgr.wave_started_in_chapter.connect(_on_wave_started_in_chapter)

	# elite_wave_triggered → 日志
	if chapter_mgr.has_signal("elite_wave_triggered"):
		if not chapter_mgr.elite_wave_triggered.is_connected(_on_elite_wave_triggered):
			chapter_mgr.elite_wave_triggered.connect(_on_elite_wave_triggered)

	# endless_mode_started → 日志
	if chapter_mgr.has_signal("endless_mode_started"):
		if not chapter_mgr.endless_mode_started.is_connected(_on_endless_mode_started):
			chapter_mgr.endless_mode_started.connect(_on_endless_mode_started)

	# boss_health_changed → HUD Boss 血条
	if chapter_mgr.has_signal("boss_health_changed"):
		if not chapter_mgr.boss_health_changed.is_connected(_on_boss_health_changed):
			chapter_mgr.boss_health_changed.connect(_on_boss_health_changed)

func _on_wave_completed(wave_number: int) -> void:
	# TODO(P1): 补充波次完成时的全局处理逻辑（如统计更新、音效触发）
	push_warning("SignalBridge: _on_wave_completed 收到信号 wave=%d，但尚未实现具体处理逻辑。" % wave_number)

func _on_wave_started(wave_number: int, wave_type: String) -> void:
	# TODO(P1): 补充波次开始时的全局处理逻辑（如 HUD 波次提示）
	push_warning("SignalBridge: _on_wave_started 收到信号 wave=%d type=%s，但尚未实现具体处理逻辑。" % [wave_number, wave_type])

func _on_chapter_timer_updated(elapsed: float, total: float) -> void:
	# 由 HUD 轮询处理，此处仅作为备用连接点
	# 若需全局计时器逻辑，在此添加
	pass

func _on_bpm_changed(new_bpm: float) -> void:
	GameManager.current_bpm = new_bpm

func _on_wave_started_in_chapter(chapter: int, wave: int, wave_type: String) -> void:
	# TODO(P1): 补充章节内波次开始的全局处理逻辑
	push_warning("SignalBridge: _on_wave_started_in_chapter 收到信号 chapter=%d wave=%d type=%s，但尚未实现具体处理逻辑。" % [chapter, wave, wave_type])

func _on_elite_wave_triggered(chapter: int, elite_type: String) -> void:
	# TODO(P1): 补充精英波触发时的全局处理逻辑（如特殊 BGM 切换、UI 警告）
	push_warning("SignalBridge: _on_elite_wave_triggered 收到信号 chapter=%d type=%s，但尚未实现具体处理逻辑。" % [chapter, elite_type])

func _on_endless_mode_started(loop_count: int) -> void:
	# TODO(P1): 补充无尽模式开始时的全局处理逻辑（如难度提示、特殊 BGM）
	push_warning("SignalBridge: _on_endless_mode_started 收到信号 loop=%d，但尚未实现具体处理逻辑。" % loop_count)

func _on_boss_health_changed(boss_key: String, current_hp: float, max_hp: float) -> void:
	# Boss 血条由 BossHpBarUI 处理，此处转发给 Group 中的所有血条 UI
	var hp_bars := get_tree().get_nodes_in_group("boss_health_bar")
	for bar in hp_bars:
		if bar.has_method("update_hp"):
			bar.update_hp(current_hp, max_hp)

# ============================================================
# Boss 核心信号 (P1 新增)
# ============================================================
func _connect_boss_signals() -> void:
	## 连接 Boss 系统的核心信号链路。
	## Boss 信号来源：
	##   - ChapterManager.boss_spawned → 触发 Boss 生成后的全局处理
	##   - BossBase 实例信号 → 在 _on_boss_spawned 中动态连接
	##   - BossArenaDecorator 信号 → 通过 Group 查找
	call_deferred("_deferred_connect_boss_signals")

func _deferred_connect_boss_signals() -> void:
	var chapter_mgr: Node = _get_chapter_manager()
	if chapter_mgr:
		# boss_spawned → 触发 Boss 生成后的全局处理（显示血条、连接 Boss 内部信号）
		if chapter_mgr.has_signal("boss_spawned"):
			if not chapter_mgr.boss_spawned.is_connected(_on_boss_spawned):
				chapter_mgr.boss_spawned.connect(_on_boss_spawned)

		# boss_phase_changed (ChapterManager 层面) → 全局阶段变化通知
		if chapter_mgr.has_signal("boss_phase_changed"):
			if not chapter_mgr.boss_phase_changed.is_connected(_on_chapter_boss_phase_changed):
				chapter_mgr.boss_phase_changed.connect(_on_chapter_boss_phase_changed)

	# BossArenaDecorator 信号 — 通过 Group 查找
	if get_tree().has_group("boss_arena_decorator"):
		var decorators := get_tree().get_nodes_in_group("boss_arena_decorator")
		for decorator in decorators:
			_connect_arena_decorator_signals(decorator)

func _connect_arena_decorator_signals(decorator: Node) -> void:
	## 连接 BossArenaDecorator 的信号。
	if decorator.has_signal("arena_activated"):
		if not decorator.arena_activated.is_connected(_on_arena_activated):
			decorator.arena_activated.connect(_on_arena_activated)
	if decorator.has_signal("arena_deactivated"):
		if not decorator.arena_deactivated.is_connected(_on_arena_deactivated):
			decorator.arena_deactivated.connect(_on_arena_deactivated)
	if decorator.has_signal("arena_phase_changed"):
		if not decorator.arena_phase_changed.is_connected(_on_arena_phase_changed):
			decorator.arena_phase_changed.connect(_on_arena_phase_changed)

func _on_boss_spawned(boss_node: Node) -> void:
	## Boss 生成事件处理：
	##   1. 动态连接 Boss 节点的内部信号（vulnerability、phase_changed 等）
	##   2. 通知 UI 显示 Boss 血条
	if boss_node == null:
		push_warning("SignalBridge: _on_boss_spawned 收到 null boss_node，跳过处理。")
		return

	# 动态连接 BossBase 内部信号
	if boss_node.has_signal("boss_vulnerability_started"):
		if not boss_node.boss_vulnerability_started.is_connected(_on_boss_vulnerability_started):
			boss_node.boss_vulnerability_started.connect(_on_boss_vulnerability_started)

	if boss_node.has_signal("boss_vulnerability_ended"):
		if not boss_node.boss_vulnerability_ended.is_connected(_on_boss_vulnerability_ended):
			boss_node.boss_vulnerability_ended.connect(_on_boss_vulnerability_ended)

	if boss_node.has_signal("boss_phase_changed"):
		if not boss_node.boss_phase_changed.is_connected(_on_boss_phase_changed):
			boss_node.boss_phase_changed.connect(_on_boss_phase_changed)

	if boss_node.has_signal("boss_enraged"):
		if not boss_node.boss_enraged.is_connected(_on_boss_enraged):
			boss_node.boss_enraged.connect(_on_boss_enraged)

	if boss_node.has_signal("boss_defeated"):
		if not boss_node.boss_defeated.is_connected(_on_boss_defeated):
			boss_node.boss_defeated.connect(_on_boss_defeated)

	if boss_node.has_signal("boss_summon_minions"):
		if not boss_node.boss_summon_minions.is_connected(_on_boss_summon_minions):
			boss_node.boss_summon_minions.connect(_on_boss_summon_minions)

	if boss_node.has_signal("boss_attack_started"):
		if not boss_node.boss_attack_started.is_connected(_on_boss_attack_started):
			boss_node.boss_attack_started.connect(_on_boss_attack_started)

	if boss_node.has_signal("boss_attack_ended"):
		if not boss_node.boss_attack_ended.is_connected(_on_boss_attack_ended):
			boss_node.boss_attack_ended.connect(_on_boss_attack_ended)

	# 通知 UI 显示 Boss 血条（通过 Group 查找，避免硬编码路径）
	if get_tree():
		var hp_bars := get_tree().get_nodes_in_group("boss_health_bar")
		for bar in hp_bars:
			if bar.has_method("show_boss_bar"):
				bar.show_boss_bar(boss_node)

func _on_boss_vulnerability_started(duration: float) -> void:
	## Boss 进入虚弱状态：触发视觉反馈和伤害加成提示。
	# TODO(P1): 补充虚弱状态的视觉反馈逻辑（如高亮效果、UI 提示）
	push_warning("SignalBridge: Boss 进入虚弱状态，持续 %.1f 秒。待实现视觉反馈。" % duration)
	# 通知 BGMManager 切换到虚弱状态音乐（若支持）
	var bgm_mgr := _get_bgm_manager()
	if bgm_mgr and bgm_mgr.has_method("on_boss_vulnerability_started"):
		bgm_mgr.on_boss_vulnerability_started(duration)

func _on_boss_vulnerability_ended() -> void:
	## Boss 虚弱状态结束：恢复正常视觉和音乐。
	# TODO(P1): 补充虚弱状态结束的视觉恢复逻辑
	push_warning("SignalBridge: Boss 虚弱状态结束。待实现视觉恢复。")
	var bgm_mgr := _get_bgm_manager()
	if bgm_mgr and bgm_mgr.has_method("on_boss_vulnerability_ended"):
		bgm_mgr.on_boss_vulnerability_ended()

func _on_boss_phase_changed(phase_index: int, phase_name: String) -> void:
	## Boss 阶段变化（来自 BossBase 实例）：更新血条 UI 阶段显示。
	push_warning("SignalBridge: Boss 阶段变化 → phase=%d name=%s" % [phase_index, phase_name])
	# 通知血条 UI 更新阶段
	if get_tree():
		var hp_bars := get_tree().get_nodes_in_group("boss_health_bar")
		for bar in hp_bars:
			if bar.has_method("set_phase"):
				bar.set_phase(phase_index)

func _on_chapter_boss_phase_changed(boss_key: String, phase: int) -> void:
	## Boss 阶段变化（来自 ChapterManager 层面）：日志记录。
	push_warning("SignalBridge: ChapterManager 报告 Boss '%s' 阶段变化 → phase=%d" % [boss_key, phase])

func _on_boss_enraged(enrage_level: int) -> void:
	## Boss 进入狂暴状态：触发视觉和音频强化效果。
	# TODO(P1): 补充狂暴状态的视觉/音效处理逻辑
	push_warning("SignalBridge: Boss 进入狂暴状态，等级=%d。待实现视觉/音效强化。" % enrage_level)
	var bgm_mgr := _get_bgm_manager()
	if bgm_mgr and bgm_mgr.has_method("on_boss_enraged"):
		bgm_mgr.on_boss_enraged(enrage_level)

func _on_boss_defeated() -> void:
	## Boss 被击败：隐藏血条、触发结算逻辑。
	push_warning("SignalBridge: Boss 被击败。触发血条隐藏和结算逻辑。")
	if get_tree():
		var hp_bars := get_tree().get_nodes_in_group("boss_health_bar")
		for bar in hp_bars:
			if bar.has_method("hide_boss_bar"):
				bar.hide_boss_bar()

func _on_boss_summon_minions(count: int, type: String) -> void:
	## Boss 召唤小兵：日志记录。
	# TODO(P1): 补充召唤小兵时的全局处理逻辑（如 UI 提示）
	push_warning("SignalBridge: Boss 召唤 %d 个 '%s' 类型小兵。待实现全局处理。" % [count, type])

func _on_boss_attack_started(attack_name: String) -> void:
	## Boss 开始攻击：日志记录。
	# TODO(P2): 可在此添加攻击预警 UI 逻辑
	pass  # 高频信号，不使用 push_warning 避免日志污染

func _on_boss_attack_ended(attack_name: String) -> void:
	## Boss 攻击结束：日志记录。
	# TODO(P2): 可在此添加攻击结束的视觉清理逻辑
	pass  # 高频信号，不使用 push_warning 避免日志污染

func _on_arena_activated(boss_key: String) -> void:
	## Boss 竞技场激活：触发环境特效和区域封锁。
	push_warning("SignalBridge: Boss 竞技场激活，boss_key='%s'。待实现区域封锁逻辑。" % boss_key)

func _on_arena_deactivated() -> void:
	## Boss 竞技场停用：恢复正常环境。
	push_warning("SignalBridge: Boss 竞技场停用。待实现环境恢复逻辑。")

func _on_arena_phase_changed(phase_index: int) -> void:
	## 竞技场阶段变化：同步视觉效果。
	push_warning("SignalBridge: 竞技场阶段变化 → phase=%d。待实现视觉同步。" % phase_index)

# ============================================================
# 音频事件信号
# ============================================================
func _connect_audio_signals() -> void:
	# BgmManager 信号
	var bgm_mgr: Node = _get_bgm_manager()
	if bgm_mgr:
		if bgm_mgr.has_signal("intensity_changed"):
			if not bgm_mgr.intensity_changed.is_connected(_on_bgm_intensity_changed):
				bgm_mgr.intensity_changed.connect(_on_bgm_intensity_changed)
		if bgm_mgr.has_signal("layer_toggled"):
			if not bgm_mgr.layer_toggled.is_connected(_on_bgm_layer_toggled):
				bgm_mgr.layer_toggled.connect(_on_bgm_layer_toggled)
		if bgm_mgr.has_signal("tonality_changed"):
			if not bgm_mgr.tonality_changed.is_connected(_on_tonality_changed):
				bgm_mgr.tonality_changed.connect(_on_tonality_changed)

	# MusicTheoryEngine 信号
	if MusicTheoryEngine and MusicTheoryEngine.has_signal("progression_triggered"):
		if not MusicTheoryEngine.progression_triggered.is_connected(_on_progression_triggered):
			MusicTheoryEngine.progression_triggered.connect(_on_progression_triggered)

	# ModeSystem 信号
	if ModeSystem and ModeSystem.has_signal("transpose_changed"):
		if not ModeSystem.transpose_changed.is_connected(_on_transpose_changed):
			ModeSystem.transpose_changed.connect(_on_transpose_changed)

func _on_bgm_intensity_changed(new_intensity: float) -> void:
	# TODO(P2): 可用于驱动视觉强度（如屏幕边缘光晕、粒子密度）
	pass  # 此处保留备用，视觉强度由各视觉组件自行订阅

func _on_bgm_layer_toggled(layer_name: String, enabled: bool) -> void:
	# TODO(P2): 可用于同步视觉层（如音乐层对应的视觉元素显隐）
	pass  # 此处保留备用，视觉层同步由各视觉组件自行订阅

func _on_tonality_changed(chapter_id: int, mode_name: String, scale_notes: Array) -> void:
	# TODO(P2): 可用于更新 UI 调性显示（如调式名称标签）
	pass  # 此处保留备用，调性 UI 由 HUD 组件自行订阅

func _on_progression_triggered(effect_type: String, bonus_multiplier: float) -> void:
	# TODO(P1): 补充和声进行触发时的全局处理逻辑（如全局增益特效）
	push_warning("SignalBridge: _on_progression_triggered 收到信号 type=%s mult=%.2f，但尚未实现具体处理逻辑。" % [effect_type, bonus_multiplier])

func _on_transpose_changed(semitone_offset: int) -> void:
	# TODO(P1): 补充移调变化时的全局处理逻辑（如 UI 调性指示器更新）
	push_warning("SignalBridge: _on_transpose_changed 收到信号 offset=%d，但尚未实现具体处理逻辑。" % semitone_offset)

# ============================================================
# 局外成长信号
# ============================================================
func _connect_meta_progression_signals() -> void:
	var meta_mgr: Node = null
	if has_node("/root/MetaProgressionManager"):
		meta_mgr = get_node("/root/MetaProgressionManager")
	if not meta_mgr:
		return

	if meta_mgr.has_signal("mode_unlocked"):
		if not meta_mgr.mode_unlocked.is_connected(_on_mode_unlocked):
			meta_mgr.mode_unlocked.connect(_on_mode_unlocked)
	if meta_mgr.has_signal("mode_selected"):
		if not meta_mgr.mode_selected.is_connected(_on_mode_selected):
			meta_mgr.mode_selected.connect(_on_mode_selected)
	if meta_mgr.has_signal("theory_unlocked"):
		if not meta_mgr.theory_unlocked.is_connected(_on_theory_unlocked):
			meta_mgr.theory_unlocked.connect(_on_theory_unlocked)
	if meta_mgr.has_signal("resonance_changed"):
		pass  # resonance_fragments_changed 已由 HallOfHarmony 连接

	# SaveManager.resonance_changed
	if SaveManager and SaveManager.has_signal("resonance_changed"):
		if not SaveManager.resonance_changed.is_connected(_on_resonance_changed):
			SaveManager.resonance_changed.connect(_on_resonance_changed)

func _on_mode_unlocked(mode_name: String) -> void:
	# TODO(P1): 补充模式解锁时的全局通知逻辑（如解锁提示 UI、音效）
	push_warning("SignalBridge: _on_mode_unlocked 收到信号 mode='%s'，但尚未实现具体处理逻辑。" % mode_name)

func _on_mode_selected(mode_name: String) -> void:
	# TODO(P1): 补充模式选择时的全局处理逻辑（如 BGM 切换）
	push_warning("SignalBridge: _on_mode_selected 收到信号 mode='%s'，但尚未实现具体处理逻辑。" % mode_name)

func _on_theory_unlocked(theory_id: String) -> void:
	# TODO(P1): 补充乐理解锁时的全局通知逻辑（如成就系统触发）
	push_warning("SignalBridge: _on_theory_unlocked 收到信号 theory='%s'，但尚未实现具体处理逻辑。" % theory_id)

func _on_resonance_changed(amount: int) -> void:
	# TODO(P1): 补充共鸣值变化时的全局处理逻辑（如 HUD 更新）
	push_warning("SignalBridge: _on_resonance_changed 收到信号 amount=%d，但尚未实现具体处理逻辑。" % amount)

# ============================================================
# 辅助函数
# ============================================================
func _get_audio_manager() -> Node:
	if has_node("/root/AudioManager"):
		return get_node("/root/AudioManager")
	return null

func _get_bgm_manager() -> Node:
	if has_node("/root/BGMManager"):
		return get_node("/root/BGMManager")
	return null

func _get_chapter_manager() -> Node:
	## 获取 ChapterManager 节点，优先直接访问 Autoload。
	## ChapterManager 已在 project.godot 中注册为 Autoload，应直接通过 /root 访问。
	if has_node("/root/ChapterManager"):
		return get_node("/root/ChapterManager")
	# 回退：通过 Engine 单例访问
	if Engine.has_singleton("ChapterManager"):
		return Engine.get_singleton("ChapterManager")
	return null

func _find_node_in_tree(node_name: String) -> Node:
	## 在场景树中查找指定名称的节点。
	## 优化策略（P1 修复）：
	##   1. 优先检查 Autoload（直接路径访问，O(1)）
	##   2. 其次通过 Group 查找（已知节点类型的快速路径）
	##   3. 最后回退到递归遍历（保留兼容性，但输出警告）
	if not is_inside_tree():
		return null

	# 策略1：直接访问 Autoload
	if has_node("/root/" + node_name):
		return get_node("/root/" + node_name)

	# 策略2：通过 Group 查找（常用场景节点的快速路径）
	var group_map: Dictionary = {
		"EnemySpawner": "enemy_spawner",
		"BossSpawner": "boss_spawner",
		"BossArenaDecorator": "boss_arena_decorator",
		"CircleOfFifthsUpgradeV3": "upgrade_ui",
		"ChapterManager": "chapter_manager",
	}
	if group_map.has(node_name) and get_tree():
		var group_name: String = group_map[node_name]
		if get_tree().has_group(group_name):
			var nodes := get_tree().get_nodes_in_group(group_name)
			if nodes.size() > 0:
				return nodes[0]

	# 策略3：递归遍历（回退路径，性能较低）
	push_warning("SignalBridge: _find_node_in_tree('%s') 使用低效的递归遍历。建议为该节点添加 Group 注册。" % node_name)
	return _search_children(get_tree().root, node_name)

func _search_children(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var result := _search_children(child, target_name)
		if result:
			return result
	return null
