# godot_project/scripts/autoload/bgm_manager.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 1520 | 函数数: 85 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `bgm_changed` | signal | `bgm_changed(track_name: String)` |  |
| `bgm_beat_synced` | signal | `bgm_beat_synced(beat_index: int)` |  |
| `bgm_measure_synced` | signal | `bgm_measure_synced(measure_index: int)` |  |
| `layer_toggled` | signal | `layer_toggled(layer_name: String, enabled: bool)` |  |
| `intensity_changed` | signal | `intensity_changed(new_intensity: float)` |  |
| `sixteenth_tick` | signal | `sixteenth_tick(sixteenth_index: int)` |  |
| `harmony_context_changed` | signal | `harmony_context_changed(chord_root: int, chord_type: int, chord_notes: Array)` |  |
| `tonality_changed` | signal | `tonality_changed(chapter_id: int, mode_name: String, scale_notes: Array)` |  |
| `_ready` | function | `_ready()` |  |
| `_process` | function | `_process(delta: float)` |  |
| `_setup_players` | function | `_setup_players()` |  |
| `_connect_signals` | function | `_connect_signals()` |  |
| `_connect_chapter_manager_signal` | function | `_connect_chapter_manager_signal()` |  |
| `_connect_chapter_manager_signal_deferred` | function | `_connect_chapter_manager_signal_deferred()` |  |
| `_init_default_patterns` | function | `_init_default_patterns()` |  |
| `_generate_all_samples` | function | `_generate_all_samples()` |  |
| `_gen_kick` | function | `_gen_kick()` |  |
| `_gen_kick_hard` | function | `_gen_kick_hard()` |  |
| `_gen_snare` | function | `_gen_snare()` |  |
| `_gen_clap` | function | `_gen_clap()` |  |
| `_gen_hihat_closed` | function | `_gen_hihat_closed()` |  |
| `_gen_hihat_open` | function | `_gen_hihat_open()` |  |
| `_gen_ghost_tap` | function | `_gen_ghost_tap()` |  |
| `_gen_ghost_rim` | function | `_gen_ghost_rim()` |  |
| `_gen_bass_note` | function | `_gen_bass_note(freq: float)` |  |
| `_gen_pad_chord` | function | `_gen_pad_chord(freqs: Array)` |  |
| `_create_wav` | function | `_create_wav(data: PackedByteArray)` |  |
| `start_bgm` | function | `start_bgm(bpm: float = 0.0)` |  |
| `stop_bgm` | function | `stop_bgm(fade_out: bool = true)` |  |
| `pause_bgm` | function | `pause_bgm()` |  |
| `resume_bgm` | function | `resume_bgm()` |  |
| `set_intensity` | function | `set_intensity(value: float)` |  |
| `get_intensity` | function | `get_intensity()` |  |
| `toggle_layer` | function | `toggle_layer(layer_name: String, enabled: bool)` |  |
| `set_layer_volume` | function | `set_layer_volume(layer_name: String, volume_db: float)` |  |
| `get_bgm_bpm` | function | `get_bgm_bpm()` |  |
| `is_playing` | function | `is_playing()` |  |
| `get_current_track` | function | `get_current_track()` |  |
| `set_bgm_volume` | function | `set_bgm_volume(volume: float)` |  |
| `set_hihat_pattern` | function | `set_hihat_pattern(pattern_name: String)` |  |
| `set_ghost_pattern` | function | `set_ghost_pattern(pattern_name: String)` |  |
| `set_bass_pattern` | function | `set_bass_pattern(pattern_name: String)` |  |
| `auto_select_bgm_for_state` | function | `auto_select_bgm_for_state(state: GameManager.GameState)` |  |
| `_tick_sixteenth` | function | `_tick_sixteenth()` |  |
| `_start_pad_loop` | function | `_start_pad_loop()` |  |
| `_update_pad_chord` | function | `_update_pad_chord()` |  |
| `update_fatigue_mix` | function | `update_fatigue_mix(fatigue_level: int, fatigue_afi: float)` |  |
| `_connect_fatigue_signals` | function | `_connect_fatigue_signals()` |  |
| `_on_fatigue_level_changed` | function | `_on_fatigue_level_changed(new_level: MusicData.FatigueLevel)` |  |
| `_update_layer_mix` | function | `_update_layer_mix()` |  |
| `_update_timing` | function | `_update_timing()` |  |
| `_reset_clock` | function | `_reset_clock()` |  |
| `_stop_all_players` | function | `_stop_all_players()` |  |
| `_apply_muffle_effect` | function | `_apply_muffle_effect(enable: bool)` |  |
| `play_external_bgm` | function | `play_external_bgm(track_path: String, fade_duration: float = 1.0)` |  |
| `stop_external_bgm` | function | `stop_external_bgm(fade_duration: float = 1.0)` |  |
| `_on_game_state_changed` | function | `_on_game_state_changed(new_state: GameManager.GameState)` |  |
| `_init_harmony_conductor` | function | `_init_harmony_conductor()` |  |
| `_reset_harmony_conductor` | function | `_reset_harmony_conductor()` |  |
| `_on_player_chord_identified` | function | `_on_player_chord_identified(chord_type: int, root_note: int)` |  |
| `_on_harmony_measure_synced` | function | `_on_harmony_measure_synced(measure_index: int)` |  |
| `_apply_chord_change` | function | `_apply_chord_change(root: int, type: int)` |  |
| `_calculate_chord_notes` | function | `_calculate_chord_notes(root: int, type: int)` |  |
| `_get_markov_next_chord` | function | `_get_markov_next_chord(current_root: int)` |  |
| `_regenerate_dynamic_pad_sample` | function | `_regenerate_dynamic_pad_sample()` |  |
| `_regenerate_dynamic_bass_sample` | function | `_regenerate_dynamic_bass_sample()` |  |
| `_crossfade_pad_to_dynamic` | function | `_crossfade_pad_to_dynamic()` |  |
| `get_current_chord` | function | `get_current_chord()` |  |
| `get_current_scale` | function | `get_current_scale()` |  |
| `get_chord_note_for_degree` | function | `get_chord_note_for_degree(degree: int)` |  |
| `quantize_to_scale` | function | `quantize_to_scale(pitch_class: int)` |  |
| `_note_name` | function | `_note_name(pc: int)` |  |
| `_on_chapter_started_tonality` | function | `_on_chapter_started_tonality(chapter_id: int, _chapter_name: String = "")` |  |
| `_start_tonality_transition` | function | `_start_tonality_transition(new_config: Dictionary)` |  |
| `_apply_transition_scale` | function | `_apply_transition_scale(transition_notes: Array[int])` |  |
| `_schedule_tonality_completion` | function | `_schedule_tonality_completion(new_config: Dictionary, new_scale: Array[int])` |  |
| `_complete_tonality_transition` | function | `_complete_tonality_transition(new_config: Dictionary, new_scale: Array[int])` |  |
| `_get_initial_chapter_id` | function | `_get_initial_chapter_id()` |  |
| `set_tonality` | function | `set_tonality(chapter_id: int)` |  |
| `get_current_mode` | function | `get_current_mode()` |  |
| `get_current_tonal_mode` | function | `get_current_tonal_mode()` |  |
| `get_current_tonality_chapter` | function | `get_current_tonality_chapter()` |  |
| `is_tonality_transitioning` | function | `is_tonality_transitioning()` |  |
| `_on_game_started_event` | function | `_on_game_started_event(payload: Variant)` |  |
| `_on_game_reset_event` | function | `_on_game_reset_event(_payload: Variant = null)` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/autoload/bgm_manager.gd
```
