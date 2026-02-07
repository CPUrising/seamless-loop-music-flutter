# 技术文档 - Seamless Loop Music Player

**版本**: 1.0.0  
**最后更新**: 2026-02-07

---

## 📐 架构设计

### 整体架构

```
┌─────────────────────────────────────────────────┐
│                   UI Layer                      │
│  ┌──────────────┐         ┌──────────────┐     │
│  │ Desktop UI   │         │  Mobile UI   │     │
│  └──────┬───────┘         └──────┬───────┘     │
│         │                        │             │
└─────────┼────────────────────────┼─────────────┘
          │                        │
┌─────────┼────────────────────────┼─────────────┐
│         │   State Management     │             │
│         └────────┬───────────────┘             │
│                  │ Provider                    │
│         ┌────────▼───────────┐                 │
│         │ AudioPlayerState   │                 │
│         └────────┬───────────┘                 │
└──────────────────┼─────────────────────────────┘
                   │
┌──────────────────┼─────────────────────────────┐
│                  │   Service Layer             │
│  ┌───────────────▼────────────┐                │
│  │   AudioLoopService         │                │
│  │   (just_audio wrapper)     │                │
│  └───────────────┬────────────┘                │
│                  │                             │
│  ┌───────────────▼────────────┐                │
│  │   ConfigManager            │                │
│  │   (JSON persistence)       │                │
│  └────────────────────────────┘                │
│                                                 │
│  ┌─────────────────────────────┐               │
│  │   LoopMatcherService        │               │
│  │   (SAD algorithm)           │               │
│  └───────────┬─────────────────┘               │
│              │                                  │
│  ┌───────────▼──────┐  ┌──────────────┐        │
│  │   WavReader      │  │  Mp3Reader   │        │
│  │   (Pure Dart)    │  │  (ffmpeg)    │        │
│  └──────────────────┘  └──────────────┘        │
└─────────────────────────────────────────────────┘
                   │
┌──────────────────┼─────────────────────────────┐
│                  │   Data Layer                │
│  ┌───────────────▼────────────┐                │
│  │   LoopConfig               │                │
│  │   LoopPoint                │                │
│  └────────────────────────────┘                │
└─────────────────────────────────────────────────┘
```

---

## 🔧 核心组件详解

### 1. AudioLoopService

**职责**: 封装 just_audio，提供循环播放功能

**关键方法**:
```dart
class AudioLoopService {
  // 加载音频文件并设置循环点
  Future<void> loadAudio(String filePath, LoopPoint loop, int sampleRate);
  
  // 播放/暂停/停止
  void play();
  void pause();
  void stop();
  
  // 跳转到指定位置
  void seek(Duration position);
}
```

**实现细节**:
```dart
AudioSource _createLoopingSource(String filePath, LoopPoint loop, int sampleRate) {
  final startDuration = loop.getStartDuration(sampleRate);
  final endDuration = loop.getEndDuration(sampleRate);

  // 使用 ClippingAudioSource 定义循环范围
  final clippedSource = ClippingAudioSource(
    child: AudioSource.file(filePath),
    start: startDuration,
    end: endDuration,
  );

  // 使用 LoopingAudioSource 实现无限循环
  return LoopingAudioSource(child: clippedSource);
}
```

---

### 2. LoopMatcherService

**职责**: 实现智能循环点匹配算法

**核心算法**: SAD (Sum of Absolute Differences)

**工作流程**:
```
1. 提取 End 点之前 1 秒的音频（Template）
   ↓
2. 在 Start 点附近 ±2 秒范围内搜索（Search Buffer）
   ↓
3. 滑动窗口匹配（SAD 算法）
   ↓
4. 找到最小差异位置
   ↓
5. 返回最佳循环点
```

**关键代码**:
```dart
(int, double) _sadMatch(Float32List template, Float32List searchBuffer) {
  double minDiff = double.maxFinite;
  int bestMatchOffset = -1;

  // 滑动窗口匹配
  for (int i = 0; i <= searchBuffer.length - template.length; i++) {
    double diff = 0;
    
    // 优化：步长为 4
    for (int t = 0; t < template.length; t += 4) {
      final valA = template[t];
      final valB = searchBuffer[i + t];
      diff += (valA - valB).abs();
      
      // 提前退出优化
      if (diff > minDiff) break;
    }

    if (diff < minDiff) {
      minDiff = diff;
      bestMatchOffset = i;
    }
  }

  return (bestMatchOffset, minDiff);
}
```

