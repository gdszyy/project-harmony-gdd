# godot_project/scripts/ui/toast_notification.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 387 | 函数数: 24 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `toast_shown` | signal | `toast_shown(toast_type: String, message: String)` |  |
| `toast_dismissed` | signal | `toast_dismissed(toast_type: String)` |  |
| `ToastType` | enum | `ToastType()` |  |
| `_ready` | function | `_ready()` |  |
| `_process` | function | `_process(_delta: float)` |  |
| `show_toast` | function | `show_toast(message: String, type: int = ToastType.INFO, duration: float = -1.0, subtitle: String = "")` |  |
| `info` | function | `info(message: String, subtitle: String = "")` |  |
| `success` | function | `success(message: String, subtitle: String = "")` |  |
| `warning` | function | `warning(message: String, subtitle: String = "")` |  |
| `error` | function | `error(message: String, subtitle: String = "")` |  |
| `achievement` | function | `achievement(message: String, subtitle: String = "")` |  |
| `item` | function | `item(message: String, subtitle: String = "")` |  |
| `level_up` | function | `level_up(message: String, subtitle: String = "")` |  |
| `codex` | function | `codex(message: String, subtitle: String = "")` |  |
| `clear_all` | function | `clear_all()` |  |
| `_show_toast_internal` | function | `_show_toast_internal(data: Dictionary)` |  |
| `_release_toast` | function | `_release_toast(panel_idx: int, type: int)` |  |
| `_reposition_active_toasts` | function | `_reposition_active_toasts()` |  |
| `_update_panel_content` | function | `_update_panel_content(panel: PanelContainer, config: Dictionary, message: String, subtitle: String)` |  |
| `_update_panel_style` | function | `_update_panel_style(panel: PanelContainer, config: Dictionary)` |  |
| `_create_pool` | function | `_create_pool()` |  |
| `_acquire_panel` | function | `_acquire_panel()` |  |
| `_create_toast_panel` | function | `_create_toast_panel()` |  |
| `_get_type_name` | function | `_get_type_name(type: int)` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/ui/toast_notification.gd
```
