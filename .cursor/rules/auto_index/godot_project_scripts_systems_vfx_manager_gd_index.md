# godot_project/scripts/systems/vfx_manager.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 440 | 函数数: 21 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `_ready` | function | `_ready()` |  |
| `_process` | function | `_process(delta: float)` |  |
| `_create_vfx_layers` | function | `_create_vfx_layers()` |  |
| `_connect_signals` | function | `_connect_signals()` |  |
| `play_progression_shockwave` | function | `play_progression_shockwave(function_type: String = "tonic")` |  |
| `_play_progression_vfx_enhanced` | function | `_play_progression_vfx_enhanced(function_type: String)` |  |
| `play_mode_switch` | function | `play_mode_switch(mode_name: String)` |  |
| `play_screen_flash` | function | `play_screen_flash(color: Color = Color.WHITE, duration: float = 0.15)` |  |
| `play_boss_phase_transition` | function | `play_boss_phase_transition()` |  |
| `play_evaluation_vfx` | function | `play_evaluation_vfx(grade: String)` |  |
| `switch_spectral_phase` | function | `switch_spectral_phase(phase: int)` |  |
| `trigger_noise_overload` | function | `trigger_noise_overload(intensity: float = 0.5)` |  |
| `trigger_dissonance_corrosion` | function | `trigger_dissonance_corrosion(intensity: float = 0.5)` |  |
| `trigger_monotone_silence` | function | `trigger_monotone_silence(intensity: float = 0.5)` |  |
| `_update_penalty_shader` | function | `_update_penalty_shader()` |  |
| `_on_progression_resolved` | function | `_on_progression_resolved(progression_type: String, _completeness: float)` |  |
| `_on_mode_changed` | function | `_on_mode_changed(mode_name: String)` |  |
| `_on_phase_switched` | function | `_on_phase_switched(phase_name: String)` |  |
| `_on_monotone_silence` | function | `_on_monotone_silence(_data: Dictionary)` |  |
| `_on_noise_overload` | function | `_on_noise_overload(_data: Dictionary)` |  |
| `_on_dissonance_corrosion` | function | `_on_dissonance_corrosion(_data: Dictionary)` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/systems/vfx_manager.gd
```
