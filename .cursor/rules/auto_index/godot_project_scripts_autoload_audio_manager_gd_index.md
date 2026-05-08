# godot_project/scripts/autoload/audio_manager.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 1528 | 函数数: 78 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `sfx_played` | signal | `sfx_played(sfx_name: String, position: Vector2)` |  |
| `_ready` | function | `_ready()` |  |
| `_process` | function | `_process(delta: float)` |  |
| `_setup_audio_buses` | function | `_setup_audio_buses()` |  |
| `_setup_spatial_audio_buses` | function | `_setup_spatial_audio_buses()` |  |
| `_ensure_bus_lpf` | function | `_ensure_bus_lpf(bus_name: String, cutoff_hz: float)` |  |
| `_ensure_bus_exists` | function | `_ensure_bus_exists(bus_name: String, parent_bus_name: String)` |  |
| `_init_audio_pools` | function | `_init_audio_pools()` |  |
| `_generate_procedural_sounds` | function | `_generate_procedural_sounds()` |  |
| `_gen_noise_click` | function | `_gen_noise_click()` |  |
| `_gen_bitcrush` | function | `_gen_bitcrush(duration: float, bit_depth: int)` |  |
| `_gen_glitch_burst` | function | `_gen_glitch_burst(duration: float, intensity: float)` |  |
| `_gen_low_hum` | function | `_gen_low_hum()` |  |
| `_gen_void_impact` | function | `_gen_void_impact()` |  |
| `_gen_implosion` | function | `_gen_implosion()` |  |
| `_gen_feedback_whine` | function | `_gen_feedback_whine()` |  |
| `_gen_feedback_explosion` | function | `_gen_feedback_explosion()` |  |
| `_gen_pulse_tick` | function | `_gen_pulse_tick()` |  |
| `_gen_digital_crack` | function | `_gen_digital_crack()` |  |
| `_gen_pulse_overload` | function | `_gen_pulse_overload()` |  |
| `_gen_heavy_grind` | function | `_gen_heavy_grind()` |  |
| `_gen_metal_impact` | function | `_gen_metal_impact()` |  |
| `_gen_structure_collapse` | function | `_gen_structure_collapse()` |  |
| `_gen_cast_chime` | function | `_gen_cast_chime()` |  |
| `_gen_chord_resolve` | function | `_gen_chord_resolve()` |  |
| `_gen_perfect_beat_ring` | function | `_gen_perfect_beat_ring()` |  |
| `_gen_progression_fanfare` | function | `_gen_progression_fanfare()` |  |
| `_gen_ui_click` | function | `_gen_ui_click()` |  |
| `_gen_ui_hover` | function | `_gen_ui_hover()` |  |
| `_gen_ui_confirm` | function | `_gen_ui_confirm()` |  |
| `_gen_ui_cancel` | function | `_gen_ui_cancel()` |  |
| `_gen_level_up` | function | `_gen_level_up()` |  |
| `_gen_note_silenced` | function | `_gen_note_silenced()` |  |
| `_gen_density_overload` | function | `_gen_density_overload()` |  |
| `_gen_crit_hit` | function | `_gen_crit_hit()` |  |
| `_gen_rest_cleanse` | function | `_gen_rest_cleanse()` |  |
| `_create_wav` | function | `_create_wav(data: PackedByteArray, sample_rate: int)` |  |
| `_connect_global_signals` | function | `_connect_global_signals()` |  |
| `play_enemy_stun_sfx` | function | `play_enemy_stun_sfx(position: Vector2, enemy_node: Node = null)` |  |
| `play_spell_cast_sfx` | function | `play_spell_cast_sfx(position: Vector2, is_perfect_beat: bool = false)` |  |
| `play_chord_cast_sfx` | function | `play_chord_cast_sfx(position: Vector2, chord_data: Dictionary = {})` |  |
| `_play_spell_form_sfx` | function | `_play_spell_form_sfx(spell_form: int, position: Vector2)` |  |
| `play_progression_resolve_sfx` | function | `play_progression_resolve_sfx()` |  |
| `play_player_hit_sfx` | function | `play_player_hit_sfx()` |  |
| `play_ui_click` | function | `play_ui_click()` |  |
| `play_ui_hover` | function | `play_ui_hover()` |  |
| `play_ui_confirm` | function | `play_ui_confirm()` |  |
| `play_ui_cancel` | function | `play_ui_cancel()` |  |
| `play_level_up_sfx` | function | `play_level_up_sfx()` |  |
| `play_note_silenced_sfx` | function | `play_note_silenced_sfx()` |  |
| `play_density_overload_sfx` | function | `play_density_overload_sfx()` |  |
| `play_crit_sfx` | function | `play_crit_sfx(position: Vector2)` |  |
| `play_rest_cleanse_sfx` | function | `play_rest_cleanse_sfx()` |  |
| `register_enemy` | function | `register_enemy(enemy: Node, enemy_type_name: String)` |  |
| `unregister_enemy` | function | `unregister_enemy(enemy: Node)` |  |
| `_on_enemy_stunned` | function | `_on_enemy_stunned(duration: float, enemy: Node)` |  |
| `_on_level_up` | function | `_on_level_up(_new_level: int)` |  |
| `_on_player_died` | function | `_on_player_died()` |  |
| `_on_spell_cast` | function | `_on_spell_cast(spell_data: Dictionary)` |  |
| `_on_chord_cast` | function | `_on_chord_cast(chord_data: Dictionary)` |  |
| `_on_spell_blocked_by_silence` | function | `_on_spell_blocked_by_silence(_note: int)` |  |
| `_on_accuracy_penalized` | function | `_on_accuracy_penalized(_penalty: float)` |  |
| `_setup_event_queue` | function | `_setup_event_queue()` |  |
| `set_quantize_mode` | function | `set_quantize_mode(mode: AudioEventQueue.QuantizeMode)` |  |
| `get_quantize_mode` | function | `get_quantize_mode()` |  |
| `get_quantize_stats` | function | `get_quantize_stats()` |  |
| `_get_pooled_2d` | function | `_get_pooled_2d()` |  |
| `_get_pooled_global` | function | `_get_pooled_global()` |  |
| `_check_cooldown` | function | `_check_cooldown(key: String, interval: float = MIN_SFX_INTERVAL)` |  |
| `_update_cooldowns` | function | `_update_cooldowns(_delta: float)` |  |
| `set_sfx_volume` | function | `set_sfx_volume(volume: float)` |  |
| `set_enemy_sfx_volume` | function | `set_enemy_sfx_volume(volume: float)` |  |
| `set_player_sfx_volume` | function | `set_player_sfx_volume(volume: float)` |  |
| `set_ui_volume` | function | `set_ui_volume(volume: float)` |  |
| `_get_spatial_controller` | function | `_get_spatial_controller(enemy_node: Node)` |  |
| `update_spatial_bus_lpf` | function | `update_spatial_bus_lpf(bus_name: String, cutoff_hz: float)` |  |
| `_calculate_relative_pitch_scale` | function | `_calculate_relative_pitch_scale(spell_data: Dictionary)` |  |
| `_resolve_chord_notes_relative` | function | `_resolve_chord_notes_relative(chord_notes: Array)` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/autoload/audio_manager.gd
```
