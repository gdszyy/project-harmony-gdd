## adsr_envelope.gd
## ADSR 包络生成器 (Attack / Decay / Sustain / Release)
##
## OPT08 — 程序化音色合成核心组件
## 用于同时驱动弹体行为和音效合成的统一包络曲线。
##
## 设计要点：
##   - 同一套 ADSR 参数同时控制弹体视觉/伤害效能和音效振幅/滤波器
##   - 支持线性和指数两种包络曲线模式
##   - 轻量级实现，适合每帧调用
##
## 用法示例：
##   var env = ADSREnvelope.new()
##   env.attack_time = 0.08
##   env.decay_time = 0.20
##   env.sustain_level = 0.60
##   env.release_time = 0.15
##   env.trigger()
##   # 在 _process 中：
##   var value = env.process(delta)
##
class_name ADSREnvelope
extends RefCounted

# ============================================================
# 包络参数
# ============================================================

## 起音时间（秒）— 从 0 上升到峰值 1.0 的时间
var attack_time: float = 0.01

## 衰减时间（秒）— 从峰值 1.0 衰减到 sustain_level 的时间
var decay_time: float = 0.1

## 持续电平（0.0 ~ 1.0）— Sustain 阶段的稳定电平
var sustain_level: float = 0.7

## 释放时间（秒）— 从 sustain_level 衰减到 0 的时间
var release_time: float = 0.3

## 包络曲线类型：true = 指数曲线（更自然），false = 线性
var use_exponential: bool = true

# ============================================================
# 包络状态
# ============================================================

## 包络阶段枚举
enum Stage {
	IDLE,       ## 空闲 — 包络未激活
	ATTACK,     ## 起音 — 从 0 上升到 1.0
	DECAY,      ## 衰减 — 从 1.0 下降到 sustain_level
	SUSTAIN,    ## 持续 — 保持在 sustain_level
	RELEASE,    ## 释放 — 从当前值下降到 0
}

## 当前包络阶段
var _stage: Stage = Stage.IDLE

## 当前包络输出值 (0.0 ~ 1.0)
var _current_value: float = 0.0

## 当前阶段已经过的时间（秒）
var _elapsed: float = 0.0

## Release 阶段开始时的值（用于从任意值开始释放）
var _release_start_value: float = 0.0

# ============================================================
# 公共接口
# ============================================================

## 触发包络（Note On）— 开始 Attack 阶段
func trigger() -> void:
	_stage = Stage.ATTACK
	_elapsed = 0.0
	# 如果从非零值重新触发（retrigger），保留当前值实现平滑过渡
	# 但仍从 Attack 阶段开始

## 释放包络（Note Off）— 进入 Release 阶段
func release() -> void:
	if _stage == Stage.IDLE:
		return
	_release_start_value = _current_value
	_stage = Stage.RELEASE
	_elapsed = 0.0

## 强制停止包络，立即归零
func force_stop() -> void:
	_stage = Stage.IDLE
	_current_value = 0.0
	_elapsed = 0.0

## 每帧更新，返回当前包络值 (0.0 ~ 1.0)
func process(delta: float) -> float:
	_elapsed += delta

	match _stage:
		Stage.IDLE:
			_current_value = 0.0

		Stage.ATTACK:
			if attack_time > 0.0:
				var t := minf(_elapsed / attack_time, 1.0)
				if use_exponential:
					# 指数起音：快速上升后趋缓
					_current_value = 1.0 - exp(-3.0 * t)
					_current_value = minf(_current_value / (1.0 - exp(-3.0)), 1.0)
				else:
					_current_value = t
			else:
				_current_value = 1.0

			if _elapsed >= attack_time:
				_current_value = 1.0
				_stage = Stage.DECAY
				_elapsed = 0.0

		Stage.DECAY:
			if decay_time > 0.0:
				var t := minf(_elapsed / decay_time, 1.0)
				if use_exponential:
					# 指数衰减：快速下降后趋缓
					_current_value = lerpf(1.0, sustain_level, 1.0 - exp(-3.0 * t))
				else:
					_current_value = lerpf(1.0, sustain_level, t)
			else:
				_current_value = sustain_level

			if _elapsed >= decay_time:
				_current_value = sustain_level
				_stage = Stage.SUSTAIN
				_elapsed = 0.0

		Stage.SUSTAIN:
			_current_value = sustain_level

		Stage.RELEASE:
			if release_time > 0.0:
				var t := minf(_elapsed / release_time, 1.0)
				if use_exponential:
					_current_value = _release_start_value * exp(-5.0 * t)
				else:
					_current_value = lerpf(_release_start_value, 0.0, t)
			else:
				_current_value = 0.0

			if _current_value <= 0.001 or _elapsed >= release_time:
				_stage = Stage.IDLE
				_current_value = 0.0

	return _current_value

## 包络是否处于活跃状态（非 IDLE）
func is_active() -> bool:
	return _stage != Stage.IDLE

## 获取当前阶段
func get_stage() -> Stage:
	return _stage

## 获取当前包络值（不更新状态）
func get_value() -> float:
	return _current_value

# ============================================================
# 工厂方法 — 从音色武器参数创建包络
# ============================================================

## 从 Dictionary 参数创建 ADSR 包络
## params 格式: { "attack": float, "decay": float, "sustain": float, "release": float }
static func from_params(params: Dictionary) -> ADSREnvelope:
	var env := ADSREnvelope.new()
	env.attack_time = params.get("attack", 0.01)
	env.decay_time = params.get("decay", 0.1)
	env.sustain_level = params.get("sustain", 0.7)
	env.release_time = params.get("release", 0.3)
	return env

## 创建滤波器包络（基于音色武器参数，但起音更快、衰减更慢）
## 用于控制滤波器截止频率的时间变化
static func create_filter_envelope(params: Dictionary) -> ADSREnvelope:
	var env := ADSREnvelope.new()
	env.attack_time = params.get("attack", 0.01) * 0.5   # 滤波器起音更快
	env.decay_time = params.get("decay", 0.1) * 1.5      # 滤波器衰减更慢
	env.sustain_level = params.get("brightness", 0.5)     # 明亮度决定持续截止频率
	env.release_time = params.get("release", 0.3)
	return env
