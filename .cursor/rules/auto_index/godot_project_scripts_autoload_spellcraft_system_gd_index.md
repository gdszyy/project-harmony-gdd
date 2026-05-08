# godot_project/scripts/autoload/spellcraft_system.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 1380 | 函数数: 72 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `spell_cast` | signal | `spell_cast(spell_data: Dictionary)` |  |
| `chord_cast` | signal | `chord_cast(chord_data: Dictionary)` |  |
| `modifier_applied` | signal | `modifier_applied(modifier: MusicData.ModifierEffect)` |  |
| `sequencer_updated` | signal | `sequencer_updated(sequence: Array)` |  |
| `rhythm_pattern_changed` | signal | `rhythm_pattern_changed(pattern: MusicData.RhythmPattern)` |  |
| `timbre_changed` | signal | `timbre_changed(timbre: MusicData.TimbreType)` |  |
| `progression_resolved` | signal | `progression_resolved(progression: Dictionary)` |  |
| `spell_blocked_by_silence` | signal | `spell_blocked_by_silence(note: MusicData.WhiteKey)` |  |
| `accuracy_penalized` | signal | `accuracy_penalized(penalty: float)` |  |
| `phase_switched` | signal | `phase_switched(phase_name: String)` |  |
| `monotone_silence_triggered` | signal | `monotone_silence_triggered(data: Dictionary)` |  |
| `noise_overload_triggered` | signal | `noise_overload_triggered(data: Dictionary)` |  |
| `dissonance_corrosion_triggered` | signal | `dissonance_corrosion_triggered(data: Dictionary)` |  |
| `_ready` | function | `_ready()` |  |
| `_on_game_reset_event` | function | `_on_game_reset_event(_payload: Variant = null)` |  |
| `_process` | function | `_process(delta: float)` |  |
| `_init_sequencer` | function | `_init_sequencer()` |  |
| `_init_manual_slots` | function | `_init_manual_slots()` |  |
| `set_sequencer_note` | function | `set_sequencer_note(position: int, white_key: MusicData.WhiteKey)` |  |
| `set_sequencer_chord` | function | `set_sequencer_chord(measure: int, spell_id: String)` |  |
| `set_sequencer_chord_raw` | function | `set_sequencer_chord_raw(measure: int, chord_notes: Array)` |  |
| `set_sequencer_rest` | function | `set_sequencer_rest(position: int)` |  |
| `clear_sequencer` | function | `clear_sequencer()` |  |
| `_unequip_sequencer_slot` | function | `_unequip_sequencer_slot(position: int)` |  |
| `set_manual_slot` | function | `set_manual_slot(slot_index: int, spell_data: Dictionary)` |  |
| `clear_manual_slot` | function | `clear_manual_slot(slot_index: int)` |  |
| `_unequip_manual_slot` | function | `_unequip_manual_slot(slot_index: int)` |  |
| `trigger_manual_cast` | function | `trigger_manual_cast(slot_index: int)` |  |
| `_update_manual_slot_cooldowns` | function | `_update_manual_slot_cooldowns(delta: float)` |  |
| `get_manual_slot_cooldown_progress` | function | `get_manual_slot_cooldown_progress(slot_index: int)` |  |
| `handle_black_key_input` | function | `handle_black_key_input(black_key: MusicData.BlackKey)` |  |
| `apply_black_key_modifier` | function | `apply_black_key_modifier(black_key: MusicData.BlackKey)` |  |
| `_consume_modifier` | function | `_consume_modifier()` |  |
| `_black_key_to_midi` | function | `_black_key_to_midi(black_key: MusicData.BlackKey)` |  |
| `add_to_chord_buffer` | function | `add_to_chord_buffer(note: int)` |  |
| `_flush_chord_buffer` | function | `_flush_chord_buffer()` |  |
| `_on_beat_tick` | function | `_on_beat_tick(beat_index: int)` |  |
| `_on_half_beat_tick` | function | `_on_half_beat_tick(_half_beat_index: int)` |  |
| `_on_measure_complete` | function | `_on_measure_complete(measure_index: int)` |  |
| `_execute_sequencer_position` | function | `_execute_sequencer_position(pos: int)` |  |
| `_cast_single_note_from_sequencer` | function | `_cast_single_note_from_sequencer(slot: Dictionary, pos: int)` |  |
| `_cast_single_note` | function | `_cast_single_note(note: int)` |  |
| `_cast_chord` | function | `_cast_chord(chord_result: Dictionary)` |  |
| `_cast_chord_from_sequencer` | function | `_cast_chord_from_sequencer(slot: Dictionary, _pos: int)` |  |
| `_update_measure_rhythm` | function | `_update_measure_rhythm(measure_idx: int)` |  |
| `_analyze_rhythm_pattern` | function | `_analyze_rhythm_pattern(start_pos: int)` |  |
| `_apply_rhythm_modifier` | function | `_apply_rhythm_modifier(stats: Dictionary, rhythm: MusicData.RhythmPattern, _measure_idx: int)` |  |
| `_trigger_progression_effect` | function | `_trigger_progression_effect(progression: Dictionary)` |  |
| `_apply_burst_effect` | function | `_apply_burst_effect(bonus_mult: float)` |  |
| `_apply_empower_buff` | function | `_apply_empower_buff(bonus_mult: float)` |  |
| `_apply_cooldown_reduction` | function | `_apply_cooldown_reduction(bonus_mult: float)` |  |
| `_note_to_white_key` | function | `_note_to_white_key(note: int)` |  |
| `_midi_to_black_key` | function | `_midi_to_black_key(note: int)` |  |
| `_execute_spell` | function | `_execute_spell(spell_data: Dictionary)` |  |
| `get_sequencer_position` | function | `get_sequencer_position()` |  |
| `get_sequencer_data` | function | `get_sequencer_data()` |  |
| `reset` | function | `reset()` |  |
| `switch_spectral_phase` | function | `switch_spectral_phase(phase: int)` |  |
| `switch_to_overtone` | function | `switch_to_overtone()` |  |
| `switch_to_sub_bass` | function | `switch_to_sub_bass()` |  |
| `switch_to_fundamental` | function | `switch_to_fundamental()` |  |
| `get_current_spectral_phase` | function | `get_current_spectral_phase()` |  |
| `get_current_phase_name` | function | `get_current_phase_name()` |  |
| `get_phase_energy_ratio` | function | `get_phase_energy_ratio()` |  |
| `_update_phase_energy` | function | `_update_phase_energy(delta: float)` |  |
| `set_timbre` | function | `set_timbre(timbre: MusicData.TimbreType)` |  |
| `get_current_timbre` | function | `get_current_timbre()` |  |
| `set_chapter_timbre` | function | `set_chapter_timbre(timbre: MusicData.ChapterTimbre)` |  |
| `get_current_chapter_timbre` | function | `get_current_chapter_timbre()` |  |
| `_apply_chapter_timbre_mechanics` | function | `_apply_chapter_timbre_mechanics(spell_data: Dictionary)` |  |
| `get_timbre_info` | function | `get_timbre_info(timbre: MusicData.TimbreType)` |  |
| `_spawn_dodge_afterimage` | function | `_spawn_dodge_afterimage(player: CharacterBody2D)` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/autoload/spellcraft_system.gd
```
