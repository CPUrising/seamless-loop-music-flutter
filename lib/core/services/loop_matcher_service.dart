import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import '../data/loop_config.dart';
import 'wav_reader.dart';
import 'mp3_reader.dart';
import 'mp3_reader_ffi.dart';
import 'ogg_reader_ffi.dart';
import '../../src/rust/api.dart' as rust_api;

/// 音频循环点智能匹配服务
/// 基于 SAD (Sum of Absolute Differences) 算法
class LoopMatcherService {
  /// 智能寻找最佳循环点 (逆向回溯匹配算法)
  /// 
  /// 原理：
  /// 1. 锚定 End 点不动
  /// 2. 提取 End 点之前的音频作为"指纹" (Template)
  /// 3. 在 Start 点附近搜索最匹配的位置
  /// 4. 调整 Start 点以匹配 End 的前导波形
  /// 
  /// 参数：
  /// - filePath: 音频文件路径
  /// - currentStart: 当前起点（采样数）
  /// - currentEnd: 当前终点（采样数）
  /// - sampleRate: 采样率
  /// 
  /// 返回：
  /// - (bestStart, bestEnd, score) 元组
  Future<(int, int, double)> findBestLoopPoints({
    required String filePath,
    required int currentStart,
    required int currentEnd,
    required int sampleRate,
  }) async {
    try {
      // 1. 定义匹配窗口 (1秒)
      final windowSize = sampleRate;

      // 2. 提取 END 点的"前世指纹" (Template)
      final templateEndPos = currentEnd;
      final templateStartPos = max(0, currentEnd - windowSize);
      final templateLen = templateEndPos - templateStartPos;

      if (templateLen < sampleRate ~/ 10) {
        // 指纹太短
        return (currentStart, currentEnd, 0.0);
      }

      // 读取 End 点的指纹
      final template = await _readSamples(filePath, templateStartPos, templateLen);
      if (template.isEmpty) {
        return (currentStart, currentEnd, 0.0);
      }

      // 3. 定义 START 点的搜索区域 (前后 2 秒)
      final searchRadius = sampleRate * 2;
      final searchRegionBegin = max(0, currentStart - searchRadius);
      final searchRegionEnd = currentStart + searchRadius;
      final searchLen = searchRegionEnd - searchRegionBegin;

      if (searchLen < templateLen) {
        return (currentStart, currentEnd, 0.0);
      }

      // 读取搜索区域的波形
      final searchBuffer = await _readSamples(filePath, searchRegionBegin, searchLen);
      if (searchBuffer.isEmpty || searchBuffer.length < template.length) {
        return (currentStart, currentEnd, 0.0);
      }

      // 4. 核心匹配逻辑 (SAD)
      final (bestMatchOffset, minDiff) = _sadMatch(template, searchBuffer);

      if (bestMatchOffset == -1) {
        return (currentStart, currentEnd, 0.0);
      }

      // 5. 应用结果
      // bestMatchOffset 是指纹在 searchBuffer 中的起始位置
      // 片段结束位置就是新的 Start 点
      final matchPosStart = searchRegionBegin + bestMatchOffset;
      final matchPosEnd = matchPosStart + templateLen;
      final bestStart = matchPosEnd;

      // 计算评分（归一化）
      final maxPossibleDiff = template.length * 2.0; // 假设最大差异为 2.0
      final score = 1.0 - (minDiff / maxPossibleDiff).clamp(0.0, 1.0);

      return (bestStart, currentEnd, score);
    } catch (e) {
      throw Exception('匹配失败: $e');
    }
  }

  /// 读取音频采样数据
  /// 
  /// 当前支持的格式：
  /// - ✅ WAV 文件（PCM 格式）
  /// - ✅ MP3 文件（FFI + minimp3）
  /// - ✅ OGG 文件（FFI + stb_vorbis）
  /// - ⏳ FLAC（未来版本）
  /// - ⏳ FLAC（未来版本）
  Future<Float32List> _readSamples(
    String filePath,
    int startSample,
    int count,
  ) async {
    try {
      // 直接调用 Rust 接口，它会自动处理 WAV, MP3, OGG 等格式
      final samples = await rust_api.readAudioSamples(
        path: filePath,
        startSample: BigInt.from(startSample),
        count: BigInt.from(count),
      );
      
      return samples;
    } catch (e) {
      throw Exception('Rust 读取音频失败: $e');
    }
  }

  /// 生成模拟采样数据（用于测试）
  /// 
  /// 注意：这个方法仅用于算法测试，不应在生产环境中使用
  Float32List _generateMockSamples(int startSample, int count) {
    final samples = Float32List(count);
    for (int i = 0; i < count; i++) {
      // 生成 440Hz 正弦波（A4 音符）
      final t = (startSample + i) / 44100.0;
      samples[i] = sin(2 * pi * 440 * t) * 0.5;
    }
    return samples;
  }

  /// SAD (Sum of Absolute Differences) 匹配算法
  /// 
  /// 参数：
  /// - template: 模板波形（End 点的指纹）
  /// - searchBuffer: 搜索区域波形
  /// 
  /// 返回：
  /// - (bestOffset, minDiff) 元组
  (int, double) _sadMatch(Float32List template, Float32List searchBuffer) {
    double minDiff = double.maxFinite;
    int bestMatchOffset = -1;

    // 滑动窗口匹配
    for (int i = 0; i <= searchBuffer.length - template.length; i++) {
      double diff = 0;
      
      // 优化：步长为 4，跳过部分采样点
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

  /// 短距离微调
  /// 
  /// 在当前循环点附近进行小范围搜索（±100ms）
  /// 用于精细调整，避免爆音
  Future<(int, int)> fineTuneLoopPoints({
    required String filePath,
    required int currentStart,
    required int currentEnd,
    required int sampleRate,
  }) async {
    try {
      // 短距离搜索范围：±100ms
      final searchRadius = (sampleRate * 0.1).toInt();

      // TODO: 实现精细调整算法
      // 1. 在 ±100ms 范围内搜索过零点
      // 2. 或者使用更小的窗口进行 SAD 匹配

      return (currentStart, currentEnd);
    } catch (e) {
      throw Exception('微调失败: $e');
    }
  }

  /// 检测过零点
  /// 
  /// 在指定位置附近寻找音频波形的过零点
  /// 用于避免爆音（在波形为 0 的地方切换）
  Future<int> findZeroCrossing({
    required String filePath,
    required int targetSample,
    required int sampleRate,
    int searchRadius = 2205, // 默认 50ms @ 44100Hz
  }) async {
    try {
      // TODO: 实现过零点检测
      // 1. 读取 targetSample 附近的波形
      // 2. 找到最接近 0 的点
      // 3. 返回该点的采样位置

      return targetSample;
    } catch (e) {
      throw Exception('过零点检测失败: $e');
    }
  }
}
