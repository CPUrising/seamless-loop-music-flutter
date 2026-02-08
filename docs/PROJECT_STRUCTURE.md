# 项目结构概览 (Project Structure)

本文件整理了 `seamless-loop-music-flutter` 项目的目录结构与核心模块说明，方便 cpu 大人随时查阅。

## 📁 根目录结构
- **.agent/**: AI 助手的辅助文件。
- **assets/**: 存放静态资源。
  - **images/**: 图标、封面占位图等。
- **docs/**: 项目文档库（本文件所在地）。
- **lib/**: Flutter 核心源代码目录。
- **test/**: 测试代码目录。
- **lib/native/**: 原生 C 代码（FFI 核心）。

---

## 🏗️ 核心模块 (lib/core)
存放业务逻辑与底层驱动。

### 🔊 音频处理 (lib/core/audio)
- `audio_loop_service.dart`: 负责音频的播放控制与 ClippingAudioSource 无缝循环逻辑。
- `audio_player_state.dart`: 使用 ChangeNotifier 维护全局播放状态。

### 📊 数据管理 (lib/core/data)
- `loop_config.dart`: 定义歌曲循环点的信息结构。

### ⚙️ 核心服务 (lib/core/services)
- `config_manager.dart`: 负责歌曲配置信息的加载与持久化。
- `loop_matcher_service.dart`: 智能匹配服务，负责实现 SAD 算法。
- **读取器 (Readers)**:
  - `wav_reader.dart`: 纯 Dart 实现。
  - `mp3_reader.dart`: 基于 ffmpeg 命令行。
  - `mp3_reader_ffi.dart`: 基于 FFI + minimp3 (高性能)。
  - `ogg_reader_ffi.dart`: 基于 FFI + stb_vorbis (高性能)。
- **FFI 绑定 (Bindings)**:
  - `mp3_decoder_ffi.dart`: MP3 动态库调用。
  - `ogg_decoder_ffi.dart`: OGG 动态库调用。

---

## 🛠️ 原生开发 (lib/native)
用于 FFI 调用的 C 语言项目。
- `mp3_decoder.c`: minimp3 的包装实现。
- `ogg_decoder.c`: stb_vorbis 的包装实现。
- `stb_vorbis.c`: OGG 解码库。
- `CMakeLists.txt`: 动态库的编译配置文件。
- `build/Release/`: 存放生成好的 `.dll` 文件。

---

## 🖥️ 界面展示 (lib/ui)
- **lib/ui/common/**: 通用 UI 组件（按钮、装饰等）。
- **lib/ui/desktop/**: 专门为桌面端优化的布局。
  - `player_ui/desktop_player_page.dart`: 桌面端主界面。
- **lib/ui/mobile/**: 为手机端优化的布局。
  - `player_page/mobile_player_page.dart`: 移动端主界面。

---

## 📝 文档列表
- `DEVELOPMENT_LOG.md`: 详细的开发进度与时间线。
- `MP3_PERFORMANCE_OPTIMIZATION.md`: MP3 优化的技术细节。
- `OGG_SUPPORT.md`: OGG 格式支持的实现文档。
- `QUICKSTART.md`: 快速开发指南。

---
**最后更新**: 2026-02-08  
**整理者**: 莱芙・泽诺 (Lev Zenith)
