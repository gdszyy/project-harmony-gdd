## events.gd
## 全局事件名称常量定义
## 提供类型安全的事件名称，避免拼写错误
##
## 参考设计文档: EventBus_Architecture_Design.md (tsk-c61b04fa-930)
class_name Events

# ============================================================
# 游戏生命周期事件
# ============================================================
## 游戏重置到主菜单状态
const GAME_RESET: String = "game_reset"
## 新一局游戏开始
const GAME_STARTED: String = "game_started"
## 游戏暂停
const GAME_PAUSED: String = "game_paused"
## 游戏恢复
const GAME_RESUMED: String = "game_resumed"
## 游戏结束（玩家死亡或通关）
## payload: { "reason": String }
const GAME_OVER: String = "game_over"
## 进入升级选择界面
const UPGRADE_SELECT_ENTERED: String = "upgrade_select_entered"

# ============================================================
# 玩家状态事件
# ============================================================
## 玩家受到伤害
## payload: { "damage": float, "source_pos": Vector2 }
const PLAYER_DAMAGED: String = "player_damaged"
## 玩家死亡
## payload: null
const PLAYER_DIED: String = "player_died"
## 玩家血量变化
## payload: { "current_hp": float, "max_hp": float }
const PLAYER_HP_CHANGED: String = "player_hp_changed"
## 玩家升级
## payload: { "new_level": int }
const PLAYER_LEVEL_UP: String = "player_level_up"
## 玩家获得经验值
## payload: { "amount": int }
const XP_GAINED: String = "xp_gained"
## 玩家治疗
## payload: { "amount": float, "new_hp": float }
const PLAYER_HEALED: String = "player_healed"

# ============================================================
# 升级系统事件
# ============================================================
## 玩家选择了一个升级
## payload: { "upgrade": Dictionary }
const UPGRADE_SELECTED: String = "upgrade_selected"
## 玩家获得了一个章节词条
## payload: { "inscription": Dictionary }
const INSCRIPTION_ACQUIRED: String = "inscription_acquired"
## 音乐史彩蛋被触发
## payload: { "egg": Dictionary }
const EASTER_EGG_TRIGGERED: String = "easter_egg_triggered"

# ============================================================
# 节拍系统事件
# ============================================================
## 四分音符节拍触发
## payload: { "beat": int }
const BEAT_TICK: String = "beat_tick"
## 八分音符节拍触发
## payload: { "half_beat": int }
const HALF_BEAT_TICK: String = "half_beat_tick"
## 小节完成
## payload: { "measure": int }
const MEASURE_COMPLETED: String = "measure_completed"
## BPM 变更
## payload: { "new_bpm": float }
const BPM_CHANGED: String = "bpm_changed"

# ============================================================
# 战斗事件
# ============================================================
## 敌人被击杀
## payload: { "position": Vector2, "enemy_type": String }
const ENEMY_KILLED: String = "enemy_killed"
## 波次开始
## payload: { "wave_number": int, "wave_type": String }
const WAVE_STARTED: String = "wave_started"
## 波次完成
## payload: { "wave_number": int }
const WAVE_COMPLETED: String = "wave_completed"
## 伤害造成
## payload: { "amount": float, "target_type": String, "position": Vector2 }
const DAMAGE_DEALT: String = "damage_dealt"

# ============================================================
# 法术与音符事件
# ============================================================
## 不和谐度造成伤害
## payload: { "dissonance": float, "damage": float }
const DISSONANCE_APPLIED: String = "dissonance_applied"
## 和弦法术合成
## payload: { "chord_spell": Dictionary }
const CHORD_SPELL_CRAFTED: String = "chord_spell_crafted"
## 音符库存变化
## payload: { "note_key": int, "new_count": int }
const NOTE_INVENTORY_CHANGED: String = "note_inventory_changed"

# ============================================================
# 章节事件
# ============================================================
## 章节切换开始
## payload: { "from_chapter": int, "to_chapter": int }
const CHAPTER_TRANSITION_STARTED: String = "chapter_transition_started"
## 章节切换完成
## payload: { "new_chapter": int }
const CHAPTER_TRANSITION_COMPLETED: String = "chapter_transition_completed"
## 章节音色变更
## payload: { "new_timbre": int }
const CHAPTER_TIMBRE_CHANGED: String = "chapter_timbre_changed"

# ============================================================
# Boss 事件
# ============================================================
## Boss 战开始
## payload: { "boss_name": String }
const BOSS_FIGHT_STARTED: String = "boss_fight_started"
## Boss 战结束
## payload: { "boss_name": String, "victory": bool }
const BOSS_FIGHT_ENDED: String = "boss_fight_ended"
## Boss 血量变化
## payload: { "boss_key": String, "current_hp": float, "max_hp": float }
const BOSS_HEALTH_CHANGED: String = "boss_health_changed"

# ============================================================
# 音频事件
# ============================================================
## BGM 强度变化
## payload: { "intensity": float }
const BGM_INTENSITY_CHANGED: String = "bgm_intensity_changed"
## 调性变化
## payload: { "chapter_id": int, "mode_name": String, "scale_notes": Array }
const TONALITY_CHANGED: String = "tonality_changed"
