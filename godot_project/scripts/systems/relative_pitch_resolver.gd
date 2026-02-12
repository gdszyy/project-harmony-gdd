## 相对音高解析器 (OPT02: Relative Pitch System)
##
## 将法术的音高定义从"播放绝对音符"变为"播放当前和弦的某个功能音"。
## 确保无论背景和声如何变化，玩家的每一次施法在听觉上都是和谐的。
##
## 核心职责：
##   1. 将法术的 pitch_degree (1-7) 解析为当前音阶中的绝对 MIDI 音高
##   2. 提供和弦音吸附算法，将非和弦音量化到最近的和弦音
##   3. 提供 MIDI ↔ 频率转换工具
##   4. 提供 Pitch Shifting 比率计算
##   5. 提供音乐功能角色查询（紧张度、稳定性等）
##
## 设计原则：
##   - 和谐优先：所有法术音效必须与当前全局和弦保持和谐
##   - 功能化音高：法术的音高是相对于当前和弦的功能性角色
##   - 向下兼容：和声指挥官未激活时，回退到绝对音高模式
##
## 依赖：BgmManager (OPT01 和声指挥官) 提供和声上下文
class_name RelativePitchResolver

# ============================================================
# 常量
# ============================================================

## A4 标准频率 (Hz)
const A4_FREQUENCY: float = 440.0
## A4 的 MIDI 编号
const A4_MIDI: int = 69

## 白键到默认音程度数的映射
## 度数表示音符在当前音阶中的功能角色 (1=根音, ..., 7=导音)
const WHITE_KEY_DEGREE: Dictionary = {
	0: 1,  ## WhiteKey.C → 根音 (Tonic)
	1: 2,  ## WhiteKey.D → 上主音 (Supertonic)
	2: 3,  ## WhiteKey.E → 中音 (Mediant)
	3: 4,  ## WhiteKey.F → 下属音 (Subdominant)
	4: 5,  ## WhiteKey.G → 属音 (Dominant)
	5: 6,  ## WhiteKey.A → 下中音 (Submediant)
	6: 7,  ## WhiteKey.B → 导音 (Leading Tone)
}

## 音程度数的功能角色信息
## tension: 紧张度 (0.0=完全和谐, 1.0=极度紧张)
## stability: 稳定性 (0.0=不稳定, 1.0=完全稳定)
## is_chord_priority: 是否优先吸附到和弦音
const DEGREE_ROLES: Dictionary = {
	1: {"name": "根音", "en": "Tonic", "tension": 0.0, "stability": 1.0, "is_chord_priority": true},
	2: {"name": "上主音", "en": "Supertonic", "tension": 0.3, "stability": 0.5, "is_chord_priority": false},
	3: {"name": "中音", "en": "Mediant", "tension": 0.2, "stability": 0.7, "is_chord_priority": true},
	4: {"name": "下属音", "en": "Subdominant", "tension": 0.5, "stability": 0.4, "is_chord_priority": false},
	5: {"name": "属音", "en": "Dominant", "tension": 0.7, "stability": 0.6, "is_chord_priority": true},
	6: {"name": "下中音", "en": "Submediant", "tension": 0.4, "stability": 0.5, "is_chord_priority": false},
	7: {"name": "导音", "en": "Leading Tone", "tension": 0.9, "stability": 0.2, "is_chord_priority": false},
}

## 常用音阶定义 (半音间隔数组)
const SCALE_INTERVALS: Dictionary = {
	"natural_minor":    [0, 2, 3, 5, 7, 8, 10],
	"harmonic_minor":   [0, 2, 3, 5, 7, 8, 11],
	"melodic_minor":    [0, 2, 3, 5, 7, 9, 11],
	"major":            [0, 2, 4, 5, 7, 9, 11],
	"dorian":           [0, 2, 3, 5, 7, 9, 10],
	"phrygian":         [0, 1, 3, 5, 7, 8, 10],
	"lydian":           [0, 2, 4, 6, 7, 9, 11],
	"mixolydian":       [0, 2, 4, 5, 7, 9, 10],
	"locrian":          [0, 1, 3, 5, 6, 8, 10],
	"pentatonic_minor": [0, 3, 5, 7, 10],
	"blues":            [0, 3, 5, 6, 7, 10],
}

