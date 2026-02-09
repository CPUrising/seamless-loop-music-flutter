import 'dart:typed_data';

/// WAV 格式工具类
/// 用于生成 WAV 文件头和处理 PCM 数据
class WavUtils {
  /// 生成标准的 WAV 文件头 (44 bytes)
  /// 
  /// 参数：
  /// - sampleRate: 采样率 (e.g., 44100)
  /// - numChannels: 声道数 (1=Mono, 2=Stereo)
  /// - totalSamples per channel: 单个声道的采样点总数 (注意不是总数据长度，是帧数)
  static Uint8List createWavHeader({
    required int sampleRate,
    required int numChannels,
    required int totalSamples,
  }) {
    final buffer = ByteData(44);
    
    // 计算相关数据
    final bitsPerSample = 32; // 我们使用 float32 格式，所以是 32位
    final byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    final blockAlign = numChannels * (bitsPerSample ~/ 8);
    final dataSize = totalSamples * numChannels * (bitsPerSample ~/ 8);
    final fileSize = 36 + dataSize;

    var offset = 0;

    // 1. RIFF Chunk Descriptor
    _writeString(buffer, offset, 'RIFF'); offset += 4;
    buffer.setInt32(offset, fileSize, Endian.little); offset += 4; // ChunkSize
    _writeString(buffer, offset, 'WAVE'); offset += 4;

    // 2. fmt Sub-chunk
    _writeString(buffer, offset, 'fmt '); offset += 4;
    buffer.setInt32(offset, 16, Endian.little); offset += 4; // Subchunk1Size (16 for PCM)
    buffer.setInt16(offset, 3, Endian.little); offset += 2; // AudioFormat (3 = IEEE Float)
    buffer.setInt16(offset, numChannels, Endian.little); offset += 2; // NumChannels
    buffer.setInt32(offset, sampleRate, Endian.little); offset += 4; // SampleRate
    buffer.setInt32(offset, byteRate, Endian.little); offset += 4; // ByteRate
    buffer.setInt16(offset, blockAlign, Endian.little); offset += 2; // BlockAlign
    buffer.setInt16(offset, bitsPerSample, Endian.little); offset += 2; // BitsPerSample

    // 3. data Sub-chunk
    _writeString(buffer, offset, 'data'); offset += 4;
    buffer.setInt32(offset, dataSize, Endian.little); offset += 4; // Subchunk2Size

    return buffer.buffer.asUint8List();
  }

  /// 辅助方法：写入字符串到 ByteData
  static void _writeString(ByteData buffer, int offset, String text) {
    for (int i = 0; i < text.length; i++) {
      buffer.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  /// 将 Float32List (PCM) 转换为字节流 (Little Endian)
  static Uint8List float32ToBytes(Float32List samples) {
    final buffer = Uint8List(samples.length * 4);
    final view = ByteData.view(buffer.buffer);
    
    for (int i = 0; i < samples.length; i++) {
      view.setFloat32(i * 4, samples[i], Endian.little);
    }
    
    return buffer;
  }
}
