## manual_slot_config_v3.gd
## v3.0 手动施法槽配置面板 (Manual Casting Slots)
##
## 位于一体化编曲台中央区域下半部分，功能包括：
##   - 3个手动施法槽（对应快捷键 1, 2, 3）
##   - 支持拖入音符或和弦法术
##   - 对齐到八分音符精度（每小节8个施法时机）
##   - 右键清除槽位
##   - 冷却进度显示
##
## 使用 Godot 内置拖拽 API
## 与 SpellcraftSystem、NoteInventory 全局单例对接
extends Control

# ============================================================
# 信号
# ============================================================
## 槽位配置变更时触发
signal slot_configured(slot_index: int, spell_data: Dictionary)
## 信息悬停（供主面板信息栏使用）
signal info_hover(title: String, desc: String, color: Color)

# ============================================================
# 常量
# ============================================================
## 施法槽配置
const SLOT_COUNT: int = 3
const SLOT_KEYS := ["1", "2", "3"]

## 施法槽尺寸
const SLOT_SIZE := Vector2(64, 64)
const SLOT_GAP := 16.0
const KEY_LABEL_HEIGHT := 16.0

## 颜色定义
const SLOT_EMPTY_BG := Color("141026B0")
const SLOT_HOVER_BG := Color("9D6FFF30")
const SLOT_FILLED_BG := Color("1A1433D0")
const SLOT_DROP_HIGHLIGHT := Color("00FFD466")
const SLOT_BORDER := Color("9D6FFF50")
const SLOT_ACTIVE_BORDER := Color("00FFD4CC")
const KEY_LABEL_COLOR := Color("9D8FBF")
const KEY_LABEL_BG := Color("9D6FFF20")
const COOLDOWN_OVERLAY := Color("00000080")
const SECTION_TITLE_COLOR := Color("9D8FBF")

## 音符颜色
const NOTE_COLORS := {
	0: Color("00FFD4"), 1: Color("0088FF"), 2: Color("66FF66"),
	3: Color("8844FF"), 4: Color("FF4444"), 5: Color("FF8800"),
	6: Color("FF44AA"),
}

## 法术形态颜色
const SPELL_FORM_COLORS := {
	"enhanced_projectile": Color("FFD94D"),
	"dot_projectile": Color("3366CC"),
	"explosive_projectile": Color("FF6633"),
	"shockwave": Color("8822BB"),
	"magic_circle": Color("FFCC00"),
	"celestial_strike": Color("CC1111"),
	"shield_heal": Color("33E666"),
	"summon_construct": Color("2233BB"),
	"charged_projectile": Color("D9D9F2"),
	"slow_field": Color("4D4DBB"),
	"generic_blast": Color("808080"),
}

## 法术形态图标
const SPELL_FORM_ICONS := {
	"enhanced_projectile": "▲",
	"dot_projectile": "💧",
	"explosive_projectile": "✦",
	"shockwave": "◎",
	"magic_circle": "◉",
	"celestial_strike": "⚡",
	"shield_heal": "✚",
	"summon_construct": "▣",
	"charged_projectile": "⌛",
	"slow_field": "◐",
	"generic_blast": "●",
}

# ============================================================
# 状态
# ============================================================
## 施法槽配置数据
var _slot_configs: Array[Dictionary] = []
## 施法槽矩形缓存
var _slot_rects: Array[Rect2] = []
## 悬停状态
var _hover_slot: int = -1
## 拖拽放置悬停
var _drop_hover_slot: int = -1

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	## 初始化槽位
	_slot_configs.clear()
	for i in range(SLOT_COUNT):
		_slot_configs.append({ "type": "empty" })

	## 同步 SpellcraftSystem 的手动施法槽数据
	_sync_from_system()

	## 计算最小尺寸
	var total_w := SLOT_COUNT * (SLOT_SIZE.x + SLOT_GAP) - SLOT_GAP + 20
	var total_h := 20 + KEY_LABEL_HEIGHT + SLOT_SIZE.y + 10  # 标题 + 快捷键标签 + 槽位 + 留白
	custom_minimum_size = Vector2(total_w, total_h)

	mouse_filter = Control.MOUSE_FILTER_STOP

# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	var font := ThemeDB.fallback_font
	_slot_rects.clear()

	var x := 10.0
	var y := 4.0

	## ===== 标题 =====
	draw_string(font, Vector2(x, y + 12), "MANUAL CAST  手动施法",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, SECTION_TITLE_COLOR)
	y += 20.0

	## ===== 施法槽 =====
	var slots_start_x := x + (size.x - 20 - SLOT_COUNT * (SLOT_SIZE.x + SLOT_GAP) + SLOT_GAP) / 2.0

	for i in range(SLOT_COUNT):
		var slot_x := slots_start_x + i * (SLOT_SIZE.x + SLOT_GAP)

		## 快捷键标签
		var key_rect := Rect2(
			Vector2(slot_x + SLOT_SIZE.x / 2.0 - 10, y),
			Vector2(20, KEY_LABEL_HEIGHT)
		)
		draw_rect(key_rect, KEY_LABEL_BG)
		draw_string(font,
			Vector2(slot_x + SLOT_SIZE.x / 2.0 - 3, y + 12),
			SLOT_KEYS[i], HORIZONTAL_ALIGNMENT_CENTER, -1, 11, KEY_LABEL_COLOR)

		## 施法槽
		var slot_y := y + KEY_LABEL_HEIGHT + 4
		var rect := Rect2(Vector2(slot_x, slot_y), SLOT_SIZE)
		_slot_rects.append(rect)

		var config := _slot_configs[i]
		var slot_type: String = config.get("type", "empty")
		var is_hover := (_hover_slot == i)
		var is_drop_hover := (_drop_hover_slot == i)

		## 背景色
		var bg := SLOT_EMPTY_BG
		if slot_type != "empty":
			bg = SLOT_FILLED_BG
		if is_hover:
			bg = SLOT_HOVER_BG
		if is_drop_hover:
			bg = SLOT_DROP_HIGHLIGHT

		draw_rect(rect, bg)

		## 边框
		var border := SLOT_BORDER
		if is_drop_hover:
			border = SLOT_ACTIVE_BORDER
		draw_rect(rect, border, false, 1.5)

		## 内容
		match slot_type:
			"note":
				var note_key: int = config.get("note", 0)
				var note_color: Color = NOTE_COLORS.get(note_key, Color(0.5, 0.5, 0.5))
				## 色块背景
				draw_rect(rect.grow(-4), Color(note_color.r, note_color.g, note_color.b, 0.25))
				## 音符名称
				var name_str: String = MusicData.WHITE_KEY_STATS.get(note_key, {}).get("name", "?")
				draw_string(font,
					rect.position + Vector2(rect.size.x / 2.0 - 6, rect.size.y / 2.0 + 6),
					name_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 20, note_color)
			"chord":
				var spell_id: String = config.get("spell_id", "")
				var spell := NoteInventory.get_chord_spell(spell_id)
				if not spell.is_empty():
					var spell_form: String = spell.get("spell_form", "generic_blast")
					var form_color: Color = SPELL_FORM_COLORS.get(spell_form, Color.WHITE)
					var form_icon: String = SPELL_FORM_ICONS.get(spell_form, "●")
					## 色块背景
					draw_rect(rect.grow(-4), Color(form_color.r, form_color.g, form_color.b, 0.2))
					## 法术图标
					draw_string(font,
						rect.position + Vector2(rect.size.x / 2.0 - 6, rect.size.y / 2.0 + 6),
						form_icon, HORIZONTAL_ALIGNMENT_CENTER, -1, 22, form_color)
				else:
					## 法术已不存在
					draw_string(font,
						rect.position + Vector2(rect.size.x / 2.0 - 4, rect.size.y / 2.0 + 4),
						"?", HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color("FF4444"))
			"empty":
				## 空槽位提示
				draw_string(font,
					rect.position + Vector2(rect.size.x / 2.0 - 6, rect.size.y / 2.0 + 4),
					"—", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color("9D8FBF40"))

		## 冷却进度覆盖
		var cd_progress := SpellcraftSystem.get_manual_slot_cooldown_progress(i)
		if cd_progress > 0 and cd_progress < 1.0:
			var cd_height := rect.size.y * (1.0 - cd_progress)
			var cd_rect := Rect2(
				rect.position + Vector2(0, rect.size.y - cd_height),
				Vector2(rect.size.x, cd_height)
			)
			draw_rect(cd_rect, COOLDOWN_OVERLAY)

