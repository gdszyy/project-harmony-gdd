# BGM 音频文件目录

## 说明

本目录用于存放外部 BGM 音频文件。当前版本使用 `BGMManager` 的程序化合成引擎生成所有 BGM，
不依赖任何外部音频文件。此目录为未来替换/补充 BGM 预留。

## 当前状态

- **程序化合成 BGM**：已完成（`bgm_manager.gd`）
  - 6 层音轨：Kick / Snare / Hi-Hat / Ghost / Bass / Pad
  - 实时合成 Minimal Techno / Glitch Techno 风格
  - 与 GameManager BPM 系统同步
  - 支持疲劳等级驱动的动态混音

## 文件命名规范

如需添加外部 BGM 文件，请遵循以下命名规范：

```
bgm_{chapter}_{variant}.ogg
```

| 文件名 | 说明 |
|--------|------|
| `bgm_ch1_explore.ogg` | 第一章 探索阶段 BGM |
| `bgm_ch1_combat.ogg` | 第一章 战斗阶段 BGM |
| `bgm_ch1_boss.ogg` | 第一章 Boss 战 BGM |
| `bgm_ch2_explore.ogg` | 第二章 探索阶段 BGM |
| `bgm_menu.ogg` | 主菜单 BGM |
| `bgm_gameover.ogg` | 游戏结束 BGM |
| `bgm_victory.ogg` | 胜利 BGM |

## 技术要求

- **格式**：OGG Vorbis（Godot 4 推荐格式）
- **采样率**：44100 Hz
- **比特率**：128-192 kbps
- **声道**：立体声
- **循环**：BGM 文件应设置循环点（在 Godot 导入设置中配置）
- **BPM**：应与 `GameManager.current_bpm`（默认 120）对齐，或为其整数倍/约数

## 推荐音频来源

- [Freesound.org](https://freesound.org) — CC0 / CC-BY 免费音效
- [OpenGameArt.org](https://opengameart.org) — 游戏用免费音频资源
- [Incompetech](https://incompetech.com) — Kevin MacLeod 免版税音乐
- [Free Music Archive](https://freemusicarchive.org) — CC 授权音乐

## 集成方式

外部 BGM 文件可通过 `BGMManager.play_external_bgm(track_path)` 接口播放，
该接口会自动处理淡入淡出和与程序化 BGM 的切换。
