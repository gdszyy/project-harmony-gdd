## vfx_combinator.gd
## 特效模块化组合引擎与优先级系统
##
## 职责：
## 1. 实现七层特效组合矩阵（层级0-7的叠加规则：附加/混合/替换/覆盖）
## 2. 实现 P0-P4 优先级排序系统，解决特效冲突
## 3. 提供 resolve_vfx_stack 方法，将多层特效解析为最终的渲染参数
## 4. 管理 LOD 视觉降级策略
extends Node

# ============================================================
# 枚举与常量
# ============================================================

## 特效层级定义 (0-7)
enum VfxLayer {
	ENVIRONMENT = 0,    ## 层级0：全局环境 (章节主题、地面Shader)
	MODIFIER = 1,       ## 层级1：修饰符 (黑键，一次性附加效果)
	BASE_PROJECTILE = 2,## 层级1.5：基础弹体 (音符，决定物理属性和基础形态)
	CHORD_SPELL = 3,    ## 层级2：和弦法术 (形态质变，引入新视觉语言)
	TIMBRE = 4,         ## 层级3：音色 (攻击质感，材质滤镜)
	RHYTHM = 5,         ## 层级4：节奏型 (行为模式，发射轨迹和频率)
	PROGRESSION = 6,    ## 层级5：和弦进行 (组合效果，全屏反馈)
	PENALTY = 7,        ## 层级6：环境与惩罚 (疲劳、单音寂静)
	SPECTRAL_PHASE = 8  ## 层级7：频谱相位 (共鸣切割，全局重塑)
}

## 优先级定义 (P0-P4，数值越小优先级越高)
enum Priority {
	P0_BLOCKING = 0,    ## P0=机制阻断层（惩罚）
	P1_GLOBAL = 1,      ## P1=全局重塑层（相位/进行）
	P2_MORPH = 2,       ## P2=形态质变层（和弦）
	P3_BEHAVIOR = 3,    ## P3=行为修饰层（节奏/修饰符）
	P4_BASE = 4         ## P4=质感基础层（音色/弹体）
}

## 叠加方式
enum BlendMode {
	ADDITIVE,           ## 附加 (作为子节点或额外Shader Pass)
	BLEND,              ## 混合 (修改Shader参数)
	REPLACE,            ## 替换 (完全替换基础形态)
	OVERRIDE            ## 覆盖 (强制覆盖底层颜色和材质)
}

## LOD 级别
enum LodLevel {
	LOD0_FULL = 0,      ## 完整：所有粒子+长拖尾+高质量Glow
	LOD1_SIMPLE = 1,    ## 简化：粒子减半+拖尾缩短30%+关闭次要环境特效
	LOD2_CORE = 2       ## 核心：仅保留命中/爆炸粒子+线条Shader拖尾
}

# ============================================================
# 状态
# ============================================================
var current_lod: int = LodLevel.LOD0_FULL

# ============================================================
# 核心接口
# ============================================================

