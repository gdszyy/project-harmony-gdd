# godot_project/scripts/systems/spatial_audio_controller.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 452 | 函数数: 25 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `SpatialAudioController` | class_name | `SpatialAudioController()` |  |
| `spatial_params_changed` | signal | `spatial_params_changed(params: Dictionary)` |  |
| `DistanceZone` | enum | `DistanceZone()` |  |
| `_ready` | function | `_ready()` |  |
| `_process` | function | `_process(delta: float)` |  |
| `_update_spatial_params` | function | `_update_spatial_params()` |  |
| `_calculate_zone` | function | `_calculate_zone(distance: float)` |  |
| `_calculate_lpf_cutoff` | function | `_calculate_lpf_cutoff(distance: float)` |  |
| `_calculate_pitch_scale` | function | `_calculate_pitch_scale()` |  |
| `_calculate_pan` | function | `_calculate_pan(enemy_pos: Vector2, player_pos: Vector2)` |  |
| `get_spatial_bus` | function | `get_spatial_bus()` |  |
| `get_lpf_cutoff` | function | `get_lpf_cutoff()` |  |
| `get_pitch_scale` | function | `get_pitch_scale()` |  |
| `get_pan` | function | `get_pan()` |  |
| `get_distance_zone` | function | `get_distance_zone()` |  |
| `get_normalized_distance` | function | `get_normalized_distance()` |  |
| `is_in_hearing_range` | function | `is_in_hearing_range()` |  |
| `get_active_state` | function | `get_active_state()` |  |
| `get_spatial_snapshot` | function | `get_spatial_snapshot()` |  |
| `apply_state_fx` | function | `apply_state_fx(state: String)` |  |
| `clear_state_fx` | function | `clear_state_fx()` |  |
| `get_state_fx_params` | function | `get_state_fx_params()` |  |
| `modify_playback_params` | function | `modify_playback_params(base_volume_db: float, base_pitch: float, base_bus: String)` |  |
| `_apply_state_fx_to_params` | function | `_apply_state_fx_to_params(result: Dictionary, fx_params: Dictionary)` |  |
| `_find_player` | function | `_find_player()` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/systems/spatial_audio_controller.gd
```
