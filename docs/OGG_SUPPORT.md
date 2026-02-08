# OGG 格式支持总结

**实现日期**: 2026-02-08  
**实现者**: 莱芙・泽诺 (Lev Zenith)  
**状态**: ✅ 完成

---

## 📋 实现目标

添加 **OGG/Vorbis** 格式支持,使用 **FFI + stb_vorbis** 方案实现高性能解码。

---

## ✅ 完成的工作

### 1. 库文件准备
- ✅ 下载 stb_vorbis.c (单头文件库)
- ✅ 验证库文件完整性

### 2. C 代码实现
- ✅ 创建 `ogg_decoder.c` - OGG 解码器 C 实现
- ✅ 实现核心函数:
  - `ogg_open()` - 打开 OGG 文件
  - `ogg_read_samples()` - 读取采样数据
  - `ogg_get_sample_rate()` - 获取采样率
  - `ogg_get_channels()` - 获取声道数
  - `ogg_get_total_samples()` - 获取总采样数
  - `ogg_close()` - 关闭解码器

### 3. 编译配置
- ✅ 更新 `CMakeLists.txt` - 添加 OGG 解码器编译配置
- ✅ 编译 `ogg_decoder.dll` (Release x64)
- ✅ 验证动态库生成成功

### 4. Dart FFI 绑定
- ✅ 创建 `ogg_decoder_ffi.dart` - FFI 函数绑定
- ✅ 创建 `ogg_reader_ffi.dart` - 高性能 OGG 读取器
- ✅ 更新 `loop_matcher_service.dart` - 集成 OGG 支持

### 5. 文档更新
- ✅ 更新开发日志
- ✅ 更新项目架构文档
- ✅ 创建本总结文档

---

## 🏗️ 技术架构

### 调用流程

```
用户加载 OGG 文件
    ↓
LoopMatcherService._readSamples()
    ↓
检测文件格式 (.ogg / .oga)
    ↓
OggReaderFFI.isFFIAvailable() ?
    ├─ 是 → 使用 FFI + stb_vorbis ⚡
    │   ↓
    │   OggReaderFFI.parseHeader()
    │   OggReaderFFI.readSamples()
    │   ↓
    │   C 库: ogg_open() → ogg_read_samples() → ogg_close()
    │
    └─ 否 → 抛出错误(提示编译 DLL)
```

### 文件结构

```
lib/
├── core/services/
│   ├── ogg_decoder_ffi.dart      # FFI 绑定
│   ├── ogg_reader_ffi.dart       # FFI 读取器
│   └── loop_matcher_service.dart # 智能匹配服务(集成 OGG)
└── native/
    ├── ogg_decoder.c             # C 实现
    ├── stb_vorbis.c              # stb_vorbis 库
    ├── CMakeLists.txt            # 编译配置
    └── build/Release/
        └── ogg_decoder.dll       # 编译产物
```

---

## 🔧 核心实现

### C 代码 (ogg_decoder.c)

```c
// 打开 OGG 文件
OggDecoder* ogg_open(const char* filename);

// 读取采样数据(返回 float 格式,单声道)
int ogg_read_samples(OggDecoder* decoder, int64_t start_sample, 
                     int count, float* buffer);

// 获取文件信息
int ogg_get_sample_rate(OggDecoder* decoder);
int ogg_get_channels(OggDecoder* decoder);
int64_t ogg_get_total_samples(OggDecoder* decoder);

// 关闭解码器
void ogg_close(OggDecoder* decoder);
```

### Dart FFI 绑定 (ogg_decoder_ffi.dart)

```dart
// 动态库加载
static ffi.DynamicLibrary get dylib {
  if (Platform.isWindows) {
    return ffi.DynamicLibrary.open('ogg_decoder.dll');
  }
  // ...
}

// 函数绑定
final oggOpen = dylib
    .lookup<ffi.NativeFunction<OggOpenNative>>('ogg_open')
    .asFunction();
```

### Dart 读取器 (ogg_reader_ffi.dart)