## 解析特效栈，返回最终的渲染参数和行为指令
## layers: Dictionary，键为 VfxLayer 枚举，值为具体的特效配置字典
## 返回值: Dictionary，包含最终的 shader_params, particles, behaviors 等
func resolve_vfx_stack(layers: Dictionary) -> Dictionary:
	var result := {
		"shader_params": {
			"base_color_index": 0.0,
			"emission_multiplier": 1.0,
			"timbre_texture_mask": 0.0,
			"distortion_glitch": 0.0
		},
		"color": Color.WHITE,
		"scale": Vector3.ONE,
		"particles": [],
		"attachments": [],
		"is_blocked": false,
		"morph_type": ""
	}
	
	# 1. 检查 P0 机制阻断层 (惩罚)
	if layers.has(VfxLayer.PENALTY):
		var penalty = layers[VfxLayer.PENALTY]
		if penalty.get("type") == "silence":
			# 单音寂静：强制覆盖为灰色，失去发光，增加故障
			result["color"] = Color(0.3, 0.3, 0.3, 1.0)
			result["shader_params"]["emission_multiplier"] = 0.0
			result["shader_params"]["distortion_glitch"] = 1.0
			result["is_blocked"] = true
			return result # 阻断后续所有层级
			
	# 2. 检查 P2 形态质变层 (和弦法术)
	var has_morph = false
	if layers.has(VfxLayer.CHORD_SPELL):
		var chord = layers[VfxLayer.CHORD_SPELL]
		if chord.get("morph_base", false):
			has_morph = true
			result["morph_type"] = chord.get("type", "default_chord")
			# 和弦法术可能自带基础颜色
			if chord.has("color"):
				result["color"] = chord["color"]
	
	# 3. 处理 P4 质感基础层 (基础弹体 + 音色)
	if not has_morph and layers.has(VfxLayer.BASE_PROJECTILE):
		var base = layers[VfxLayer.BASE_PROJECTILE]
		result["color"] = base.get("color", Color.WHITE)
		result["shader_params"]["base_color_index"] = base.get("note_index", 0.0)
		result["shader_params"]["emission_multiplier"] = base.get("damage_ratio", 1.0)
		result["scale"] = Vector3.ONE * base.get("size_ratio", 1.0)
		
	if layers.has(VfxLayer.TIMBRE):
		var timbre = layers[VfxLayer.TIMBRE]
		# 音色作为材质滤镜
		result["shader_params"]["timbre_texture_mask"] = timbre.get("type_index", 0.0)
		# 附加音色专属粒子
		if timbre.has("particle_type"):
			result["particles"].append(timbre["particle_type"])
			
	# 4. 处理 P3 行为修饰层 (节奏型 + 修饰符)
	if layers.has(VfxLayer.RHYTHM):
		var rhythm = layers[VfxLayer.RHYTHM]
		# 节奏型可能放大发光强度（如精准蓄力）
		if rhythm.get("is_strong_beat", false):
			result["shader_params"]["emission_multiplier"] *= 1.5
			result["scale"] *= 1.2
			
	if layers.has(VfxLayer.MODIFIER):
		var modifier = layers[VfxLayer.MODIFIER]
		# 修饰符作为附加效果
		if modifier.has("attachment_vfx"):
			result["attachments"].append(modifier["attachment_vfx"])
			
	# 5. 处理 P1 全局重塑层 (在全局管理器中处理，这里仅做标记或微调)
	if layers.has(VfxLayer.SPECTRAL_PHASE):
		var phase = layers[VfxLayer.SPECTRAL_PHASE]
		if phase.get("type") == "high_pass":
			# 高通：线框化，变亮变细
			result["shader_params"]["emission_multiplier"] *= 1.2
			result["scale"] *= 0.8
			
	# 6. 应用 LOD 降级
	_apply_lod_degradation(result)
	
	return result

# ============================================================
# LOD 管理
# ============================================================

## 更新当前 LOD 级别
func update_lod(fps: float, fatigue: float) -> void:
	if fps < 30.0 or fatigue > 0.8:
		current_lod = LodLevel.LOD2_CORE
	elif fps < 50.0 or fatigue > 0.5:
		current_lod = LodLevel.LOD1_SIMPLE
	else:
		current_lod = LodLevel.LOD0_FULL

## 应用 LOD 降级到渲染参数
func _apply_lod_degradation(result: Dictionary) -> void:
	match current_lod:
		LodLevel.LOD0_FULL:
			pass # 保持完整
		LodLevel.LOD1_SIMPLE:
			# 简化：减少次要粒子
			if result["particles"].size() > 1:
				result["particles"].resize(1) # 仅保留主要粒子
		LodLevel.LOD2_CORE:
			# 核心：移除所有非关键粒子和附加物
			result["particles"].clear()
			result["attachments"].clear()
			# 降低发光强度以节省性能
			result["shader_params"]["emission_multiplier"] = min(result["shader_params"]["emission_multiplier"], 1.0)
