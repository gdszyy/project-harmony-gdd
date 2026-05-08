# godot_project/scripts/entities/summon_audio_controller.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 684 | 函数数: 36 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `audio_triggered` | signal | `audio_triggered(timbre_id: String, frequency: float)` |  |
| `audio_sustained_updated` | signal | `audio_sustained_updated(timbre_id: String, chord_notes: Array)` |  |
| `_ready` | function | `_ready()` |  |
| `_exit_tree` | function | `_exit_tree()` |  |
| `_connect_trigger_signals` | function | `_connect_trigger_signals()` |  |
| `_on_beat` | function | `_on_beat(beat_index: int)` |  |
| `_on_beat_strong_only` | function | `_on_beat_strong_only(beat_index: int)` |  |
| `_on_sixteenth` | function | `_on_sixteenth(_sixteenth_index: int)` |  |
| `trigger_on_event` | function | `trigger_on_event()` |  |
| `_trigger_sound` | function | `_trigger_sound()` |  |
| `_resolve_pitch` | function | `_resolve_pitch()` |  |
| `_get_current_chord` | function | `_get_current_chord()` |  |
| `_get_current_scale` | function | `_get_current_scale()` |  |
| `_start_sustained_playback` | function | `_start_sustained_playback()` |  |
| `_on_harmony_changed` | function | `_on_harmony_changed(chord_root: int, chord_type: int, chord_notes: Array)` |  |
| `_play_summon_tone` | function | `_play_summon_tone(frequency: float, timbre_id: String)` |  |
| `_play_percussion_tone` | function | `_play_percussion_tone(timbre_id: String)` |  |
| `_play_sustained_pad` | function | `_play_sustained_pad(notes: Array, octave: int)` |  |
| `_play_sustained_gate_pulse` | function | `_play_sustained_gate_pulse(notes: Array, octave: int)` |  |
| `_update_sustained_sound` | function | `_update_sustained_sound(notes: Array, octave: int)` |  |
| `_synthesize_tone` | function | `_synthesize_tone(frequency: float, timbre_id: String)` |  |
| `_synthesize_percussion` | function | `_synthesize_percussion(timbre_id: String)` |  |
| `_synthesize_pad` | function | `_synthesize_pad(frequencies: Array[float])` |  |
| `_synthesize_gate_pulse` | function | `_synthesize_gate_pulse(frequency: float)` |  |
| `_gen_pluck` | function | `_gen_pluck(freq: float, duration: float)` |  |
| `_gen_delay_echo` | function | `_gen_delay_echo(freq: float, duration: float)` |  |
| `_gen_sweep` | function | `_gen_sweep(freq: float, duration: float)` |  |
| `_gen_sub_bass` | function | `_gen_sub_bass(freq: float, duration: float)` |  |
| `_gen_hihat` | function | `_gen_hihat(duration: float)` |  |
| `_gen_pad_chord` | function | `_gen_pad_chord(freqs: Array[float], duration: float)` |  |
| `_gen_gate_pulse` | function | `_gen_gate_pulse(freq: float, duration: float)` |  |
| `_create_wav` | function | `_create_wav(data: PackedByteArray)` |  |
| `_midi_to_frequency` | function | `_midi_to_frequency(midi_note: int)` |  |
| `deactivate` | function | `deactivate()` |  |
| `is_audio_active` | function | `is_audio_active()` |  |
| `get_audio_info` | function | `get_audio_info()` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/entities/summon_audio_controller.gd
```