# ============================================================
# 核心解析方法
# ============================================================

## 根据法术度数和当前和声上下文，计算绝对 MIDI 音高
## degree: 音程度数 (1-7)
## base_octave: 基础八度 (默认 4, 即 C4 = MIDI 60 附近)
## 返回: MIDI 音高编号
static func resolve_pitch(degree: int, base_octave: int = 4) -> int:
	var scale: Array[int] = _get_current_scale()

	# 确保度数在有效范围内
	var index: int = clampi(degree - 1, 0, scale.size() - 1)
	var pitch_class: int = scale[index]

	# 计算 MIDI 音高: pitch_class + (octave + 1) * 12
	var midi_note: int = pitch_class + (base_octave + 1) * 12
	return midi_note

## 根据法术度数获取对应的和弦功能音
## 优先返回和弦内音；若度数对应的音不在和弦内，吸附到最近的和弦音
## degree: 音程度数 (1-7)
## base_octave: 基础八度 (默认 4)
## 返回: MIDI 音高编号
static func resolve_chord_tone(degree: int, base_octave: int = 4) -> int:
	var chord: Dictionary = _get_current_chord()
	var chord_notes: Array = chord.get("notes", [])
	var scale: Array[int] = _get_current_scale()

	var index: int = clampi(degree - 1, 0, scale.size() - 1)
	var target_pc: int = scale[index]

	# 检查是否为和弦内音
	if target_pc in chord_notes:
		return target_pc + (base_octave + 1) * 12

	# 不在和弦内，吸附到最近的和弦音
	var quantized: int = _quantize_to_chord(target_pc, chord_notes)
	return quantized + (base_octave + 1) * 12

## 从白键枚举直接解析相对音高
## white_key: MusicData.WhiteKey 枚举值
## base_octave: 基础八度
## use_chord_tone: 是否优先吸附到和弦音
## 返回: MIDI 音高编号
static func resolve_from_white_key(white_key: int, base_octave: int = 4, use_chord_tone: bool = true) -> int:
	var degree: int = WHITE_KEY_DEGREE.get(white_key, 1)
	if use_chord_tone:
		return resolve_chord_tone(degree, base_octave)
	else:
		return resolve_pitch(degree, base_octave)

# ============================================================
# 频率与 MIDI 转换工具
# ============================================================

## 将 MIDI 音高转换为频率 (Hz)
## midi_note: MIDI 音高编号 (0-127)
## 返回: 频率 (Hz)
static func midi_to_frequency(midi_note: int) -> float:
	return A4_FREQUENCY * pow(2.0, (midi_note - A4_MIDI) / 12.0)

## 将频率转换为最近的 MIDI 音高
## frequency: 频率 (Hz)
## 返回: MIDI 音高编号
static func frequency_to_midi(frequency: float) -> int:
	if frequency <= 0.0:
		return 0
	return roundi(A4_MIDI + 12.0 * log(frequency / A4_FREQUENCY) / log(2.0))

## 计算 Pitch Shifting 比率
## 将基础音高 (base_midi) 变调到目标音高 (target_midi) 所需的 pitch_scale
## base_midi: 基础 MIDI 音高
## target_midi: 目标 MIDI 音高
## 返回: pitch_scale 比率 (1.0 = 不变调)
static func calculate_pitch_ratio(base_midi: int, target_midi: int) -> float:
	var semitone_diff: float = float(target_midi - base_midi)
	return pow(2.0, semitone_diff / 12.0)

