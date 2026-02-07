# Audio Resources — Project Harmony

本目录存放游戏的所有音频资源文件。

## 目录结构

```
audio/
├── bgm/                    # 背景音乐
│   ├── menu_ambient.ogg    # 主菜单环境音
│   ├── battle_techno_120.ogg  # 战斗 BGM (120 BPM)
│   ├── battle_techno_130.ogg  # 高强度战斗 BGM (130 BPM)
│   ├── battle_techno_140.ogg  # Boss 战 BGM (140 BPM)
│   └── game_over_drone.ogg    # 游戏结束
├── sfx/
│   ├── enemy/              # 敌人音效 (程序化生成，无需手动放置)
│   ├── player/             # 玩家法术音效 (程序化生成)
│   └── ui/                 # UI 音效 (程序化生成)
├── samples/                # 外部乐器采样 (可选，用于替代程序化合成)
│   ├── default/            # 默认合成器音色
│   ├── plucked/            # 弹拨系 (古筝、琵琶、吉他)
│   ├── bowed/              # 拉弦系 (二胡、大提琴、小提琴)
│   ├── wind/               # 吹奏系 (笛子、长笛、单簧管)
│   ├── percussive/         # 打击系 (钢琴、马林巴、木琴)
│   └── README.md           # 采样规范和推荐来源
└── README.md
```

## BGM 制作规范

### 推荐风格
- **Minimal Techno** / **Glitch Techno**
- 4/4 拍，稳定清晰的 Kick (底鼓)
- BPM 范围：120 ~ 140

### 技术要求
1. **格式**：OGG Vorbis (`.ogg`)，推荐比特率 192kbps
2. **BPM 精确**：BGM 的 BPM 必须与文件名标注的 BPM 完全一致
3. **Kick 频率**：底鼓能量应集中在 **20-200Hz** 区间，以便频谱分析器准确提取节拍信号
4. **无缝循环**：BGM 必须支持无缝循环播放
5. **动态范围**：保持适当的动态范围，避免过度压缩

### 避免的类型
- 自由爵士 (节拍难以预测)
- 变速古典乐 (BPM 不稳定)
- Drum & Bass (节奏过于细碎)

## 音效说明

### 敌人音效与 UI 音效

敌人音效和 UI 音效均由 `AudioManager` 在运行时**程序化生成**（使用 `AudioStreamWAV`），
无需手动制作音效文件。如需替换为手工制作的音效，可将 `.wav` 或 `.ogg` 文件放入对应目录，
并修改 `audio_manager.gd` 中的加载逻辑。

### 音符/法术音效 (音色系统)

音符音效由 `NoteSynthesizer`（`scripts/systems/note_synthesizer.gd`）负责生成，
支持四大音色系别（弹拨/拉弦/吹奏/打击）的差异化音效。系统采用混合策略：

1. **程序化合成（默认）**：使用 ADSR 包络、泛音结构和波形合成模拟乐器音色，零外部依赖
2. **外部采样加载（可选）**：将真实乐器采样放入 `audio/samples/` 对应目录，系统会自动优先使用

详细的采样规范和推荐来源请参阅 `audio/samples/README.md`。
