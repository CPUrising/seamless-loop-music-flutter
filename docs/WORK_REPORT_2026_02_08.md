# 工作日志 - 2026.02.08

## Seamless Loop Music Player - Rust 音频引擎集成与调试

### 1. 今日目标
集成 Rust 音频解码库 (`symphonia`)，替换原有的不稳定 FFI 实现，以支持 OGG/FLAC 格式在 Windows 平台上的高保真无缝循环播放。

### 2. 主要进展

#### A. 架构重构 (Rust + Flutter Rust Bridge)
*   **废弃旧方案**：彻底移除了基于 `miniaudio` 的 C++ FFI 实现，解决了编译复杂和内存泄露隐患。
*   **新方案落地**：成功集成了 `flutter_rust_bridge` 和 `symphonia` (Rust)，实现了音频信息的读取 (`get_audio_info`) 和 PCM 数据解码 (`read_audio_samples`)。

#### B. 核心功能实现
*   **无缝循环 (Looping)**：
    *   放弃了 `just_audio` 自带的 `LoopingAudioSource` (在 Windows 上不稳定导致 Crash)。
    *   **创新方案**：采用 `ClippingAudioSource` 截取循环片段 + `LoopMode.one` 单曲循环的组合，实现了极其稳定的无缝循环体验。
*   **转码缓存**：
    *   实现了 `DecodedAudioSource` 缓存机制，转码后的 WAV 文件会被复用，大幅减少了重复加载时的等待时间。
*   **立体声支持 (尝试修复，未验证)**：
    *   修改 Rust `process_buffer` 逻辑，从单声道下混改为 **Interleaved Stereo (L, R, L, R...)** 输出。
    *   **当前状态**：由于 App 启动崩溃 (见下文)，该修复未能在真机验证。**音质依然糟糕**。

#### C. Bug 修复
*   **进度条崩溃**：修复了 `Slider` 在音频时长未加载时因除以零或 NaN 导致的 UI 崩溃。
*   **循环点重置**：修复了切换歌曲或手动调整循环点时，配置被意外重置回默认值的问题。
*   **播放速度异常**：通过在 Dart 端动态检测解码数据长度，自动适配 Mono/Stereo Header，临时解决了因声道不匹配导致的"花栗鼠音效"(2倍速) 问题。

### 3. 遗留的严重问题 (Critical Blockers)

#### **App 启动崩溃 (Content Hash Mismatch)**
*   **现象**：`Unhandled Exception: Bad state: Content hash on Dart side (1211921517) is different from Rust side (-67028392)`
*   **原因**：手动修改 Rust 代码并重新编译后，Dart 端的生成代码 (`frb_generated.dart`) 与 Rust 二进制 (`rust.dll`) 的版本校验哈希不一致。
*   **当前状态**：
    *   尽管尝试了 `flutter clean`、`cargo clean`、重新生成代码 (`flutter_rust_bridge_codegen generate`)，该问题依然阻塞了 App 启动。
    *   **应用程序完全无法打开**，所有功能（包括立体声音质验证）均无法测试。
*   **下一步计划**：
    *   彻底排查 `flutter_rust_bridge` 的版本一致性和构建流程。
    *   必要时手动屏蔽 Hash 检查或回退到稳定版本以恢复开发。

### 4. 总结
今日完成了 Rust 引擎的核心逻辑开发和循环机制的重构，但最终的集成卡在了构建系统的 Hash 校验上。**目前应用程序无法启动，音质问题尚未解决**。明日首要任务是打通构建流程，恢复基本的运行能力。
