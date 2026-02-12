## manual_cast_slot.gd — 手动施法槽冷却 UI
## 屏幕左下角 3 个方形槽位，支持冷却遮罩、法力不足闪烁、电流特效
## 使用 _draw() 实现自定义绘制
extends Control

# ============================================================
# 配置
# ============================================================
const SLOT_COUNT: int = 3
const SLOT_SIZE: float = 64.0
const SLOT_GAP: float = 8.0
const TOTAL_WIDTH: float = SLOT_SIZE * SLOT_COUNT + SLOT_GAP * (SLOT_COUNT - 1) + 20
const TOTAL_HEIGHT: float = SLOT_SIZE + 20.0

# 颜色
const COLOR_ACCENT      := Color(0.616, 0.435, 1.0)     # #9D6FFF 主强调色
const COLOR_ABYSS_BLACK := Color(0.039, 0.031, 0.078)    # #0A0814 深渊黑
const COLOR_CRYSTAL_WHITE := Color(0.918, 0.902, 1.0)    # #EAE6FF 晶体白
const COLOR_ERROR_RED   := Color(1.0, 0.133, 0.267)      # #FF2244 错误红
const COLOR_STARRY_PURPLE := Color(0.078, 0.063, 0.149)  # #141026 星空紫

# 按键标签
const KEY_LABELS := ["Q", "W", "E"]