# ============================================================
# 鼠标交互
# ============================================================

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover(event.position)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			## 右键清除槽位
			for i in range(_slot_rects.size()):
				if _slot_rects[i].has_point(event.position):
					_clear_slot(i)
					break

## 更新悬停状态
func _update_hover(pos: Vector2) -> void:
	var old_hover := _hover_slot
	_hover_slot = -1

	for i in range(_slot_rects.size()):
		if _slot_rects[i].has_point(pos):
			_hover_slot = i
			break

	if _hover_slot != old_hover:
		if _hover_slot >= 0:
			_emit_slot_info(_hover_slot)
		queue_redraw()

## 发送槽位信息
func _emit_slot_info(idx: int) -> void:
	var config := _slot_configs[idx]
	var slot_type: String = config.get("type", "empty")

	match slot_type:
		"note":
			var note_key: int = config.get("note", 0)
			var name_str: String = MusicData.WHITE_KEY_STATS.get(note_key, {}).get("name", "?")
			var color: Color = NOTE_COLORS.get(note_key, Color.WHITE)
			info_hover.emit(
				"手动施法槽 [%s] — %s 音符" % [SLOT_KEYS[idx], name_str],
				"按键 %s 释放 | 对齐八分音符精度 | 右键清除" % SLOT_KEYS[idx],
				color
			)
		"chord":
			var spell_id: String = config.get("spell_id", "")
			var spell := NoteInventory.get_chord_spell(spell_id)
			var spell_name: String = spell.get("spell_name", "Unknown") if not spell.is_empty() else "Unknown"
			var spell_form: String = spell.get("spell_form", "generic_blast") if not spell.is_empty() else "generic_blast"
			var form_color: Color = SPELL_FORM_COLORS.get(spell_form, Color.WHITE)
			info_hover.emit(
				"手动施法槽 [%s] — %s" % [SLOT_KEYS[idx], spell_name],
				"按键 %s 释放 | 对齐八分音符精度 | 右键清除" % SLOT_KEYS[idx],
				form_color
			)
		"empty":
			info_hover.emit(
				"手动施法槽 [%s] — 空" % SLOT_KEYS[idx],
				"拖入音符或和弦法术 | 战斗中按 %s 释放" % SLOT_KEYS[idx],
				Color("9D8FBF")
			)

# ============================================================
# Godot 内置拖拽 API
# ============================================================

## 从施法槽拖出
func _get_drag_data(at_position: Vector2) -> Variant:
	for i in range(_slot_rects.size()):
		if _slot_rects[i].has_point(at_position):
			var config := _slot_configs[i]
			var slot_type: String = config.get("type", "empty")

			if slot_type == "note":
				var note_key: int = config.get("note", 0)
				var name_str: String = MusicData.WHITE_KEY_STATS.get(note_key, {}).get("name", "?")
				var color: Color = NOTE_COLORS.get(note_key, Color(0.5, 0.5, 0.5))

				## 清除槽位（归还音符）
				_clear_slot_internal(i)
				_slot_configs[i] = { "type": "empty" }

				var preview := _create_drag_preview(name_str, color)
				set_drag_preview(preview)

				return {
					"type": "note",
					"note_key": note_key,
					"source": "manual_slot",
					"source_idx": i,
				}
			elif slot_type == "chord":
				var spell_id: String = config.get("spell_id", "")
				var spell := NoteInventory.get_chord_spell(spell_id)
				var spell_name: String = spell.get("spell_name", "?") if not spell.is_empty() else "?"
				var spell_form: String = spell.get("spell_form", "generic_blast") if not spell.is_empty() else "generic_blast"
				var form_color: Color = SPELL_FORM_COLORS.get(spell_form, Color.WHITE)

				## 清除槽位（归还法术到法术书）
				_clear_slot_internal(i)
				_slot_configs[i] = { "type": "empty" }

				var form_icon: String = SPELL_FORM_ICONS.get(spell_form, "●")
				var preview := _create_drag_preview(form_icon, form_color)
				set_drag_preview(preview)

				return {
					"type": "chord_spell",
					"spell_id": spell_id,
					"spell_name": spell_name,
					"spell_form": spell_form,
					"source": "manual_slot",
					"source_idx": i,
				}
	return null

