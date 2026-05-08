# godot_project/scripts/systems/spell_visual_manager.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 2210 | 函数数: 72 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `_ready` | function | `_ready()` |  |
| `_process` | function | `_process(delta: float)` |  |
| `_on_spell_cast` | function | `_on_spell_cast(spell_data: Dictionary)` |  |
| `_on_chord_cast` | function | `_on_chord_cast(chord_data: Dictionary)` |  |
| `_on_progression_resolved` | function | `_on_progression_resolved(progression: Dictionary)` |  |
| `_on_modifier_applied` | function | `_on_modifier_applied(modifier: MusicData.ModifierEffect)` |  |
| `_on_timbre_changed` | function | `_on_timbre_changed(new_timbre: int)` |  |
| `_on_phase_switched` | function | `_on_phase_switched(phase_name: String)` |  |
| `_on_monotone_silence` | function | `_on_monotone_silence(note_data: Dictionary)` |  |
| `_on_noise_overload` | function | `_on_noise_overload(overload_data: Dictionary)` |  |
| `_on_dissonance_corrosion` | function | `_on_dissonance_corrosion(corrosion_data: Dictionary)` |  |
| `_connect_vfx_timing` | function | `_connect_vfx_timing()` |  |
| `_on_beat_signal` | function | `_on_beat_signal(beat_index: int, is_strong_beat: bool)` |  |
| `_on_tick_signal` | function | `_on_tick_signal(_tick_index: int)` |  |
| `_get_beat_duration` | function | `_get_beat_duration()` |  |
| `_beats_to_seconds` | function | `_beats_to_seconds(beats: float)` |  |
| `_get_fatigue_scale` | function | `_get_fatigue_scale()` |  |
| `_spawn_modifier_visual_enhanced` | function | `_spawn_modifier_visual_enhanced(pos: Vector2, aim_dir: Vector2, modifier: MusicData.ModifierEffect, _data: Dictionary)` |  |
| `_modifier_vfx_pierce` | function | `_modifier_vfx_pierce(pos: Vector2, aim_dir: Vector2, color: Color)` |  |
| `_modifier_vfx_homing` | function | `_modifier_vfx_homing(pos: Vector2, color: Color)` |  |
| `_modifier_vfx_split` | function | `_modifier_vfx_split(pos: Vector2, color: Color)` |  |
| `_modifier_vfx_echo` | function | `_modifier_vfx_echo(pos: Vector2, color: Color)` |  |
| `_modifier_vfx_scatter` | function | `_modifier_vfx_scatter(pos: Vector2, aim_dir: Vector2, color: Color)` |  |
| `_spawn_modifier_ready_indicator_enhanced` | function | `_spawn_modifier_ready_indicator_enhanced(pos: Vector2, modifier: MusicData.ModifierEffect)` |  |
| `_spawn_cast_aura_enhanced` | function | `_spawn_cast_aura_enhanced(pos: Vector2, spell_data: Dictionary)` |  |
| `_spawn_chord_cast_aura` | function | `_spawn_chord_cast_aura(pos: Vector2, chord_data: Dictionary)` |  |
| `_vfx_enhanced_projectile` | function | `_vfx_enhanced_projectile(pos: Vector2, _data: Dictionary)` |  |
| `_vfx_dot_projectile` | function | `_vfx_dot_projectile(pos: Vector2, _data: Dictionary)` |  |
| `_vfx_explosive` | function | `_vfx_explosive(pos: Vector2, _data: Dictionary)` |  |
| `_vfx_shockwave` | function | `_vfx_shockwave(pos: Vector2, _data: Dictionary)` |  |
| `_vfx_field` | function | `_vfx_field(pos: Vector2, _data: Dictionary)` |  |
| `_vfx_divine_strike` | function | `_vfx_divine_strike(pos: Vector2, _data: Dictionary)` |  |
| `_vfx_shield_heal` | function | `_vfx_shield_heal(pos: Vector2, _data: Dictionary)` |  |
| `_vfx_summon` | function | `_vfx_summon(pos: Vector2, _data: Dictionary)` |  |
| `_vfx_charged` | function | `_vfx_charged(pos: Vector2, _data: Dictionary)` |  |
| `_vfx_storm_field` | function | `_vfx_storm_field(pos: Vector2, _data: Dictionary)` |  |
| `_vfx_holy_domain` | function | `_vfx_holy_domain(pos: Vector2, _data: Dictionary)` |  |
| `_vfx_annihilation_ray` | function | `_vfx_annihilation_ray(pos: Vector2, _data: Dictionary)` |  |
| `_vfx_time_rift` | function | `_vfx_time_rift(pos: Vector2, _data: Dictionary)` |  |
| `_vfx_symphony_storm` | function | `_vfx_symphony_storm(pos: Vector2, _data: Dictionary)` |  |
| `_vfx_finale` | function | `_vfx_finale(pos: Vector2, _data: Dictionary)` |  |
| `_vfx_slow_field` | function | `_vfx_slow_field(pos: Vector2, _data: Dictionary)` |  |
| `_vfx_augmented_burst` | function | `_vfx_augmented_burst(pos: Vector2, _data: Dictionary)` |  |
| `_spawn_timbre_cast_feedback` | function | `_spawn_timbre_cast_feedback(pos: Vector2, timbre: MusicData.TimbreType)` |  |
| `_spawn_timbre_chord_interaction` | function | `_spawn_timbre_chord_interaction(pos: Vector2, timbre: MusicData.TimbreType, spell_form: int, _data: Dictionary)` |  |
| `_spawn_rhythm_cast_feedback` | function | `_spawn_rhythm_cast_feedback(pos: Vector2, aim_dir: Vector2, rhythm: int, _data: Dictionary)` |  |
| `_spawn_progression_resolve_vfx_enhanced` | function | `_spawn_progression_resolve_vfx_enhanced(pos: Vector2, progression: Dictionary)` |  |
| `_vfx_progression_d_to_t` | function | `_vfx_progression_d_to_t(pos: Vector2, color: Color)` |  |
| `_vfx_progression_t_to_d` | function | `_vfx_progression_t_to_d(pos: Vector2, color: Color)` |  |
| `_vfx_progression_pd_to_d` | function | `_vfx_progression_pd_to_d(pos: Vector2, color: Color)` |  |
| `_spawn_monotone_silence_vfx` | function | `_spawn_monotone_silence_vfx(pos: Vector2, note_data: Dictionary)` |  |
| `_spawn_noise_overload_vfx` | function | `_spawn_noise_overload_vfx(pos: Vector2, _data: Dictionary)` |  |
| `_spawn_dissonance_corrosion_vfx` | function | `_spawn_dissonance_corrosion_vfx(pos: Vector2, _data: Dictionary)` |  |
| `_spawn_phase_switch_vfx` | function | `_spawn_phase_switch_vfx(pos: Vector2, phase_name: String)` |  |
| `_vfx_switch_to_overtone` | function | `_vfx_switch_to_overtone(pos: Vector2)` |  |
| `_vfx_switch_to_sub_bass` | function | `_vfx_switch_to_sub_bass(pos: Vector2)` |  |
| `_vfx_switch_to_fundamental` | function | `_vfx_switch_to_fundamental(pos: Vector2)` |  |
| `_update_effects` | function | `_update_effects(delta: float)` |  |
| `_cleanup_expired` | function | `_cleanup_expired()` |  |
| `_create_ring` | function | `_create_ring(pos: Vector2, radius: float, color: Color, alpha: float = 0.5)` |  |
| `_create_polygon` | function | `_create_polygon(pos: Vector2, size: float, vertex_count: int, color: Color)` |  |
| `_spawn_radial_particles` | function | `_spawn_radial_particles(pos: Vector2, color: Color, count: int, distance: float, duration: float)` |  |
| `_spawn_floating_text` | function | `_spawn_floating_text(pos: Vector2, text: String, color: Color)` |  |
| `_get_spell_form_color` | function | `_get_spell_form_color(spell_form)` |  |
| `_get_player_position` | function | `_get_player_position()` |  |
| `_get_aim_direction` | function | `_get_aim_direction()` |  |
| `_find_nearest_enemy` | function | `_find_nearest_enemy(pos: Vector2)` |  |
| `_apply_timbre_shader_to_cast` | function | `_apply_timbre_shader_to_cast(pos: Vector2, timbre: int, spell_data: Dictionary)` |  |
| `_apply_modifier_shader` | function | `_apply_modifier_shader(node: Node2D, modifier: MusicData.ModifierEffect)` |  |
| `_apply_scanline_glow` | function | `_apply_scanline_glow(node: Node2D, color: Color)` |  |
| `clear_all` | function | `clear_all()` |  |
| `_spawn_crit_flash` | function | `_spawn_crit_flash(pos: Vector2)` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| `config_shader_state` | 视觉上限、颜色表、Shader 引用和运行时状态 | `grep -n '@section:config_shader_state' godot_project/scripts/systems/spell_visual_manager.gd` |
| `lifecycle` | 初始化、信号连接与逐帧清理入口 | `grep -n '@section:lifecycle' godot_project/scripts/systems/spell_visual_manager.gd` |
| `signal_handlers` | 法术、和弦、进程、音色与惩罚事件响应 | `grep -n '@section:signal_handlers' godot_project/scripts/systems/spell_visual_manager.gd` |
| `vfx_timing_bridge` | VFXTiming 节拍信号桥接与时间换算 | `grep -n '@section:vfx_timing_bridge' godot_project/scripts/systems/spell_visual_manager.gd` |
| `modifier_visuals` | 穿透、追踪、分裂、回声与散射修饰符特效 | `grep -n '@section:modifier_visuals' godot_project/scripts/systems/spell_visual_manager.gd` |
| `cast_aura_visuals` | 单音与和弦施法光环反馈 | `grep -n '@section:cast_aura_visuals' godot_project/scripts/systems/spell_visual_manager.gd` |
| `base_spellform_visuals` | 基础和弦/法术形态 VFX | `grep -n '@section:base_spellform_visuals' godot_project/scripts/systems/spell_visual_manager.gd` |
| `extended_spellform_visuals` | 高阶法术形态与终曲 VFX | `grep -n '@section:extended_spellform_visuals' godot_project/scripts/systems/spell_visual_manager.gd` |
| `timbre_feedback` | 音色施法反馈与和弦交互特效 | `grep -n '@section:timbre_feedback' godot_project/scripts/systems/spell_visual_manager.gd` |
| `rhythm_feedback` | 节奏型施法反馈特效 | `grep -n '@section:rhythm_feedback' godot_project/scripts/systems/spell_visual_manager.gd` |
| `progression_vfx` | 功能和声进行解决 VFX | `grep -n '@section:progression_vfx' godot_project/scripts/systems/spell_visual_manager.gd` |
| `punishment_vfx` | 单调、噪声过载与不协和腐蚀惩罚特效 | `grep -n '@section:punishment_vfx' godot_project/scripts/systems/spell_visual_manager.gd` |
| `phase_switch_vfx` | 音色阶段切换特效 | `grep -n '@section:phase_switch_vfx' godot_project/scripts/systems/spell_visual_manager.gd` |
| `effect_lifecycle` | 活跃特效生命周期、缩放、透明度与清理 | `grep -n '@section:effect_lifecycle' godot_project/scripts/systems/spell_visual_manager.gd` |
| `primitive_helpers` | 环形、多边形、粒子、浮字与目标查询工具 | `grep -n '@section:primitive_helpers' godot_project/scripts/systems/spell_visual_manager.gd` |
| `shader_integration` | 音色、修饰符和扫描线 Shader 激活 | `grep -n '@section:shader_integration' godot_project/scripts/systems/spell_visual_manager.gd` |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/systems/spell_visual_manager.gd
```
