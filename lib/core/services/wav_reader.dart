import 'dart:io';
import 'dart:typed_data';

/// 简单的 WAV 文件读取器
/// 
/// 注意：这是一个简化版本，只支持标准的 PCM WAV 文件
/// 不支持压缩格式和复杂的 WAV 变体
class WavReader {
  final File _file;
  late int _sampleRate;
  late int _channels;
  late int _bitsPerSample;
  late int _dataOffset;
  late int _dataSize;
  late int _totalSamples;

  WavReader(String filePath) : _file = File(filePath);

  /// 解析 WAV 文件头
  Future<void> parseHeader() async {
    final bytes = await _file.readAsBytes();
    
    // 检查 RIFF 标识
    if (bytes.length < 44) {
      throw Exception('文件太小，不是有效的 WAV 文件');
    }

    final riff = String.fromCharCodes(bytes.sublist(0, 4));
    if (riff != 'RIFF') {
      throw Exception('不是有效的 WAV 文件（缺少 RIFF 标识）');
    }

    final wave = String.fromCharCodes(bytes.sublist(8, 12));
    if (wave != 'WAVE') {
      throw Exception('不是有效的 WAV 文件（缺少 WAVE 标识）');
    }

    // 查找 fmt chunk
    int offset = 12;
    while (offset < bytes.length - 8) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize = ByteData.view(bytes.buffer).getUint32(offset + 4, Endian.little);

      if (chunkId == 'fmt ') {
        // 解析 fmt chunk
        final audioFormat = ByteData.view(bytes.buffer).getUint16(offset + 8, Endian.little);
        if (audioFormat != 1) {
          throw Exception('只支持 PCM 格式的 WAV 文件');
        }

        _channels = ByteData.view(bytes.buffer).getUint16(offset + 10, Endian.little);
        _sampleRate = ByteData.view(bytes.buffer).getUint32(offset + 12, Endian.little);
        _bitsPerSample = ByteData.view(bytes.buffer).getUint16(offset + 22, Endian.little);

        offset += 8 + chunkSize;
      } else if (chunkId == 'data') {
        // 找到 data chunk
        _dataOffset = offset + 8;
        _dataSize = chunkSize;
        _totalSamples = _dataSize ~/ (_channels * (_bitsPerSample ~/ 8));
        break;
      } else {
        // 跳过其他 chunk
        offset += 8 + chunkSize;
      }
    }

    if (_dataOffset == 0) {
      throw Exception('WAV 文件中未找到 data chunk');
    }
  }

  /// 读取指定范围的采样数据
  /// 
  /// 参数：
  /// - startSample: 起始采样点（单声道计数）
  /// - count: 要读取的采样数
  /// 
  /// 返回：
  /// - Float32List: 归一化的采样数据（-1.0 到 1.0）
  Future<Float32List> readSamples(int startSample, int count) async {
    if (startSample < 0 || startSample >= _totalSamples) {
      throw Exception('起始采样点超出范围');
    }

    // 限制读取范围
    final actualCount = (startSample + count > _totalSamples)
        ? _totalSamples - startSample
        : count;

    final bytesPerSample = _channels * (_bitsPerSample ~/ 8);
    final startByte = _dataOffset + startSample * bytesPerSample;
    final byteCount = actualCount * bytesPerSample;

    // 读取原始字节
    final file = await _file.open();
    await file.setPosition(startByte);
    final bytes = await file.read(byteCount);
    await file.close();

    // 转换为 Float32
    final samples = Float32List(actualCount);
    final byteData = ByteData.view(bytes.buffer);

    for (int i = 0; i < actualCount; i++) {
      // 只读取第一个声道（左声道）
      final byteOffset = i * bytesPerSample;

      if (_bitsPerSample == 16) {
        // 16-bit PCM
        final value = byteData.getInt16(byteOffset, Endian.little);
        samples[i] = value / 32768.0;
      } else if (_bitsPerSample == 24) {
        // 24-bit PCM (读取3个字节)
        final byte1 = bytes[byteOffset];
        final byte2 = bytes[byteOffset + 1];
        final byte3 = bytes[byteOffset + 2];
        
        // 组合成 32-bit 整数（符号扩展）
        int value = (byte3 << 24) | (byte2 << 16) | (byte1 << 8);
        value = value >> 8; // 算术右移保留符号
        samples[i] = value / 8388608.0;
      } else if (_bitsPerSample == 32) {
        // 32-bit float
        samples[i] = byteData.getFloat32(byteOffset, Endian.little);
      } else if (_bitsPerSample == 8) {
        // 8-bit PCM (unsigned)
        final value = bytes[byteOffset];
        samples[i] = (value - 128) / 128.0;
      }
    }

    return samples;
  }

  /// 获取采样率
  int get sampleRate => _sampleRate;

  /// 获取声道数
  int get channels => _channels;

  /// 获取位深度
  int get bitsPerSample => _bitsPerSample;

  /// 获取总采样数
  int get totalSamples => _totalSamples;
}