## 判断是否可以接受拖拽放置
func _can_drop_data(at_position: Vector2, data) -> bool:
	if data == null or not data is Dictionary:
		_drop_hover_slot = -1
		return false

	var drag_type: String = data.get("type", "")
	## 施法槽接受音符和和弦法术
	if drag_type not in ["note", "chord_spell"]:
		_drop_hover_slot = -1
		return false

	for i in range(_slot_rects.size()):
		if _slot_rects[i].has_point(at_position):
			_drop_hover_slot = i
			queue_redraw()
			return true

	_drop_hover_slot = -1
	return false

## 处理拖拽放置
func _drop_data(at_position: Vector2, data) -> void:
	_drop_hover_slot = -1

	if data == null or not data is Dictionary:
		return

	var drag_type: String = data.get("type", "")
	var target_slot := -1

	for i in range(_slot_rects.size()):
		if _slot_rects[i].has_point(at_position):
			target_slot = i
			break

	if target_slot < 0:
		return

	match drag_type:
		"note":
			var note_key: int = data.get("note_key", 0)
			_configure_note_slot(target_slot, note_key)
		"chord_spell":
			var spell_id: String = data.get("spell_id", "")
			_configure_chord_slot(target_slot, spell_id)

	queue_redraw()

# ============================================================
# 槽位操作
# ============================================================

## 配置音符到施法槽
func _configure_note_slot(idx: int, note_key: int) -> void:
	## 先清除旧内容
	_clear_slot_internal(idx)

	## 通过 SpellcraftSystem 设置（自动处理库存装备）
	var spell_data := { "type": "note", "note": note_key }
	SpellcraftSystem.set_manual_slot(idx, spell_data)
	_slot_configs[idx] = spell_data
	slot_configured.emit(idx, spell_data)

## 配置和弦法术到施法槽
func _configure_chord_slot(idx: int, spell_id: String) -> void:
	## 先清除旧内容
	_clear_slot_internal(idx)

	var spell_data := { "type": "chord", "spell_id": spell_id }
	SpellcraftSystem.set_manual_slot(idx, spell_data)
	_slot_configs[idx] = spell_data
	slot_configured.emit(idx, spell_data)

## 清除施法槽（外部调用）
func _clear_slot(idx: int) -> void:
	_clear_slot_internal(idx)
	_slot_configs[idx] = { "type": "empty" }
	queue_redraw()

## 清除施法槽内部逻辑
func _clear_slot_internal(idx: int) -> void:
	SpellcraftSystem.clear_manual_slot(idx)

## 从 SpellcraftSystem 同步数据
func _sync_from_system() -> void:
	for i in range(SLOT_COUNT):
		if i < SpellcraftSystem.manual_cast_slots.size():
			_slot_configs[i] = SpellcraftSystem.manual_cast_slots[i].duplicate()
		else:
			_slot_configs[i] = { "type": "empty" }

## 刷新面板
func refresh() -> void:
	_sync_from_system()
	queue_redraw()

# ============================================================
# 工具方法
# ============================================================

## 创建拖拽预览控件
func _create_drag_preview(text: String, color: Color) -> Control:
	var preview := Control.new()
	var sz := SLOT_SIZE
	preview.custom_minimum_size = sz
	preview.size = sz

	var panel := Panel.new()
	panel.custom_minimum_size = sz
	panel.size = sz

	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.5)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(color.r, color.g, color.b, 0.6)
	style.shadow_size = 5
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = sz
	label.size = sz
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 18)

	preview.add_child(panel)
	preview.add_child(label)
	return preview
