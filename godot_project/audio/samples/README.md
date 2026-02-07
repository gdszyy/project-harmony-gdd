# External Instrument Samples — Project Harmony

本目录用于存放外部乐器采样文件。当采样文件存在时，`NoteSynthesizer` 会优先使用外部采样替代程序化合成，以获得更真实的音色表现。

## 目录结构

```
audio/samples/
├── default/        # 默认合成器音色 (基础正弦波)
├── plucked/        # 弹拨系 (古筝、琵琶、吉他)
├── bowed/          # 拉弦系 (二胡、大提琴、小提琴)
├── wind/           # 吹奏系 (笛子、长笛、单簧管)
├── percussive/     # 打击系 (钢琴、马林巴、木琴)
└── README.md
```

## 文件命名规范

每个采样文件应以 **音符名+八度数** 命名，使用 `.wav` 格式（16-bit, 44100Hz, 单声道）。

| 音符 | 文件名 | 频率 (Hz) |
|------|--------|-----------|
| C4   | `C4.wav`  | 261.63 |
| C#4  | `Cs4.wav` | 277.18 |
| D4   | `D4.wav`  | 293.66 |
| D#4  | `Ds4.wav` | 311.13 |
| E4   | `E4.wav`  | 329.63 |
| F4   | `F4.wav`  | 349.23 |
| F#4  | `Fs4.wav` | 369.99 |
| G4   | `G4.wav`  | 392.00 |
| G#4  | `Gs4.wav` | 415.30 |
| A4   | `A4.wav`  | 440.00 |
| A#4  | `As4.wav` | 466.16 |
| B4   | `B4.wav`  | 493.88 |

其他八度以此类推（如 `C3.wav`, `A5.wav` 等）。

## 技术要求

采样文件应满足以下规格，以确保与 `NoteSynthesizer` 的兼容性和一致性。

| 参数 | 要求 |
|------|------|
| 格式 | WAV (PCM) |
| 位深 | 16-bit |
| 采样率 | 44100 Hz |
| 声道 | 单声道 (Mono) |
| 时长 | 0.5 ~ 2.0 秒 |
| 音量 | 归一化至 -3dB 峰值 |

## 推荐采样来源

以下是经过验证的免费/开源乐器采样资源，可直接下载并转换为上述格式使用。

### University of Iowa Musical Instrument Samples

该资源库由爱荷华大学电子音乐工作室维护，提供专业录制的单音符采样，涵盖钢琴、长笛、大提琴等多种乐器。所有采样均免费使用，无任何许可限制。

- **网址**: https://theremin.music.uiowa.edu/mis.html
- **许可**: 免费使用，无限制
- **推荐乐器**: Piano (打击系), Flute (吹奏系), Cello (拉弦系), Guitar (弹拨系)
- **原始格式**: AIFF (需转换为 WAV)

### Freesound.org

Freesound 是一个社区驱动的音效共享平台，包含大量 CC0 许可的乐器采样。其中 tarane468 用户提供的二胡单音符采样（CC0 许可）特别适合拉弦系音色。

- **网址**: https://freesound.org
- **许可**: CC0 / CC-BY（视具体采样而定）
- **推荐搜索**: "erhu single note", "guzheng pluck", "dizi flute note"

### Philharmonia Orchestra Sound Samples

伦敦爱乐乐团提供的免费管弦乐器采样，涵盖弦乐、木管、铜管和打击乐器。每种乐器提供多种演奏技法和力度的采样。

- **网址**: https://philharmonia.co.uk/resources/sound-samples/
- **许可**: 免费使用（不可单独出售采样本身）

## 格式转换

使用 `ffmpeg` 将下载的采样转换为所需格式：

```bash
# AIFF 转 WAV (单声道, 16-bit, 44100Hz)
ffmpeg -i input.aiff -ac 1 -ar 44100 -sample_fmt s16 output.wav

# MP3/OGG 转 WAV
ffmpeg -i input.mp3 -ac 1 -ar 44100 -sample_fmt s16 output.wav

# 批量转换目录下所有 AIFF 文件
for f in *.aiff; do
  ffmpeg -i "$f" -ac 1 -ar 44100 -sample_fmt s16 "${f%.aiff}.wav"
done
```

## 加载机制

`NoteSynthesizer` 在生成音符时会按以下优先级查找音源：

1. **内存缓存** — 已生成/加载的音效直接复用
2. **外部采样文件** — 检查 `res://audio/samples/{timbre_type}/{note_name}.wav`
3. **程序化合成** — 使用 ADSR 包络和泛音结构实时合成

当外部采样不存在时，系统会自动回退到程序化合成，确保游戏始终可运行。
