# godot_project/scripts/data/chapter_data.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 1554 | 函数数: 18 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `ChapterData` | class_name | `ChapterData()` |  |
| `Chapter` | enum | `Chapter()` | 巨型函数 |
| `get_chapter_config` | static_func | `get_chapter_config(chapter: int)` |  |
| `get_wave_template` | static_func | `get_wave_template(chapter: int, wave_number: int)` |  |
| `get_available_enemies` | static_func | `get_available_enemies(chapter: int, wave_number: int)` |  |
| `weighted_select_enemy` | static_func | `weighted_select_enemy(chapter: int, wave_number: int)` |  |
| `select_elite` | static_func | `select_elite(chapter: int, wave_number: int)` |  |
| `get_enemy_base_stats` | static_func | `get_enemy_base_stats(enemy_type: String)` |  |
| `is_chapter_enemy` | static_func | `is_chapter_enemy(enemy_type: String)` |  |
| `is_elite_enemy` | static_func | `is_elite_enemy(enemy_type: String)` |  |
| `get_chapter_count` | static_func | `get_chapter_count()` |  |
| `get_next_chapter` | static_func | `get_next_chapter(current: int)` |  |
| `get_special_mechanics` | static_func | `get_special_mechanics(chapter: int)` |  |
| `get_chapter_timbre` | static_func | `get_chapter_timbre(chapter: int)` |  |
| `get_chapter_inscriptions` | static_func | `get_chapter_inscriptions(chapter: int)` |  |
| `get_inscription_by_id` | static_func | `get_inscription_by_id(inscription_id: String)` |  |
| `check_easter_eggs` | static_func | `check_easter_eggs(owned_inscription_ids: Array[String])` |  |
| `get_electronic_variant` | static_func | `get_electronic_variant(chapter: int)` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/data/chapter_data.gd
```
