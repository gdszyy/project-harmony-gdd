# godot_project/scripts/systems/note_synthesizer.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 511 | 函数数: 18 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `NoteSynthesizer` | class_name | `NoteSynthesizer()` |  |
| `pregenerate_common_notes` | function | `pregenerate_common_notes(timbre: int = MusicData.TimbreType.NONE)` |  |
| `clear_cache` | function | `clear_cache()` |  |
| `has_external_samples` | function | `has_external_samples(timbre: int)` |  |
| `_calculate_envelope` | function | `_calculate_envelope(t: float, note_duration: float, adsr: Dictionary)` |  |
| `_triangle_wave` | function | `_triangle_wave(phase: float)` |  |
| `_sawtooth_wave` | function | `_sawtooth_wave(phase: float)` |  |
| `_square_wave` | function | `_square_wave(phase: float)` |  |
| `_apply_timbre_character` | function | `_apply_timbre_character(wave: float, t: float, freq: float, timbre: int)` |  |
| `_apply_simple_lowpass` | function | `_apply_simple_lowpass(buffer: Array[float], cutoff_factor: float)` |  |
| `_apply_soft_compression` | function | `_apply_soft_compression(buffer: Array[float], threshold: float)` |  |
| `_try_load_sample` | function | `_try_load_sample(note: int, timbre: int, octave: int)` |  |
| `_get_frequency` | function | `_get_frequency(note: int, octave: int)` |  |
| `_get_adsr_params` | function | `_get_adsr_params(timbre: int)` |  |
| `_make_cache_key` | function | `_make_cache_key(note: int, timbre: int, octave: int, duration: float)` |  |
| `_buffer_to_wav` | function | `_buffer_to_wav(buffer: Array[float])` |  |
| `_generate_silence` | function | `_generate_silence(duration: float)` |  |
| `_cache_put` | function | `_cache_put(key: String, wav: AudioStreamWAV)` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/systems/note_synthesizer.gd
```
