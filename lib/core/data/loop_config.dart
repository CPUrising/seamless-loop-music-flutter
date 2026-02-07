/// 循环配置数据模型
class LoopConfig {
  final String filename;
  final String? filePath; // 完整文件路径
  final String title;
  final String artist;
  final int sampleRate;
  final int totalSamples;
  final List<LoopPoint> loops;

  LoopConfig({
    required this.filename,
    this.filePath,
    required this.title,
    required this.artist,
    required this.sampleRate,
    required this.totalSamples,
    required this.loops,
  });

  /// 从 JSON 解析
  factory LoopConfig.fromJson(Map<String, dynamic> json) {
    return LoopConfig(
      filename: json['filename'] as String,
      filePath: json['file_path'] as String?,
      title: json['title'] as String,
      artist: json['artist'] as String? ?? 'Unknown',
      sampleRate: json['sample_rate'] as int,
      totalSamples: json['total_samples'] as int,
      loops: (json['loops'] as List)
          .map((e) => LoopPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'filename': filename,
      if (filePath != null) 'file_path': filePath,
      'title': title,
      'artist': artist,
      'sample_rate': sampleRate,
      'total_samples': totalSamples,
      'loops': loops.map((e) => e.toJson()).toList(),
    };
  }

  /// 获取主循环点
  LoopPoint? get primaryLoop {
    try {
      return loops.firstWhere((loop) => loop.isPrimary);
    } catch (_) {
      return loops.isNotEmpty ? loops.first : null;
    }
  }
}

/// 循环点
class LoopPoint {
  final int startSample;
  final int endSample;
  final double score;
  final bool isPrimary;

  LoopPoint({
    required this.startSample,
    required this.endSample,
    required this.score,
    this.isPrimary = false,
  });

  factory LoopPoint.fromJson(Map<String, dynamic> json) {
    return LoopPoint(
      startSample: json['start_point'] as int,
      endSample: json['end_point'] as int,
      score: (json['score'] as num).toDouble(),
      isPrimary: json['is_primary'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'start_point': startSample,
      'end_point': endSample,
      'score': score,
      'is_primary': isPrimary,
    };
  }

  /// 转换采样点到毫秒
  Duration sampleToDuration(int sample, int sampleRate) {
    return Duration(milliseconds: (sample / sampleRate * 1000).round());
  }

  /// 获取循环起点（Duration）
  Duration getStartDuration(int sampleRate) {
    return sampleToDuration(startSample, sampleRate);
  }

  /// 获取循环终点（Duration）
  Duration getEndDuration(int sampleRate) {
    return sampleToDuration(endSample, sampleRate);
  }
}
