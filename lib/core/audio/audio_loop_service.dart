import 'dart:async';
import 'package:just_audio/just_audio.dart';
import '../data/loop_config.dart';

/// 无缝循环音频播放服务
class AudioLoopService {
  final AudioPlayer _player = AudioPlayer();
  
  LoopConfig? _currentConfig;
  LoopPoint? _currentLoop;
  StreamSubscription? _positionSubscription;

  /// 播放器状态流
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  
  /// 播放位置流
  Stream<Duration> get positionStream => _player.positionStream;
  
  /// 总时长
  Duration? get duration => _player.duration;
  
  /// 当前位置
  Duration get position => _player.position;
  
  /// 是否正在播放
  bool get isPlaying => _player.playing;

  /// 当前配置
  LoopConfig? get currentConfig => _currentConfig;
  
  /// 当前循环点
  LoopPoint? get currentLoop => _currentLoop;

  /// 加载音频文件并应用循环配置
  Future<void> loadAudio(String filePath, LoopConfig config) async {
    _currentConfig = config;
    _currentLoop = config.primaryLoop;

    if (_currentLoop == null) {
      // 没有循环点，正常播放
      await _player.setAudioSource(
        AudioSource.file(filePath),
      );
      return;
    }

    // 创建带循环点的音频源
    final loopSource = _createLoopingSource(filePath, _currentLoop!, config.sampleRate);
    await _player.setAudioSource(loopSource);
    
    // 启动循环监听
    _startLoopMonitoring();
  }

  /// 创建循环音频源
  AudioSource _createLoopingSource(String filePath, LoopPoint loop, int sampleRate) {
    final startDuration = loop.getStartDuration(sampleRate);
    final endDuration = loop.getEndDuration(sampleRate);

    // 使用 ClippingAudioSource + LoopingAudioSource 实现无缝循环
    final clippedSource = ClippingAudioSource(
      child: AudioSource.file(filePath),
      start: startDuration,
      end: endDuration,
    );

    // 无限循环该片段
    return LoopingAudioSource(child: clippedSource);
  }

  /// 启动循环监听（备用方案：手动 seek）
  void _startLoopMonitoring() {
    _positionSubscription?.cancel();
    
    // 注释掉手动监听，因为我们用 ConcatenatingAudioSource 实现了自动循环
    // 如果需要单次循环的手动控制，可以取消注释以下代码：
    /*
    _positionSubscription = _player.positionStream.listen((position) {
      if (_currentLoop == null || _currentConfig == null) return;
      
      final endDuration = _currentLoop!.getEndDuration(_currentConfig!.sampleRate);
      
      // 接近结束点时跳回起点
      if (position >= endDuration - const Duration(milliseconds: 50)) {
        final startDuration = _currentLoop!.getStartDuration(_currentConfig!.sampleRate);
        _player.seek(startDuration);
      }
    });
    */
  }

  /// 播放
  Future<void> play() async {
    await _player.play();
  }

  /// 暂停
  Future<void> pause() async {
    await _player.pause();
  }

  /// 停止
  Future<void> stop() async {
    await _player.stop();
  }

  /// 跳转到指定位置
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  /// 设置音量 (0.0 - 1.0)
  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume.clamp(0.0, 1.0));
  }

  /// 切换循环点
  Future<void> switchLoop(LoopPoint loop) async {
    if (_currentConfig == null) return;
    
    _currentLoop = loop;
    // 使用完整路径而不是仅文件名
    final path = _currentConfig!.filePath ?? _currentConfig!.filename;
    
    // 重新加载音频源
    final loopSource = _createLoopingSource(path, loop, _currentConfig!.sampleRate);
    await _player.setAudioSource(loopSource);
    
    // 如果之前在播放，继续播放
    if (isPlaying) {
      await play();
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    await _positionSubscription?.cancel();
    await _player.dispose();
  }
}
