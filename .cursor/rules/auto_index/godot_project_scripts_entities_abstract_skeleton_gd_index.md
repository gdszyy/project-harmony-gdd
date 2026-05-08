# godot_project/scripts/entities/abstract_skeleton.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 537 | 函数数: 37 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `AbstractSkeleton` | class_name | `AbstractSkeleton()` |  |
| `gesture_started` | signal | `gesture_started(gesture_name: String)` |  |
| `gesture_finished` | signal | `gesture_finished(gesture_name: String)` |  |
| `stance_changed` | signal | `stance_changed(new_stance: String)` |  |
| `BoneID` | enum | `BoneID()` |  |
| `_ready` | function | `_ready()` |  |
| `_process` | function | `_process(delta: float)` |  |
| `_create_skeleton` | function | `_create_skeleton()` |  |
| `_setup_rest_poses` | function | `_setup_rest_poses()` |  |
| `_create_bone_attachments` | function | `_create_bone_attachments()` |  |
| `get_attachment` | function | `get_attachment(bone_name: String)` |  |
| `get_core_attachment` | function | `get_core_attachment()` |  |
| `get_hand_l_attachment` | function | `get_hand_l_attachment()` |  |
| `get_hand_r_attachment` | function | `get_hand_r_attachment()` |  |
| `_create_animation_player` | function | `_create_animation_player()` |  |
| `_create_animations` | function | `_create_animations()` |  |
| `_create_stance_idle` | function | `_create_stance_idle()` |  |
| `_create_stance_combat` | function | `_create_stance_combat()` |  |
| `_create_stance_channeling` | function | `_create_stance_channeling()` |  |
| `_create_gesture_point` | function | `_create_gesture_point()` |  |
| `_create_gesture_draw_circle` | function | `_create_gesture_draw_circle()` |  |
| `_create_gesture_raise` | function | `_create_gesture_raise()` |  |
| `_create_gesture_push` | function | `_create_gesture_push()` |  |
| `_create_gesture_flick` | function | `_create_gesture_flick()` |  |
| `set_stance` | function | `set_stance(stance_name: String)` |  |
| `play_gesture` | function | `play_gesture(gesture_name: String)` |  |
| `get_current_stance` | function | `get_current_stance()` |  |
| `is_gesture_playing` | function | `is_gesture_playing()` |  |
| `_update_bpm_breathing` | function | `_update_bpm_breathing(delta: float)` |  |
| `_update_modifiers` | function | `_update_modifiers(delta: float)` |  |
| `apply_impact` | function | `apply_impact(direction: Vector3 = Vector3.BACK)` |  |
| `set_glitch_intensity` | function | `set_glitch_intensity(intensity: float)` |  |
| `_apply_glitch_modifier` | function | `_apply_glitch_modifier()` |  |
| `trigger_beat_pulse` | function | `trigger_beat_pulse()` |  |
| `_connect_signals` | function | `_connect_signals()` |  |
| `_on_beat_tick` | function | `_on_beat_tick(_beat_index: int = 0)` |  |
| `_on_animation_finished` | function | `_on_animation_finished(anim_name: StringName)` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/entities/abstract_skeleton.gd
```