```dart
class OggReaderFFI {
  Future<void> parseHeader() async {
    final pathPtr = _file.path.toNativeUtf8();
    _decoder = _bindings.oggOpen(pathPtr);
    malloc.free(pathPtr);
    
    _sampleRate = _bindings.oggGetSampleRate(_decoder!);
    _channels = _bindings.oggGetChannels(_decoder!);
    _totalSamples = _bindings.oggGetTotalSamples(_decoder!);
  }
  
  Future<Float32List> readSamples(int startSample, int count) async {
    final bufferPtr = malloc.allocate<ffi.Float>(count * ffi.sizeOf<ffi.Float>());
    final samplesRead = _bindings.oggReadSamples(_decoder!, startSample, count, bufferPtr);
    
    final samples = Float32List(samplesRead);
    for (int i = 0; i < samplesRead; i++) {
      samples[i] = bufferPtr[i];
    }
    malloc.free(bufferPtr);
    return samples;
  }
}
```

---

## 📊 预期性能

基于 MP3 FFI 方案的性能数据,预计 OGG FFI 方案性能:

| 操作 | 预期时间 |
|------|---------|
| 读取 1 秒音频 | ~30-40ms |
| 读取 4 秒音频 | ~60-80ms |
| 智能匹配总时间 | ~140-180ms |

**性能特点**:
- ✅ 直接内存操作,无进程启动开销
- ✅ 单声道转换在 C 层完成,效率高
- ✅ 性能与 MP3 FFI 方案相当

---

## 🎯 支持的格式

### 当前支持

| 格式 | 实现方式 | 性能 | 状态 |
|------|---------|------|------|
| WAV | 纯 Dart | ~70ms | ✅ |
| MP3 | FFI + minimp3 | ~155ms | ✅ |
| **OGG** | **FFI + stb_vorbis** | **~160ms** | ✅ |

### 文件扩展名

- `.ogg` - Ogg Vorbis 音频
- `.oga` - Ogg Vorbis 音频(备用扩展名)

---

## 📦 部署说明

### 开发环境

- `ogg_decoder.dll` 已复制到项目根目录
- 代码会自动从多个路径查找 DLL

### 生产环境

需要将 `ogg_decoder.dll` 打包到发布版本中:

1. **Windows**: 将 DLL 放在 exe 同目录
2. **Linux**: 编译 `libogg_decoder.so`
3. **macOS**: 编译 `libogg_decoder.dylib`

### 编译命令

```bash
cd lib/native
cmake -S . -B build -G "Visual Studio 17 2022" -A x64
cmake --build build --config Release
```

---

## 🐛 已知限制

1. **平台支持**: 当前仅编译了 Windows 版本(x64)
2. **DLL 路径**: 需要确保 DLL 在正确位置
3. **无回退机制**: 如果 FFI 失败,会直接报错(不像 MP3 有 ffmpeg 回退)

---

## 🔍 技术细节

### stb_vorbis 特点

- **单头文件库**: 无需额外依赖
- **轻量级**: 比 libvorbis 更小
- **高性能**: 针对速度优化
- **开源**: MIT 许可证

### 与 MP3 方案的对比

| 特性 | MP3 (minimp3) | OGG (stb_vorbis) |
|------|--------------|-----------------|
| 库大小 | ~77KB | ~250KB |
| 解码速度 | 快 | 快 |
| 音质 | 有损 | 有损 |
| 许可证 | CC0 | MIT |
| 回退方案 | ffmpeg | 无 |

---

## 📚 参考资料

- [stb_vorbis GitHub](https://github.com/nothings/stb/blob/master/stb_vorbis.c)
- [Ogg Vorbis 官网](https://xiph.org/vorbis/)
- [Dart FFI 文档](https://dart.dev/guides/libraries/c-interop)

---

## 🎉 总结

通过使用 FFI + stb_vorbis 方案:

✅ **添加 OGG 支持**(无需 ffmpeg)  
✅ **高性能解码**(预计 ~160ms)  
✅ **统一架构**(与 MP3 FFI 方案一致)  
✅ **跨平台基础**(为 Linux/macOS 打下基础)  

**当前支持的格式**:
- ✅ WAV (纯 Dart)
- ✅ MP3 (FFI + minimp3)
- ✅ OGG (FFI + stb_vorbis)

**下一步建议**:
- 测试 OGG 文件的实际性能
- 编译 Linux/macOS 版本的动态库
- 考虑添加 FLAC 支持

---

**完成时间**: 2026-02-08 08:40  
**总耗时**: 约 15 分钟  
**状态**: ✅ 完成并集成