**复杂度分析**:
- 时间复杂度: O(N × M / 4)
  - N: 搜索区长度（~176400 采样）
  - M: 模板长度（~44100 采样）
  - 步长优化: 除以 4
- 空间复杂度: O(N + M)

---

### 3. WavReader

**职责**: 读取 WAV 文件的 PCM 数据

**支持格式**:
- 8-bit PCM (unsigned)
- 16-bit PCM (signed)
- 24-bit PCM (signed)
- 32-bit float

**实现原理**:
```dart
class WavReader {
  Future<void> parseHeader() async {
    // 1. 检查 RIFF 标识
    // 2. 检查 WAVE 标识
    // 3. 查找 fmt chunk
    //    - 解析音频格式（必须是 PCM）
    //    - 解析声道数
    //    - 解析采样率
    //    - 解析位深度
    // 4. 查找 data chunk
    //    - 记录数据偏移
    //    - 记录数据大小
  }
  
  Future<Float32List> readSamples(int startSample, int count) async {
    // 1. 计算字节偏移
    final bytesPerSample = _channels * (_bitsPerSample / 8);
    final startByte = _dataOffset + startSample * bytesPerSample;
    
    // 2. 读取原始字节
    final bytes = await file.read(byteCount);
    
    // 3. 转换为 Float32
    for (int i = 0; i < count; i++) {
      if (_bitsPerSample == 16) {
        final value = byteData.getInt16(offset, Endian.little);
        samples[i] = value / 32768.0;  // 归一化
      }
      // ... 其他位深度
    }
  }
}
```

**性能**:
- 读取 1 秒音频（44100 采样）: ~5ms
- 读取 4 秒音频（176400 采样）: ~15ms

---

### 4. Mp3Reader

**职责**: 读取 MP3 文件的 PCM 数据（使用 ffmpeg）

**依赖**: 系统安装 ffmpeg

**实现原理**:
```dart
class Mp3Reader {
  Future<void> parseHeader() async {
    // 使用 ffprobe 获取文件信息
    final result = await Process.run('ffprobe', [
      '-v', 'error',
      '-show_entries', 'stream=sample_rate,channels,duration',
      '-of', 'default=noprint_wrappers=1',
      filePath,
    ]);
    
    // 解析输出
    // sample_rate=44100
    // channels=2
    // duration=180.0
  }
  
  Future<Float32List> readSamples(int startSample, int count) async {
    final startTime = startSample / _sampleRate;
    final duration = count / _sampleRate;
    
    // 使用 ffmpeg 解码
    final result = await Process.run('ffmpeg', [
      '-ss', startTime.toString(),  // 跳转到指定时间
      '-t', duration.toString(),    // 读取指定时长
      '-i', filePath,
      '-f', 'f32le',                // 输出格式：float32 LE
      '-ac', '1',                   // 转换为单声道
      '-ar', _sampleRate.toString(),
      'pipe:1',                     // 输出到 stdout
    ]);
    
    // 转换字节为 Float32List
    final bytes = result.stdout as List<int>;
    final samples = Float32List(bytes.length / 4);
    for (int i = 0; i < samples.length; i++) {
      samples[i] = byteData.getFloat32(i * 4, Endian.little);
    }
  }
}
```

**性能**:
- 读取 1 秒音频（44100 采样）: ~240ms
- 读取 4 秒音频（176400 采样）: ~480ms

**性能瓶颈**:
- ffmpeg 进程启动: ~100-300ms
- 音频解码: ~10-50ms
- 数据传输: ~10-20ms

---

### 5. ConfigManager

**职责**: 管理循环点配置的持久化

**存储格式**: JSON

**文件位置**: `<AppDocuments>/loop_config.json`

