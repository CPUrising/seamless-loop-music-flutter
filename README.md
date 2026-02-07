# 🎵 Seamless Loop Music Player (Flutter)

一个跨平台的无缝循环音乐播放器，支持 Windows、Android、iOS 和 macOS。

![Flutter](https://img.shields.io/badge/Flutter-3.10.8-blue)
![Dart](https://img.shields.io/badge/Dart-3.10.8-blue)
![License](https://img.shields.io/badge/License-MIT-green)

---

## ✨ 特性

- 🎯 **精准循环**: 支持采样级精度的 A-B 循环
- 🤖 **智能匹配**: 基于 SAD 算法自动寻找最佳循环点
- 📁 **多格式支持**: WAV (PCM) 和 MP3 (需要 ffmpeg)
- 💾 **配置持久化**: 自动保存和加载循环点配置
- 🖥️ **桌面优化**: 完整的桌面端 UI，支持文件管理和编辑
- 📱 **移动端支持**: 基础的移动端播放功能

---

## 🚀 快速开始

### 环境要求

- Flutter SDK 3.10.8+
- Dart SDK 3.10.8+
- (可选) ffmpeg - 用于 MP3 支持

### 安装

```bash
# 克隆仓库
git clone <repository-url>
cd seamless-loop-music-flutter

# 安装依赖
flutter pub get

# 运行应用
flutter run
```

### 安装 ffmpeg (可选，用于 MP3 支持)

#### Windows
```powershell
# 下载 ffmpeg
https://www.gyan.dev/ffmpeg/builds/

# 解压并添加到 PATH
setx PATH "%PATH%;C:\ffmpeg\bin"
```

#### Linux
```bash
sudo apt install ffmpeg
```

#### macOS
```bash
brew install ffmpeg
```

---

## 📖 使用指南

### 基本使用

1. **打开音频文件**
   - 点击顶部工具栏的"打开文件"按钮
   - 选择 WAV 或 MP3 文件

2. **设置循环点**
   - 在右侧编辑器中输入起始和结束采样数
   - 或者点击"智能匹配"自动寻找最佳循环点

3. **应用并试听**
   - 点击"应用并试听"按钮
   - 音频将从循环起点开始无缝循环播放

### 智能匹配

智能匹配功能使用 SAD (Sum of Absolute Differences) 算法：

1. 提取循环终点之前 1 秒的音频作为"指纹"
2. 在循环起点附近 ±2 秒范围内搜索
3. 找到与终点最匹配的位置
4. 自动调整循环起点

**注意**: 
- WAV 文件匹配速度快 (~70ms)
- MP3 文件需要 ffmpeg，速度较慢 (~770ms)

---

## 🏗️ 项目结构

```
lib/
├── core/
│   ├── audio/              # 音频播放服务
│   ├── data/               # 数据模型
│   └── services/           # 业务逻辑服务
├── ui/
│   ├── desktop/            # 桌面端 UI
│   └── mobile/             # 移动端 UI
└── main.dart               # 应用入口

docs/
├── DEVELOPMENT_LOG.md      # 开发日志
└── MP3_SUPPORT_PLAN.md     # MP3 支持计划
```

---

## 🔧 技术栈

### 核心依赖

- **just_audio** (0.10.5) - 音频播放
- **audio_session** (0.2.2) - 音频会话管理
- **provider** (6.1.5) - 状态管理
- **file_picker** (10.3.10) - 文件选择
- **path_provider** (2.1.5) - 路径管理
- **ffi** (2.1.5) - 原生代码互操作（备用）

### 算法实现

- **循环播放**: ClippingAudioSource + LoopingAudioSource
- **智能匹配**: SAD (Sum of Absolute Differences)
- **音频读取**: 
  - WAV: 纯 Dart 实现
  - MP3: ffmpeg 外部进程调用

---

## 📊 性能

### 智能匹配性能 (44100Hz, 1秒模板, 4秒搜索区)

| 格式 | 读取时间 | 匹配时间 | 总时间 |
|------|---------|---------|--------|
| WAV  | ~20ms   | ~50ms   | ~70ms  |
| MP3  | ~720ms  | ~50ms   | ~770ms |

**注意**: MP3 性能较低是因为使用外部 ffmpeg 进程。未来版本将迁移到 FFI + minimp3，预计性能提升 6.5 倍。

---

## 🗺️ 路线图

### ✅ 已完成

- [x] 桌面端完整 UI
- [x] WAV 文件支持
- [x] MP3 文件支持（基于 ffmpeg）
- [x] 智能循环点匹配
- [x] 配置持久化
- [x] 无缝循环播放

### 🚧 进行中

- [ ] 移动端 UI 完善
- [ ] 性能优化（FFI + minimp3）
- [ ] 波形可视化

### 📅 计划中

- [ ] PyMusicLooper 集成
- [ ] FFT 互相关算法
- [ ] 金字塔搜索算法
- [ ] 多循环点管理
- [ ] 云同步功能

---

## 🐛 已知问题

1. **MP3 性能**: 使用 ffmpeg 外部进程，延迟较高
2. **Flutter Analyze 警告**: 33 个 deprecated_member_use 警告
3. **移动端 UI**: 功能不完整

详见 [开发日志](docs/DEVELOPMENT_LOG.md)

---

## 📚 文档

- [开发日志](docs/DEVELOPMENT_LOG.md) - 详细的开发过程记录
- [MP3 支持计划](docs/MP3_SUPPORT_PLAN.md) - MP3 支持的实现方案

---

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

### 开发环境设置

```bash
# 克隆仓库
git clone <repository-url>
cd seamless-loop-music-flutter

# 安装依赖
flutter pub get

# 运行测试
flutter test

# 代码检查
flutter analyze
```

---

## 📄 许可证

本项目继承自 C# WPF 版本的许可证。

---

## 🙏 致谢

- **C# WPF 版本**: 本项目的原始实现
- **just_audio**: 优秀的 Flutter 音频播放库
- **minimp3**: 轻量级的 MP3 解码器
- **ffmpeg**: 强大的多媒体处理工具

---

## 📞 联系方式

如有问题或建议，请提交 Issue。

---

**最后更新**: 2026-02-07  
**版本**: 1.0.0
