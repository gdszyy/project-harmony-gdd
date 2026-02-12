## resonance_slicing_manager.gd
## 频谱相位系统管理器 (Autoload 单例)
## 职责：管理三相位切换、相位能量、频谱偏移疲劳、音色增益计算
## 关联文档：Docs/ResonanceSlicing_System_Design.md
## 关联 UI：Docs/UI_Design_Module6_ResonanceSlicing.md
extends Node

# ============================================================
# 枚举
# ============================================================

enum Phase {
	FUNDAMENTAL = 0,  ## 全频相位（默认）
	OVERTONE = 1,     ## 高通相位
	SUB_BASS = 2,     ## 低通相位
}

# ============================================================
# 信号
# ============================================================

## 相位切换完成
signal phase_changed(new_phase: Phase)
## 相位能量变化
signal phase_energy_changed(current: float, maximum: float)
## 频谱偏移疲劳变化
signal spectrum_offset_fatigue_changed(value: float)
## 频谱失调触发（SOF >= 100%）
signal spectrum_corruption_triggered()
## 频谱失调解除
signal spectrum_corruption_cleared()
## 相位切换请求（UI 可监听此信号播放预备动画）
signal phase_switch_requested(from_phase: Phase, to_phase: Phase)

# ============================================================
# 常量
# ============================================================

## 相位能量上限
const MAX_PHASE_ENERGY: float = 100.0
## 切换消耗
const SWITCH_ENERGY_COST: float = 10.0
## 极端相位每秒持续消耗
const EXTREME_PHASE_DRAIN_PER_SEC: float = 5.0
## 全频相位能量恢复速率（基于 AFI 等级）
const RECOVERY_RATES: Dictionary = {
	"none": 20.0,       # AFI < 0.3
	"mild": 15.0,       # 0.3 <= AFI < 0.5
	"moderate": 10.0,   # 0.5 <= AFI < 0.8
	"severe": 5.0,      # 0.8 <= AFI < 1.0
	"critical": 0.0,    # AFI = 1.0
}
## 频谱偏移疲劳增长速率（每秒）
const SOF_GROWTH_RATE: float = 0.08
## 频谱偏移疲劳衰减速率（全频相位下每秒）
const SOF_DECAY_RATE: float = 0.04
## 频谱失调触发阈值
const SOF_CORRUPTION_THRESHOLD: float = 1.0
## 频谱失调解除阈值（SOF 降至此值以下解除）
const SOF_CLEAR_THRESHOLD: float = 0.6
## 切换冷却时间（秒）
const SWITCH_COOLDOWN: float = 0.3

## 相位名称
const PHASE_NAMES: Dictionary = {
	Phase.FUNDAMENTAL: "FUNDAMENTAL",
	Phase.OVERTONE: "OVERTONE",
	Phase.SUB_BASS: "SUB-BASS",
}

## 相位主色调
const PHASE_COLORS: Dictionary = {
	Phase.FUNDAMENTAL: Color("#9D6FFF"),
	Phase.OVERTONE: Color("#4DFFF3"),
	Phase.SUB_BASS: Color("#FF8C42"),
}

## 相位暗色
const PHASE_COLORS_DIM: Dictionary = {
	Phase.FUNDAMENTAL: Color("#3E2C66"),
	Phase.OVERTONE: Color("#1A665F"),
	Phase.SUB_BASS: Color("#664019"),
}

## 相位属性修正
const PHASE_MODIFIERS: Dictionary = {
	Phase.FUNDAMENTAL: {
		"move_speed_mult": 1.0,
		"damage_taken_mult": 1.0,
		"dash_cooldown_mult": 1.0,
		"can_dash": true,
		"has_hyper_armor": false,
	},
	Phase.OVERTONE: {
		"move_speed_mult": 1.3,
		"damage_taken_mult": 1.2,
		"dash_cooldown_mult": 0.5,
		"can_dash": true,
		"has_hyper_armor": false,
	},
	Phase.SUB_BASS: {
		"move_speed_mult": 0.8,
		"damage_taken_mult": 0.5,
		"dash_cooldown_mult": 1.0,
		"can_dash": false,
		"has_hyper_armor": true,
	},
}

## 相位-音色系别增益映射
const PHASE_TIMBRE_GAINS: Dictionary = {
	Phase.OVERTONE: {
		"family": "plucked",
		"bonus_text": "+50% 瞬态伤害",
		"damage_mult": 1.5,
	},
	Phase.SUB_BASS: {
		"family": "percussion",
		"bonus_text": "x2 击退/眩晕",
		"effect_mult": 2.0,
	},
	Phase.FUNDAMENTAL: {
		"family": "bowed",
		"bonus_text": "+50% 持续时间",
		"duration_mult": 1.5,
	},
}

# ============================================================
# 状态
# ============================================================

## 当前相位
var current_phase: Phase = Phase.FUNDAMENTAL
## 相位能量
var phase_energy: float = MAX_PHASE_ENERGY
## 频谱偏移疲劳（0.0 ~ 1.0）
var spectrum_offset_fatigue: float = 0.0
## 是否处于频谱失调状态
var is_corrupted: bool = false
## 切换冷却计时器
var _switch_cooldown_timer: float = 0.0
## 上一次相位（用于过渡动画）
var previous_phase: Phase = Phase.FUNDAMENTAL

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	# 冷却计时
	if _switch_cooldown_timer > 0.0:
		_switch_cooldown_timer -= delta

	# 能量消耗/恢复
	_update_energy(delta)

	# 频谱偏移疲劳
	_update_sof(delta)

# ============================================================
# 公共接口
# ============================================================