**数据结构**:
```json
{
  "configs": [
    {
      "filename": "bgm.mp3",
      "filePath": "D:/Music/bgm.mp3",
      "title": "Background Music",
      "artist": "Unknown",
      "sampleRate": 44100,
      "totalSamples": 7938000,
      "loops": [
        {
          "startSample": 2158092,
          "endSample": 5819712,
          "score": 0.98,
          "isPrimary": true
        }
      ]
    }
  ]
}
```

**关键方法**:
```dart
class ConfigManager {
  // 加载配置库
  Future<void> loadLibrary();
  
  // 保存配置库
  Future<void> saveLibrary();
  
  // 查找配置
  Future<LoopConfig?> findConfig(String filename);
  
  // 添加/更新配置
  Future<void> addOrUpdateConfig(LoopConfig config);
}
```

---

## 🎨 UI 设计

### 桌面端布局

```
┌─────────────────────────────────────────────────┐
│  [Seamless Loop Music]  [打开文件] [智能匹配]   │
├──────────────┬──────────────────────────────────┤
│              │  文件信息                        │
│  文件列表    │  ─────────────────────────────   │
│              │  文件名: bgm.mp3                 │
│  ┌─────────┐│  采样率: 44100 Hz                │
│  │ bgm.mp3 ││  总采样数: 7938000               │
│  └─────────┘│                                  │
│  ┌─────────┐│  循环点编辑器                    │
│  │song.wav ││  ─────────────────────────────   │
│  └─────────┘│  Loop Start: [2158092]           │
│             │  Loop End:   [5819712]           │
│             │  [应用并试听]                    │
│             │                                  │
│             │  播放控制                        │
│             │  ─────────────────────────────   │
│             │  [═══════════════════════]       │
│             │  [◀◀] [▶/❚❚] [▶▶]              │
│             │  音量: [═══════════]             │
└─────────────┴──────────────────────────────────┘
```

### 移动端布局

```
┌─────────────────────┐
│  Seamless Loop      │
│  Music Player       │
├─────────────────────┤
│                     │
│  [  播放封面  ]     │
│                     │
├─────────────────────┤
│  歌曲名称           │
│  艺术家             │
├─────────────────────┤
│  [═══════════]      │
│  00:48 / 03:00      │
├─────────────────────┤
│  [◀◀] [▶] [▶▶]    │
├─────────────────────┤
│  Loop: 2158092      │
│        → 5819712    │
└─────────────────────┘
```

---

## 📊 数据流

### 文件加载流程

```
用户点击"打开文件"
  ↓
FilePicker.pickFiles()
  ↓
获取文件路径和文件名
  ↓
ConfigManager.findConfig(filename)
  ↓
配置存在？
  ├─ 是 → 加载现有配置
  └─ 否 → 创建默认配置
           ↓
           ConfigManager.addOrUpdateConfig()
  ↓
AudioPlayerState.loadAndPlay(filePath, config)
  ↓
AudioLoopService.loadAudio()
  ↓
创建 LoopingAudioSource
  ↓
播放音频
```

### 智能匹配流程

```
用户点击"智能匹配"
  ↓
获取当前配置和循环点
  ↓
显示加载对话框
  ↓
LoopMatcherService.findBestLoopPoints()
  ├─ 读取 End 点指纹（1 秒）
  │   ↓
  │   WavReader/Mp3Reader.readSamples()
  ├─ 读取 Start 点搜索区（4 秒）
  │   ↓
  │   WavReader/Mp3Reader.readSamples()
  └─ SAD 匹配算法
      ↓
      返回最佳循环点和评分
  ↓
更新输入框
  ↓
创建新配置
  ↓
ConfigManager.addOrUpdateConfig()
  ↓
AudioPlayerState.loadAndPlay()
  ↓
显示成功提示
```

---

## 🔐 错误处理

### 错误类型

1. **文件不存在**
```dart
if (!await File(filePath).exists()) {
  throw Exception('文件不存在: $filePath');
}
```

2. **格式不支持**
```dart
if (ext != 'wav' && ext != 'mp3') {
  throw UnsupportedError('不支持的文件格式: $ext');
}
```

3. **ffmpeg 未安装**
```dart
if (!await Mp3Reader.isFFmpegAvailable()) {
  throw UnsupportedError('MP3 解码需要 ffmpeg');
}
```

