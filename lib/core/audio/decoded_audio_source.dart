import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../../src/rust/api.dart' as rust_api;
import 'wav_utils.dart';

/// 解码音频源
/// 
/// 负责将非原生支持的格式（如 OGG/MP3）通过 Rust 解码为 WAV 临时文件
/// 从而让 just_audio 能够播放
class DecodedAudioSource {
  // 简单的内存缓存: 原始文件路径 -> 转码后的临时文件路径
  static final Map<String, String> _cache = {};

  /// 获取解码后的 WAV 文件路径
  /// 如果已缓存且文件存在，直接返回；否则进行转码
  static Future<String> getDecodedPath(String filePath) async {
    // 1. 检查缓存
    if (_cache.containsKey(filePath)) {
      final cachedPath = _cache[filePath]!;
      if (await File(cachedPath).exists()) {
        print('🚀 Cache hit: using existing decoded WAV: $cachedPath');
        return cachedPath;
      } else {
        _cache.remove(filePath); // 文件被删了，清理缓存
      }
    }

    // 2. 获取音频信息
    final info = await rust_api.getAudioInfo(path: filePath);
    final sampleRate = info.sampleRate ?? 44100;
    final totalSamples = info.totalSamples ?? BigInt.zero;
    final numChannels = 2; // Rust now outputs Stereo (Interleaved)

    // 3. 准备临时文件
    final tempDir = await getTemporaryDirectory();
    // 使用 hash 作为文件名的一部分，确保唯一性
    // 添加 _stereo 后缀以区分新旧版本的缓存 (解决 2倍速 bug)
    final fileNameHash = filePath.hashCode;
    final tempWavFile = File('${tempDir.path}/decoded_${fileNameHash}_stereo.wav');

    // 如果文件已经存在（可能是上次运行留下的，或者是并发写入的），先删掉以防万一
    // (或者我们可以信任它？为了安全，还是覆盖吧)
    // 但如果有缓存机制，理应重用。这里我们简化处理：覆写。
    
    // 4. 准备 WAV 头
    // Rust returns total frames (samples per channel), so pass directly.
    int totalFrames = totalSamples.toInt(); 
    print('🔍 DecodedAudioSource: Start decoding $totalFrames frames to WAV...');
    
    // 打开文件写入流
    final sink = tempWavFile.openWrite();

    // 6. 分块解码并写入
    const chunkSize = 1024 * 64; // 每次读 64k 帧
    var currentSample = 0;
    bool headerWritten = false;
    
    // totalFrames is int
    while (currentSample < totalFrames) {
      final remaining = totalFrames - currentSample;
      final count = remaining > chunkSize ? chunkSize : remaining;

      // 调用 Rust 读取 PCM 数据 (Float32)
      final pcmFloat = await rust_api.readAudioSamples(
        path: filePath,
        startSample: BigInt.from(currentSample),
        count: BigInt.from(count),
      );

      // --- 动态检测声道数 logic ---
      if (!headerWritten) {
         int detectedChannels = 1;

         // 如果收到数据量 == 请求帧数 -> Mono (1 channel)
         // 如果收到数据量 == 请求帧数 * 2 -> Stereo (2 channels)
         if (pcmFloat.length == count) {
            detectedChannels = 1;
            print('⚠️ Auto-detected MONO audio (1 channel). Generated WAV header for MONO.');
         } else if (pcmFloat.length >= count * 2) {
            detectedChannels = 2;
            print('✅ Auto-detected STEREO audio (2 channels). Generated WAV header for STEREO.');
         } else {
            // fallback
            print('❓ Unknown data ratio. Length: ${pcmFloat.length}, Count: $count. Defaulting to Mono.');
            detectedChannels = 1;
         }

         // 延迟写入 Header
         final header = WavUtils.createWavHeader(
            sampleRate: sampleRate,
            numChannels: detectedChannels,
            totalSamples: totalFrames,
         );
         sink.add(header);
         headerWritten = true;
      }
      // ---------------------------

      // 转换为 Bytes (Float32 -> Bytes, Little Endian)
      final buffer = WavUtils.float32ToBytes(pcmFloat);
      
      sink.add(buffer);
      
      currentSample += count;
    }

    await sink.flush();
    await sink.close();

    print('✅ DecodedAudioSource: Decoding complete. Created temp WAV: ${tempWavFile.path}');

    // 7. 更新缓存并返回
    _cache[filePath] = tempWavFile.path;
    return tempWavFile.path;
  }
}
