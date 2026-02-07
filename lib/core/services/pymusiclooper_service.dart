import 'dart:convert';
import 'dart:io';
import '../data/loop_config.dart';

/// PyMusicLooper 分析服务
class PyMusicLooperService {
  /// 分析音频文件，返回循环点
  Future<LoopConfig> analyzeAudio(String filePath) async {
    // 检查文件是否存在
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('文件不存在: $filePath');
    }

    try {
      // 调用 pymusiclooper 命令行工具
      // 命令格式: pymusiclooper "文件路径" --export-points
      final result = await Process.run(
        'pymusiclooper',
        [
          filePath,
          '--export-points',
        ],
        runInShell: true,
      );

      if (result.exitCode != 0) {
        throw Exception('PyMusicLooper 执行失败: ${result.stderr}');
      }

      // 解析输出
      final output = result.stdout as String;
      return _parseOutput(output, filePath);
    } catch (e) {
      throw Exception('分析失败: $e');
    }
  }

  /// 解析 pymusiclooper 的输出
  LoopConfig _parseOutput(String output, String filePath) {
    try {
      // pymusiclooper 的输出格式示例：
      // Loop points found:
      // Start: 2158092 samples (48.93 seconds)
      // End: 5819712 samples (131.93 seconds)
      // Score: 0.98

      final lines = output.split('\n');
      int? startSample;
      int? endSample;
      double score = 1.0;
      int? sampleRate;

      for (var line in lines) {
        line = line.trim();
        
        // 提取起点
        if (line.contains('Start:') && line.contains('samples')) {
          final match = RegExp(r'(\d+)\s+samples').firstMatch(line);
          if (match != null) {
            startSample = int.parse(match.group(1)!);
          }
        }
        
        // 提取终点
        if (line.contains('End:') && line.contains('samples')) {
          final match = RegExp(r'(\d+)\s+samples').firstMatch(line);
          if (match != null) {
            endSample = int.parse(match.group(1)!);
          }
        }
        
        // 提取评分
        if (line.contains('Score:')) {
          final match = RegExp(r'Score:\s+([\d.]+)').firstMatch(line);
          if (match != null) {
            score = double.parse(match.group(1)!);
          }
        }

        // 提取采样率
        if (line.contains('Sample rate:') || line.contains('Hz')) {
          final match = RegExp(r'(\d+)\s*Hz').firstMatch(line);
          if (match != null) {
            sampleRate = int.parse(match.group(1)!);
          }
        }
      }

      // 如果没有找到循环点，抛出异常
      if (startSample == null || endSample == null) {
        throw Exception('未能解析循环点');
      }

      // 如果没有采样率，使用默认值
      sampleRate ??= 44100;

      // 计算总采样数（使用终点作为估算）
      final totalSamples = endSample + (sampleRate * 10); // 终点后再加10秒

      // 提取文件名
      final fileName = filePath.split(Platform.pathSeparator).last;
      final title = fileName.replaceAll(
        RegExp(r'\.(mp3|wav|ogg|flac|m4a)$', caseSensitive: false),
        '',
      );

      return LoopConfig(
        filename: fileName,
        filePath: filePath,
        title: title,
        artist: 'Unknown',
        sampleRate: sampleRate,
        totalSamples: totalSamples,
        loops: [
          LoopPoint(
            startSample: startSample,
            endSample: endSample,
            score: score,
            isPrimary: true,
          ),
        ],
      );
    } catch (e) {
      throw Exception('解析输出失败: $e');
    }
  }

  /// 检查 pymusiclooper 是否已安装
  Future<bool> isInstalled() async {
    try {
      final result = await Process.run(
        'pymusiclooper',
        ['--version'],
        runInShell: true,
      );
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// 获取 pymusiclooper 版本
  Future<String?> getVersion() async {
    try {
      final result = await Process.run(
        'pymusiclooper',
        ['--version'],
        runInShell: true,
      );
      if (result.exitCode == 0) {
        return (result.stdout as String).trim();
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
