# godot_project/scripts/audio/synth/synth_voice.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 525 | 函数数: 22 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `SynthVoice` | class_name | `SynthVoice()` |  |
| `voice_finished` | signal | `voice_finished()` |  |
| `_ready` | function | `_ready()` |  |
| `_process` | function | `_process(delta: float)` |  |
| `play_note` | function | `play_note(frequency: float, timbre_params: Dictionary)` |  |
| `stop_note` | function | `stop_note()` |  |
| `force_stop` | function | `force_stop()` |  |
| `is_playing` | function | `is_playing()` |  |
| `set_voice_position` | function | `set_voice_position(pos: Vector2)` |  |
| `_generate_sample` | function | `_generate_sample(filter_mod: float)` |  |
| `_generate_standard_sample` | function | `_generate_standard_sample()` |  |
| `_generate_fm_sample` | function | `_generate_fm_sample()` |  |
| `_generate_spectral_sample` | function | `_generate_spectral_sample()` |  |
| `_generate_supersaw_sample` | function | `_generate_supersaw_sample()` |  |
| `_init_supersaw_oscillators` | function | `_init_supersaw_oscillators()` |  |
| `_oscillator` | function | `_oscillator(phase: float, waveform: int)` |  |
| `_square_wave` | function | `_square_wave(phase: float)` |  |
| `_sawtooth_wave` | function | `_sawtooth_wave(phase: float)` |  |
| `_triangle_wave` | function | `_triangle_wave(phase: float)` |  |
| `_apply_filter` | function | `_apply_filter(sample: float, filter_mod: float)` |  |
| `_apply_bitcrush` | function | `_apply_bitcrush(sample: float)` |  |
| `_soft_clip` | function | `_soft_clip(sample: float)` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/audio/synth/synth_voice.gd
```