# ============================================================
# 槽位数据
# ============================================================
## 每个槽位: {spell_name: String, icon_color: Color, cooldown_max: float,
##            cooldown_current: float, mana_sufficient: bool, available: bool}
var _slots: Array[Dictionary] = []
var _time: float = 0.0
var _beat_intensity: float = 0.0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	custom_minimum_size = Vector2(TOTAL_WIDTH, TOTAL_HEIGHT)
	size = Vector2(TOTAL_WIDTH, TOTAL_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 初始化槽位
	for i in range(SLOT_COUNT):
		_slots.append({
			"spell_name": "",
			"icon_color": COLOR_ACCENT,
			"cooldown_max": 0.0,
			"cooldown_current": 0.0,
			"mana_sufficient": true,
			"available": true,
			"flash_timer": 0.0,
		})

	# 连接信号
	if GameManager.has_signal("beat_tick"):
		GameManager.beat_tick.connect(_on_beat_tick)
	if SpellcraftSystem.has_signal("manual_slot_updated"):
		SpellcraftSystem.manual_slot_updated.connect(_on_slot_updated)

func _process(delta: float) -> void:
	_time += delta
	_beat_intensity = max(0.0, _beat_intensity - delta * 4.0)

	# 更新冷却
	for slot in _slots:
		if slot["cooldown_current"] > 0:
			slot["cooldown_current"] = max(0.0, slot["cooldown_current"] - delta)
			if slot["cooldown_current"] <= 0:
				slot["flash_timer"] = 0.3  # 冷却完成闪光
		if slot["flash_timer"] > 0:
			slot["flash_timer"] = max(0.0, slot["flash_timer"] - delta)

	queue_redraw()

# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	var font := ThemeDB.fallback_font

	for i in range(SLOT_COUNT):
		var slot: Dictionary = _slots[i]
		var slot_x := 10.0 + i * (SLOT_SIZE + SLOT_GAP)
		var slot_y := 10.0
		var slot_rect := Rect2(Vector2(slot_x, slot_y), Vector2(SLOT_SIZE, SLOT_SIZE))

		var is_available: bool = slot["available"]
		var is_cooling: bool = slot["cooldown_current"] > 0
		var mana_ok: bool = slot["mana_sufficient"]
		var flash: float = slot["flash_timer"]

		# === 1. 槽位背景 ===
		draw_rect(slot_rect, Color(COLOR_STARRY_PURPLE, 0.8))

		# === 2. 电流特效背景 (可用时) ===
		if is_available and not is_cooling and mana_ok:
			_draw_current_effect(slot_rect, slot["icon_color"])

		# === 3. 图标色块 ===
		var icon_rect := Rect2(
			Vector2(slot_x + 8, slot_y + 8),
			Vector2(SLOT_SIZE - 16, SLOT_SIZE - 16)
		)
		var icon_color: Color = slot["icon_color"]
		if not mana_ok:
			# 法力不足：红色闪烁
			var red_flash := sin(_time * 6.0) * 0.3 + 0.5
			icon_color = Color(COLOR_ERROR_RED, red_flash)
		elif is_cooling:
			icon_color = Color(icon_color, 0.3)

		draw_rect(icon_rect, icon_color)

		# === 4. 冷却遮罩 ===
		if is_cooling:
			var cd_ratio := slot["cooldown_current"] / max(slot["cooldown_max"], 0.001)
			var mask_height := SLOT_SIZE * cd_ratio
			var mask_rect := Rect2(
				Vector2(slot_x, slot_y),
				Vector2(SLOT_SIZE, mask_height)
			)
			draw_rect(mask_rect, Color(COLOR_ABYSS_BLACK, 0.7))

			# 冷却时间文字
			var cd_text := "%.1f" % slot["cooldown_current"]
			draw_string(font,
				Vector2(slot_x + SLOT_SIZE / 2.0 - 10, slot_y + SLOT_SIZE / 2.0 + 5),
				cd_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, COLOR_CRYSTAL_WHITE)

		# === 5. 边框 ===
		var border_color := COLOR_ACCENT
		if not mana_ok:
			border_color = COLOR_ERROR_RED
		elif is_cooling:
			border_color = Color(COLOR_ACCENT, 0.3)

		# 冷却完成闪光
		if flash > 0:
			border_color = Color.WHITE
			var glow_alpha := flash / 0.3
			draw_rect(slot_rect, Color(COLOR_ACCENT, glow_alpha * 0.3))

		draw_rect(slot_rect, border_color, false, 2.0)

		# === 6. 辉光 (可用时) ===
		if is_available and not is_cooling and mana_ok:
			var glow_rect := Rect2(
				Vector2(slot_x - 2, slot_y - 2),
				Vector2(SLOT_SIZE + 4, SLOT_SIZE + 4)
			)
			var glow_alpha := 0.15 + sin(_time * 2.0) * 0.05
			draw_rect(glow_rect, Color(COLOR_ACCENT, glow_alpha))

		# === 7. 按键标签 ===
		draw_string(font,
			Vector2(slot_x + SLOT_SIZE / 2.0 - 4, slot_y + SLOT_SIZE + 12),
			KEY_LABELS[i], HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(COLOR_CRYSTAL_WHITE, 0.6))

## 绘制电流特效
func _draw_current_effect(rect: Rect2, base_color: Color) -> void:
	var segments := 6
	for j in range(segments):
		var t := float(j) / segments
		var y := rect.position.y + rect.size.y * t
		var x_offset := sin(_time * 3.0 + t * 10.0) * 3.0
		var line_alpha := 0.1 + sin(_time * 2.0 + t * 5.0) * 0.05
		draw_line(
			Vector2(rect.position.x + x_offset, y),
			Vector2(rect.position.x + rect.size.x + x_offset, y),
			Color(base_color, line_alpha), 1.0
		)

# ============================================================
# 信号回调
# ============================================================

func _on_beat_tick(_beat_index: int) -> void:
	_beat_intensity = 1.0

func _on_slot_updated(slot_index: int, data: Dictionary) -> void:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return
	_slots[slot_index].merge(data, true)

# ============================================================
# 公共接口
# ============================================================

## 设置槽位数据
func set_slot(index: int, spell_name: String, icon_color: Color, cooldown_max: float) -> void:
	if index < 0 or index >= SLOT_COUNT:
		return
	_slots[index]["spell_name"] = spell_name
	_slots[index]["icon_color"] = icon_color
	_slots[index]["cooldown_max"] = cooldown_max

## 触发冷却
func trigger_cooldown(index: int) -> void:
	if index < 0 or index >= SLOT_COUNT:
		return
	_slots[index]["cooldown_current"] = _slots[index]["cooldown_max"]

## 设置法力状态
func set_mana_sufficient(index: int, sufficient: bool) -> void:
	if index < 0 or index >= SLOT_COUNT:
		return
	_slots[index]["mana_sufficient"] = sufficient

## 设置可用状态
func set_available(index: int, available: bool) -> void:
	if index < 0 or index >= SLOT_COUNT:
		return
	_slots[index]["available"] = available
