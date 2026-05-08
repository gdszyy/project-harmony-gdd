# godot_project/scripts/autoload/meta_progression_manager.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 895 | 函数数: 51 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `resonance_fragments_changed` | signal | `resonance_fragments_changed(new_total: int)` |  |
| `upgrade_purchased` | signal | `upgrade_purchased(module: String, upgrade_id: String, new_level: int)` |  |
| `mode_unlocked` | signal | `mode_unlocked(mode_name: String)` |  |
| `mode_selected` | signal | `mode_selected(mode_name: String)` |  |
| `theory_unlocked` | signal | `theory_unlocked(theory_id: String)` | 巨型函数 |
| `_ready` | function | `_ready()` |  |
| `_init_defaults` | function | `_init_defaults()` |  |
| `save_meta_data` | function | `save_meta_data()` |  |
| `load_meta_data` | function | `load_meta_data()` |  |
| `add_resonance_fragments` | function | `add_resonance_fragments(amount: int)` |  |
| `spend_resonance_fragments` | function | `spend_resonance_fragments(amount: int)` |  |
| `get_resonance_fragments` | function | `get_resonance_fragments()` |  |
| `get_instrument_level` | function | `get_instrument_level(upgrade_id: String)` |  |
| `get_instrument_cost` | function | `get_instrument_cost(upgrade_id: String)` |  |
| `purchase_instrument_upgrade` | function | `purchase_instrument_upgrade(upgrade_id: String)` |  |
| `get_instrument_bonus` | function | `get_instrument_bonus(stat_key: String)` |  |
| `is_theory_unlocked` | function | `is_theory_unlocked(theory_id: String)` |  |
| `can_unlock_theory` | function | `can_unlock_theory(theory_id: String)` |  |
| `purchase_theory_unlock` | function | `purchase_theory_unlock(theory_id: String)` |  |
| `is_chord_unlocked` | function | `is_chord_unlocked(chord_type: String)` |  |
| `is_black_key_unlocked` | function | `is_black_key_unlocked(key_name: String)` |  |
| `is_mode_unlocked` | function | `is_mode_unlocked(mode_name: String)` |  |
| `purchase_mode_unlock` | function | `purchase_mode_unlock(mode_name: String)` |  |
| `select_mode` | function | `select_mode(mode_name: String)` |  |
| `get_selected_mode_config` | function | `get_selected_mode_config()` |  |
| `get_available_notes` | function | `get_available_notes()` |  |
| `get_mode_passive` | function | `get_mode_passive()` |  |
| `get_acoustic_level` | function | `get_acoustic_level(upgrade_id: String)` |  |
| `get_acoustic_cost` | function | `get_acoustic_cost(upgrade_id: String)` |  |
| `purchase_acoustic_upgrade` | function | `purchase_acoustic_upgrade(upgrade_id: String)` |  |
| `get_acoustic_bonus` | function | `get_acoustic_bonus(stat_key: String)` |  |
| `apply_meta_bonuses` | function | `apply_meta_bonuses()` |  |
| `_apply_instrument_bonuses` | function | `_apply_instrument_bonuses()` |  |
| `_apply_mode_passive` | function | `_apply_mode_passive()` |  |
| `_apply_acoustic_bonuses` | function | `_apply_acoustic_bonuses()` |  |
| `on_run_completed` | function | `on_run_completed(run_data: Dictionary)` |  |
| `get_upgrade_levels` | function | `get_upgrade_levels()` |  |
| `get_unlocked_skills` | function | `get_unlocked_skills()` |  |
| `get_selected_mode` | function | `get_selected_mode()` |  |
| `set_selected_mode` | function | `set_selected_mode(mode_name: String)` |  |
| `purchase_upgrade` | function | `purchase_upgrade(upgrade_id: String, _cost: int = 0)` |  |
| `unlock_skill` | function | `unlock_skill(skill_id: String, _cost: int = 0)` |  |
| `get_full_state` | function | `get_full_state()` |  |
| `debug_reset_all` | function | `debug_reset_all()` |  |
| `debug_add_fragments` | function | `debug_add_fragments(amount: int)` |  |
| `get_unlocked_upgrades` | function | `get_unlocked_upgrades()` |  |
| `unlock_upgrade` | function | `unlock_upgrade(node_id: String, cost: int)` |  |
| `get_breakthrough_log` | function | `get_breakthrough_log()` |  |
| `save_breakthrough_log` | function | `save_breakthrough_log(log_data: Array)` |  |
| `get_module_progress` | function | `get_module_progress(module: String)` |  |
| `get_total_progress` | function | `get_total_progress()` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/autoload/meta_progression_manager.gd
```