## 请求切换到指定相位
func switch_phase(target: Phase) -> bool:
	if target == current_phase:
		return false
	if _switch_cooldown_timer > 0.0:
		return false
	if phase_energy < SWITCH_ENERGY_COST and target != Phase.FUNDAMENTAL:
		return false

	# 消耗能量（切换回全频不消耗）
	if target != Phase.FUNDAMENTAL:
		phase_energy -= SWITCH_ENERGY_COST
		phase_energy_changed.emit(phase_energy, MAX_PHASE_ENERGY)

	previous_phase = current_phase
	phase_switch_requested.emit(current_phase, target)

	current_phase = target
	_switch_cooldown_timer = SWITCH_COOLDOWN

	phase_changed.emit(current_phase)
	return true

## 获取当前相位
func get_current_phase() -> Phase:
	return current_phase

## 获取相位名称
func get_phase_name(phase: Phase) -> String:
	return PHASE_NAMES.get(phase, "UNKNOWN")

## 获取相位颜色
func get_phase_color(phase: Phase) -> Color:
	return PHASE_COLORS.get(phase, Color.WHITE)

## 获取当前相位的属性修正
func get_current_modifiers() -> Dictionary:
	return PHASE_MODIFIERS.get(current_phase, PHASE_MODIFIERS[Phase.FUNDAMENTAL])

## 获取能量比例
func get_energy_ratio() -> float:
	return phase_energy / MAX_PHASE_ENERGY

## 检查是否可以切换
func can_switch_to(target: Phase) -> bool:
	if target == current_phase:
		return false
	if _switch_cooldown_timer > 0.0:
		return false
	if phase_energy < SWITCH_ENERGY_COST and target != Phase.FUNDAMENTAL:
		return false
	return true

## 获取指定相位的增益提示数据
func get_phase_gain_data(phase: Phase) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var mods: Dictionary = PHASE_MODIFIERS.get(phase, {})

	match phase:
		Phase.OVERTONE:
			result.append({"text": "▲ 移速 +30%", "color": PHASE_COLORS[Phase.OVERTONE], "is_buff": true})
			result.append({"text": "▲ 冲刺冷却 -50%", "color": PHASE_COLORS[Phase.OVERTONE], "is_buff": true})
			result.append({"text": "▼ 受伤 +20%", "color": Color("#FF4D4D"), "is_buff": false})
		Phase.SUB_BASS:
			result.append({"text": "▲ 获得霸体", "color": PHASE_COLORS[Phase.SUB_BASS], "is_buff": true})
			result.append({"text": "▲ 受伤 -50%", "color": PHASE_COLORS[Phase.SUB_BASS], "is_buff": true})
			result.append({"text": "▼ 移速 -20%", "color": Color("#FF4D4D"), "is_buff": false})
			result.append({"text": "▼ 无法冲刺", "color": Color("#FF4D4D"), "is_buff": false})
		Phase.FUNDAMENTAL:
			result.append({"text": "◆ 无属性修正", "color": Color("#A098C8"), "is_buff": true})
			result.append({"text": "▲ 能量恢复最快", "color": Color("#4DFF80"), "is_buff": true})

	return result

## 强制回到全频相位（能量耗尽时调用）
func force_fundamental() -> void:
	if current_phase != Phase.FUNDAMENTAL:
		previous_phase = current_phase
		current_phase = Phase.FUNDAMENTAL
		phase_changed.emit(current_phase)

# ============================================================
# 内部逻辑
# ============================================================

func _update_energy(delta: float) -> void:
	var old_energy := phase_energy

	if current_phase == Phase.FUNDAMENTAL:
		# 全频相位下恢复能量
		var recovery_rate := _get_recovery_rate()
		phase_energy = min(MAX_PHASE_ENERGY, phase_energy + recovery_rate * delta)
	else:
		# 极端相位下持续消耗
		phase_energy -= EXTREME_PHASE_DRAIN_PER_SEC * delta
		if phase_energy <= 0.0:
			phase_energy = 0.0
			force_fundamental()

	if abs(old_energy - phase_energy) > 0.01:
		phase_energy_changed.emit(phase_energy, MAX_PHASE_ENERGY)

func _update_sof(delta: float) -> void:
	var old_sof := spectrum_offset_fatigue

	if current_phase != Phase.FUNDAMENTAL:
		# 极端相位下 SOF 增长
		spectrum_offset_fatigue = min(1.0, spectrum_offset_fatigue + SOF_GROWTH_RATE * delta)
	else:
		# 全频相位下 SOF 衰减
		spectrum_offset_fatigue = max(0.0, spectrum_offset_fatigue - SOF_DECAY_RATE * delta)

	if abs(old_sof - spectrum_offset_fatigue) > 0.001:
		spectrum_offset_fatigue_changed.emit(spectrum_offset_fatigue)

	# 频谱失调检测
	if not is_corrupted and spectrum_offset_fatigue >= SOF_CORRUPTION_THRESHOLD:
		is_corrupted = true
		spectrum_corruption_triggered.emit()
		force_fundamental()
	elif is_corrupted and spectrum_offset_fatigue < SOF_CLEAR_THRESHOLD:
		is_corrupted = false
		spectrum_corruption_cleared.emit()

func _get_recovery_rate() -> float:
	# 根据 AFI 等级决定恢复速率
	var afi: float = 0.0
	if Engine.has_singleton("FatigueManager") or has_node("/root/FatigueManager"):
		var fm = get_node_or_null("/root/FatigueManager")
		if fm and "current_afi" in fm:
			afi = fm.current_afi

	if afi >= 1.0:
		return RECOVERY_RATES["critical"]
	elif afi >= 0.8:
		return RECOVERY_RATES["severe"]
	elif afi >= 0.5:
		return RECOVERY_RATES["moderate"]
	elif afi >= 0.3:
		return RECOVERY_RATES["mild"]
	else:
		return RECOVERY_RATES["none"]
