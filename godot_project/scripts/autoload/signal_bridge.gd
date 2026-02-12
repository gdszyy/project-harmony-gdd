## signal_bridge.gd
## 信号桥接器 (Autoload) — Issue #86 信号系统审计
##
## 功能：
##   - 集中连接项目中已触发(emit)但未被监听(connect)的核心信号
##   - 将战斗、法术、升级、资源、章节等事件信号路由到对应的处理逻辑
##   - 避免在各个脚本中分散添加连接，统一管理信号生命周期
##
## 设计原则：
##   - 使用 has_signal() 防御性检查，避免因信号不存在导致崩溃
##   - 使用 is_connected() 防止重复连接
##   - 所有回调函数以 _on_ 前缀命名，清晰标识信号来源
extends Node

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
	print("[SignalBridge] All core signal connections established.")

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
	print("[SignalBridge] Player died — session ended.")

# ============================================================
# 升级事件信号
# ============================================================
func _connect_upgrade_signals() -> void:
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
	var upgrade_name: String = upgrade.get("name", "未知升级")
	var category: String = upgrade.get("category", "unknown")
	print("[SignalBridge] Upgrade applied: %s (category: %s)" % [upgrade_name, category])
	# 播放升级音效
	var audio_mgr := _get_audio_manager()
	if audio_mgr and audio_mgr.has_method("play_global_sfx"):
		audio_mgr.play_global_sfx("upgrade_confirm")

func _on_inscription_acquired(inscription: Dictionary) -> void:
	var ins_name: String = inscription.get("name", "未知词条")
	print("[SignalBridge] Inscription acquired: %s" % ins_name)

func _on_easter_egg_triggered(egg: Dictionary) -> void:
	var egg_name: String = egg.get("name", "未知彩蛋")
	print("[SignalBridge] Easter egg triggered: %s" % egg_name)

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
	print("[SignalBridge] Insufficient notes for key: %d" % note_key)
	var audio_mgr := _get_audio_manager()
	if audio_mgr and audio_mgr.has_method("play_global_sfx"):
		audio_mgr.play_global_sfx("error_buzz")

func _on_chord_spell_crafted(chord_spell: Dictionary) -> void:
	var spell_name: String = chord_spell.get("name", "未知和弦")
	print("[SignalBridge] Chord spell crafted: %s" % spell_name)
	var audio_mgr := _get_audio_manager()
	if audio_mgr and audio_mgr.has_method("play_global_sfx"):
		audio_mgr.play_global_sfx("chord_craft_success")

func _on_inventory_changed(note_key: int, new_count: int) -> void:
	# 轻量级日志，不做重操作
	pass

# ============================================================
# 章节事件信号
# ============================================================
func _connect_chapter_signals() -> void:
	# 延迟查找 ChapterManager（可能不是 Autoload）
	call_deferred("_deferred_connect_chapter_signals")

func _deferred_connect_chapter_signals() -> void:
	var chapter_mgr: Node = null
	if Engine.has_singleton("ChapterManager"):
		chapter_mgr = Engine.get_singleton("ChapterManager")
	elif has_node("/root/ChapterManager"):
		chapter_mgr = get_node("/root/ChapterManager")
	else:
		# 尝试在场景树中查找
		chapter_mgr = _find_node_in_tree("ChapterManager")

	if not chapter_mgr:
		return

	# wave_completed (EnemySpawner) → 更新 HUD 波次信息
	# wave_started (EnemySpawner) → 更新 HUD 波次信息
	# 这些信号在 EnemySpawner 上，需要查找实例
	var spawner: Node = _find_node_in_tree("EnemySpawner")
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
	print("[SignalBridge] Wave %d completed." % wave_number)

func _on_wave_started(wave_number: int, wave_type: String) -> void:
	print("[SignalBridge] Wave %d started (type: %s)." % [wave_number, wave_type])

func _on_chapter_timer_updated(elapsed: float, total: float) -> void:
	# 由 HUD 轮询处理，此处仅作为备用连接点
	pass

func _on_bpm_changed(new_bpm: float) -> void:
	GameManager.current_bpm = new_bpm
	print("[SignalBridge] BPM changed to: %.1f" % new_bpm)

func _on_wave_started_in_chapter(chapter: int, wave: int, wave_type: String) -> void:
	print("[SignalBridge] Chapter %d, Wave %d started (type: %s)." % [chapter, wave, wave_type])

func _on_elite_wave_triggered(chapter: int, elite_type: String) -> void:
	print("[SignalBridge] Elite wave triggered in chapter %d: %s" % [chapter, elite_type])

func _on_endless_mode_started(loop_count: int) -> void:
	print("[SignalBridge] Endless mode started — loop %d." % loop_count)

func _on_boss_health_changed(boss_key: String, current_hp: float, max_hp: float) -> void:
	# Boss 血条由 BossHpBarUI 处理，此处仅作为备用
	pass

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
	pass  # 可用于驱动视觉强度

func _on_bgm_layer_toggled(layer_name: String, enabled: bool) -> void:
	pass  # 可用于同步视觉层

func _on_tonality_changed(chapter_id: int, mode_name: String, scale_notes: Array) -> void:
	pass  # 可用于更新 UI 调性显示

func _on_progression_triggered(effect_type: String, bonus_multiplier: float) -> void:
	print("[SignalBridge] Music progression triggered: %s (x%.2f)" % [effect_type, bonus_multiplier])

func _on_transpose_changed(semitone_offset: int) -> void:
	print("[SignalBridge] Transpose changed: %d semitones" % semitone_offset)

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
	print("[SignalBridge] Mode unlocked: %s" % mode_name)

func _on_mode_selected(mode_name: String) -> void:
	print("[SignalBridge] Mode selected: %s" % mode_name)

func _on_theory_unlocked(theory_id: String) -> void:
	print("[SignalBridge] Theory unlocked: %s" % theory_id)

func _on_resonance_changed(amount: int) -> void:
	print("[SignalBridge] Resonance fragments: %d" % amount)

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

func _find_node_in_tree(node_name: String) -> Node:
	if not is_inside_tree():
		return null
	var root := get_tree().root
	return _search_children(root, node_name)

func _search_children(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var result := _search_children(child, target_name)
		if result:
			return result
	return null
