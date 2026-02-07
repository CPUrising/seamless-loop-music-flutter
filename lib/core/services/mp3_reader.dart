import 'dart:io';
import 'dart:typed_data';

/// MP3 文件读取器（使用 ffmpeg 解码）
/// 
/// 注意：需要系统安装 ffmpeg
class Mp3Reader {
  final File _file;
  int? _sampleRate;
  int? _channels;
  int? _totalSamples;

  Mp3Reader(String filePath) : _file = File(filePath);

  /// 检查 ffmpeg 是否可用
  static Future<bool> isFFmpegAvailable() async {
    try {
      final result = await Process.run('ffmpeg', ['-version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// 解析 MP3 文件信息
  Future<void> parseHeader() async {
    // 使用 ffprobe 获取文件信息
    try {
      final result = await Process.run('ffprobe', [
        '-v', 'error',
        '-show_entries', 'stream=sample_rate,channels,duration',
        '-of', 'default=noprint_wrappers=1',
        _file.path,
      ]);

      if (result.exitCode != 0) {
        throw Exception('ffprobe 执行失败: ${result.stderr}');
      }

      // 解析输出
      final output = result.stdout as String;
      final lines = output.split('\n');
      
      for (var line in lines) {
        if (line.startsWith('sample_rate=')) {
          _sampleRate = int.parse(line.split('=')[1]);
        } else if (line.startsWith('channels=')) {
          _channels = int.parse(line.split('=')[1]);
        } else if (line.startsWith('duration=')) {
          final duration = double.parse(line.split('=')[1]);
          _totalSamples = (_sampleRate! * duration).toInt();
        }
      }

      if (_sampleRate == null || _channels == null) {
        throw Exception('无法解析 MP3 文件信息');
      }
    } catch (e) {
      throw Exception('解析 MP3 文件失败: $e');
    }
  }

  /// 读取指定范围的采样数据
  /// 
  /// 使用 ffmpeg 解码指定范围的音频数据
  Future<Float32List> readSamples(int startSample, int count) async {
    if (_sampleRate == null) {
      throw Exception('请先调用 parseHeader()');
    }

    try {
      // 计算时间偏移
      final startTime = startSample / _sampleRate!;
      final duration = count / _sampleRate!;

      // 使用 ffmpeg 解码为 PCM float32
      final result = await Process.run('ffmpeg', [
        '-ss', startTime.toString(),
        '-t', duration.toString(),
        '-i', _file.path,
        '-f', 'f32le',  // 输出格式：float32 little-endian
        '-ac', '1',     // 转换为单声道
        '-ar', _sampleRate.toString(),
        'pipe:1',       // 输出到 stdout
      ], stdoutEncoding: null);  // 不要编码，保持二进制

      if (result.exitCode != 0) {
        throw Exception('ffmpeg 解码失败: ${result.stderr}');
      }

      // 转换字节数据为 Float32List
      final bytes = result.stdout as List<int>;
      final byteData = ByteData.view(Uint8List.fromList(bytes).buffer);
      
      final sampleCount = bytes.length ~/ 4;  // float32 = 4 bytes
      final samples = Float32List(sampleCount);
      
      for (int i = 0; i < sampleCount; i++) {
        samples[i] = byteData.getFloat32(i * 4, Endian.little);
      }

      return samples;
    } catch (e) {
      throw Exception('读取 MP3 采样数据失败: $e');
    }
  }

  /// 获取采样率
  int get sampleRate => _sampleRate ?? 0;

  /// 获取声道数
  int get channels => _channels ?? 0;

  /// 获取总采样数
  int get totalSamples => _totalSamples ?? 0;
}