4. **循环点无效**
```dart
if (startSample < 0 || endSample > totalSamples) {
  throw RangeError('循环点超出范围');
}
```

### 错误提示

所有错误都通过 SnackBar 显示给用户：

```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('错误信息'),
    backgroundColor: Colors.red,
    duration: const Duration(seconds: 5),
  ),
);
```

---

## 🧪 测试策略

### 单元测试

```dart
// 测试 LoopConfig 序列化
test('LoopConfig toJson/fromJson', () {
  final config = LoopConfig(...);
  final json = config.toJson();
  final decoded = LoopConfig.fromJson(json);
  expect(decoded.filename, config.filename);
});

// 测试 SAD 算法
test('SAD match algorithm', () {
  final template = Float32List.fromList([1, 2, 3]);
  final buffer = Float32List.fromList([0, 1, 2, 3, 4]);
  final (offset, diff) = _sadMatch(template, buffer);
  expect(offset, 1);
});
```

### 集成测试

```dart
// 测试完整的加载流程
testWidgets('Load and play audio', (tester) async {
  await tester.pumpWidget(MyApp());
  await tester.tap(find.text('打开文件'));
  await tester.pumpAndSettle();
  // ... 验证播放状态
});
```

---

## 📈 性能优化建议

### 1. MP3 读取优化

**当前**: ffmpeg 外部进程（~770ms）

**优化方案**: FFI + minimp3（预计 ~110ms）

**实现步骤**:
1. 编译 minimp3 动态库
2. 编写 Dart FFI 绑定
3. 替换 Mp3Reader 实现

### 2. 缓存优化

**问题**: 每次智能匹配都重新读取音频

**优化方案**: 缓存已读取的音频数据

```dart
class AudioCache {
  final Map<String, Float32List> _cache = {};
  
  Future<Float32List> getOrRead(String key, Future<Float32List> Function() reader) async {
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }
    final data = await reader();
    _cache[key] = data;
    return data;
  }
}
```

### 3. 算法优化

**当前**: SAD 算法 O(N × M)

**优化方案**: FFT 互相关 O(N log N)

```dart
// 使用 FFT 加速互相关计算
Float32List fftCrossCorrelation(Float32List a, Float32List b) {
  // 1. FFT(a)
  // 2. FFT(b)
  // 3. 逐点相乘
  // 4. IFFT
}
```

---

## 🔒 安全考虑

### 1. 文件路径验证

```dart
bool isValidPath(String path) {
  // 防止路径遍历攻击
  if (path.contains('..')) return false;
  
  // 检查文件扩展名
  final ext = path.split('.').last.toLowerCase();
  if (!['wav', 'mp3'].contains(ext)) return false;
  
  return true;
}
```

### 2. 配置文件验证

```dart
LoopConfig validateConfig(Map<String, dynamic> json) {
  // 验证必需字段
  if (!json.containsKey('filename')) {
    throw FormatException('缺少 filename 字段');
  }
  
  // 验证数值范围
  final sampleRate = json['sampleRate'] as int;
  if (sampleRate < 8000 || sampleRate > 192000) {
    throw RangeError('采样率超出范围');
  }
  
  return LoopConfig.fromJson(json);
}
```

---

## 📚 参考资料

### 算法
- [Sum of Absolute Differences (SAD)](https://en.wikipedia.org/wiki/Sum_of_absolute_differences)
- [Cross-Correlation](https://en.wikipedia.org/wiki/Cross-correlation)
- [Fast Fourier Transform (FFT)](https://en.wikipedia.org/wiki/Fast_Fourier_transform)

### 音频格式
- [WAV File Format](http://soundfile.sapp.org/doc/WaveFormat/)
- [MP3 Technical Details](https://en.wikipedia.org/wiki/MP3)

### Flutter
- [just_audio Documentation](https://pub.dev/packages/just_audio)
- [Provider Documentation](https://pub.dev/packages/provider)
- [Dart FFI Guide](https://dart.dev/guides/libraries/c-interop)

---

**最后更新**: 2026-02-07  
**文档版本**: 1.0.0