## 从半音差计算 pitch_scale
## semitones: 半音差 (正=升高, 负=降低)
## 返回: pitch_scale 比率
static func semitones_to_pitch_scale(semitones: float) -> float:
	return pow(2.0, semitones / 12.0)

# ============================================================
# 音乐功能查询
# ============================================================

## 获取指定度数的功能角色信息
## degree: 音程度数 (1-7)
## 返回: 角色信息字典 {name, en, tension, stability, is_chord_priority}
static func get_degree_role(degree: int) -> Dictionary:
	return DEGREE_ROLES.get(degree, DEGREE_ROLES[1])

## 检查指定度数是否为和弦优先音（根音、中音、属音）
## degree: 音程度数 (1-7)
## 返回: 是否为和弦优先音
static func is_chord_tone(degree: int) -> bool:
	var role: Dictionary = get_degree_role(degree)
	return role.get("is_chord_priority", false)

## 获取指定度数的紧张度
## degree: 音程度数 (1-7)
## 返回: 紧张度 (0.0 ~ 1.0)
static func get_tension_for_degree(degree: int) -> float:
	var role: Dictionary = get_degree_role(degree)
	return role.get("tension", 0.0)

## 获取指定度数的稳定性
## degree: 音程度数 (1-7)
## 返回: 稳定性 (0.0 ~ 1.0)
static func get_stability_for_degree(degree: int) -> float:
	var role: Dictionary = get_degree_role(degree)
	return role.get("stability", 0.5)

## 根据根音和音阶名称构建完整音阶
## root: 根音音高类 (0-11)
## scale_name: 音阶名称 (如 "natural_minor", "major")
## 返回: 音高类数组
static func build_scale(root: int, scale_name: String) -> Array[int]:
	var intervals: Array = SCALE_INTERVALS.get(scale_name, SCALE_INTERVALS["natural_minor"])
	var scale: Array[int] = []
	for interval in intervals:
		scale.append((root + interval) % 12)
	return scale

# ============================================================
# 内部辅助方法
# ============================================================

## 获取当前全局音阶 (从 BgmManager 查询)
static func _get_current_scale() -> Array[int]:
	# 尝试通过 Engine 获取 BgmManager autoload
	var bgm = Engine.get_singleton("BGMManager") if Engine.has_singleton("BGMManager") else null
	if bgm and bgm.has_method("get_current_scale"):
		return bgm.get_current_scale()

	# 回退方案：尝试通过 SceneTree 查找
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var bgm_node := tree.root.get_node_or_null("BGMManager")
		if bgm_node and bgm_node.has_method("get_current_scale"):
			return bgm_node.get_current_scale()

	# 最终回退：返回 A 自然小调默认音阶
	return [9, 11, 0, 2, 4, 5, 7]

## 获取当前和弦信息 (从 BgmManager 查询)
static func _get_current_chord() -> Dictionary:
	var bgm = Engine.get_singleton("BGMManager") if Engine.has_singleton("BGMManager") else null
	if bgm and bgm.has_method("get_current_chord"):
		return bgm.get_current_chord()

	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var bgm_node := tree.root.get_node_or_null("BGMManager")
		if bgm_node and bgm_node.has_method("get_current_chord"):
			return bgm_node.get_current_chord()

	# 最终回退：返回 Am 默认和弦
	return {"root": 9, "type": 1, "notes": [9, 0, 4]}

## 将音高类吸附到最近的和弦音
## pitch_class: 待吸附的音高类 (0-11)
## chord_notes: 和弦包含的音高类数组
## 返回: 最近的和弦音音高类
static func _quantize_to_chord(pitch_class: int, chord_notes: Array) -> int:
	if chord_notes.is_empty():
		return pitch_class

	var min_dist: int = 12
	var closest: int = pitch_class

	for cn in chord_notes:
		var dist: int = absi((pitch_class - cn + 12) % 12)
		if dist > 6:
			dist = 12 - dist
		if dist < min_dist:
			min_dist = dist
			closest = cn

	return closest
