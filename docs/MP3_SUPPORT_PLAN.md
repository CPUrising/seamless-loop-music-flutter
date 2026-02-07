# MP3 支持实现计划

## 当前状态
- ✅ WAV 文件完全支持（8/16/24/32-bit PCM）
- ✅ 完整的 SAD 匹配算法
- ⏳ MP3 支持待实现

## 实现方案

### 方案 1：FFI + minimp3（推荐）

#### 优点
- 轻量级（单头文件）
- 性能好
- 跨平台

#### 实现步骤

1. **下载 minimp3**
   ```bash
   # 从 GitHub 下载
   https://github.com/lieff/minimp3
   # 需要的文件：
   - minimp3.h
   - minimp3_ex.h
   ```

2. **创建 C++ wrapper**
   - 文件：`lib/native/mp3_decoder.c`（已创建）
   - 功能：
     - mp3_open(): 打开 MP3 文件
     - mp3_read_samples(): 读取采样数据
     - mp3_get_sample_rate(): 获取采样率
     - mp3_close(): 关闭解码器

3. **配置 CMakeLists.txt**
   ```cmake
   # Windows
   cmake_minimum_required(VERSION 3.14)
   project(mp3_decoder)
   
   add_library(mp3_decoder SHARED
     mp3_decoder.c
   )
   
   target_include_directories(mp3_decoder PRIVATE
     ${CMAKE_CURRENT_SOURCE_DIR}
   )
   ```

4. **编译动态库**
   ```bash
   # Windows
   mkdir build && cd build
   cmake ..
   cmake --build . --config Release
   # 生成 mp3_decoder.dll
   ```

5. **编写 Dart FFI 绑定**
   ```dart
   // lib/core/services/mp3_decoder_ffi.dart
   import 'dart:ffi';
   import 'dart:io';
   
   final DynamicLibrary _dylib = Platform.isWindows
       ? DynamicLibrary.open('mp3_decoder.dll')
       : DynamicLibrary.open('libmp3_decoder.so');
   
   typedef Mp3OpenNative = Pointer<Void> Function(Pointer<Utf8>);
   typedef Mp3Open = Pointer<Void> Function(Pointer<Utf8>);
   
   final Mp3Open mp3Open = _dylib
       .lookup<NativeFunction<Mp3OpenNative>>('mp3_open')
       .asFunction();
   ```

6. **集成到 Mp3Reader**
   ```dart
   class Mp3Reader {
     late Pointer<Void> _decoder;
     
     Future<void> open(String filePath) async {
       final pathPtr = filePath.toNativeUtf8();
       _decoder = mp3Open(pathPtr);
       malloc.free(pathPtr);
     }
   }
   ```

### 方案 2：使用 ffmpeg（重量级）

#### 优点
- 支持所有格式
- 功能强大

#### 缺点
- 体积大（几十 MB）
- 配置复杂

### 方案 3：提示用户转换为 WAV（临时）

#### 优点
- 实现简单
- 立即可用

#### 缺点
- 用户体验差

## 当前采用方案

**临时方案 3 + 计划方案 1**

1. 当前：检测到 MP3 文件时，提示用户转换为 WAV
2. 未来：实现 FFI + minimp3 支持

## 用户提示文案

```
不支持的文件格式：MP3

当前版本仅支持 WAV 文件（PCM 格式）。

建议：
1. 使用 Audacity 或 FFmpeg 将 MP3 转换为 WAV
2. 命令行转换：
   ffmpeg -i input.mp3 output.wav

未来版本将支持 MP3 直接读取。
```

## 时间估算

- 方案 1 实现：2-3 小时
  - 下载配置：30 分钟
  - C++ wrapper：1 小时
  - Dart FFI 绑定：1 小时
  - 测试调试：30 分钟

- 方案 2 实现：4-6 小时
  - 下载配置 ffmpeg：1 小时
  - 集成调试：3-5 小时

## 参考资料

- minimp3: https://github.com/lieff/minimp3
- Dart FFI: https://dart.dev/guides/libraries/c-interop
- FFmpeg: https://ffmpeg.org/
