import 'dart:async';
import 'package:just_audio/just_audio.dart';
import '../data/loop_config.dart';
import 'decoded_audio_source.dart';

/// 无缝循环音频播放服务
class AudioLoopService {
  final AudioPlayer _player = AudioPlayer();
  
  LoopConfig? _currentConfig;
  LoopPoint? _currentLoop;
  // ignore: unused_field
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
  /// 
  /// [initialLoop] 可选：指定要使用的循环点，否则使用配置中的默认循环点
  Future<void> loadAudio(String filePath, LoopConfig config, {LoopPoint? initialLoop}) async {
    _currentConfig = config;
    // 优先使用传入的 loop，否则使用默认 loop
    _currentLoop = initialLoop ?? config.primaryLoop;

    print('🔍 AudioLoopService: Loading file: "$filePath"');

    // 检查文件扩展名，决定是否需要转码
    final ext = filePath.toLowerCase().split('.').last;
    final bool needsTranscoding = (ext == 'ogg' || ext == 'flac');

    try {
      String finalPath = filePath;
      
      if (needsTranscoding) {
        print('🔄 Detected $ext file. Transcoding via Rust...');
        // 获取转码后的 WAV 路径 (带缓存)
        finalPath = await DecodedAudioSource.getDecodedPath(filePath);
      }
      
      AudioSource source;
      
      // 如果有循环点配置，使用 ClippingAudioSource + LoopMode.one
      if (_currentLoop != null) {
         print('🔄 Applying loop points on: $finalPath');
         final startDuration = _currentLoop!.getStartDuration(config.sampleRate);
         final endDuration = _currentLoop!.getEndDuration(config.sampleRate);
         
         // 仅创建一个裁剪源
         source = ClippingAudioSource(
           child: AudioSource.file(finalPath),
           start: startDuration,
           end: endDuration,
           tag: config, // 传递元数据
         );
         
         await _player.setLoopMode(LoopMode.one); // 关键：开启单曲循环
      } else {
         // 没有循环点，直接播放
         source = AudioSource.file(finalPath, tag: config);
         await _player.setLoopMode(LoopMode.off);
      }

      await _player.setAudioSource(source);

    } catch (e) {
      print('❌ AudioLoopService: Load failed: $e');
      // 发生错误时重置状态
      await _player.stop();
      rethrow;
    }
  }

  /// 设置倍速 (0.5 - 4.0)
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
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
    
    // 使用完整路径而不是仅文件名
    final path = _currentConfig!.filePath ?? _currentConfig!.filename;
    
    // 重新加载音频源，并显式传递当前的 loop，防止被重置
    // 注意：loadAudio 会自动使用 DecodedAudioSource 的缓存，所以这里很快
    await loadAudio(path, _currentConfig!, initialLoop: loop);

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
