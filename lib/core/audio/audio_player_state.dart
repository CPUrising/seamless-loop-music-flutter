import 'package:flutter/foundation.dart';
import 'audio_loop_service.dart';
import '../data/loop_config.dart';
import '../services/config_manager.dart';

/// 音频播放器状态管理
class AudioPlayerState extends ChangeNotifier {
  final AudioLoopService _audioService = AudioLoopService();
  final ConfigManager _configManager = ConfigManager();

  List<LoopConfig> _library = [];
  LoopConfig? _currentConfig;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  /// 音乐库
  List<LoopConfig> get library => _library;
  
  /// 当前配置
  LoopConfig? get currentConfig => _currentConfig;
  
  /// 是否正在播放
  bool get isPlaying => _isPlaying;
  
  /// 当前位置
  Duration get currentPosition => _currentPosition;
  
  /// 总时长
  Duration get totalDuration => _totalDuration;
  
  /// 当前循环点
  LoopPoint? get currentLoop => _audioService.currentLoop;

  AudioPlayerState() {
    _init();
  }

  /// 初始化
  Future<void> _init() async {
    // 加载配置库
    await loadLibrary();
    
    // 监听播放状态
    _audioService.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      notifyListeners();
    });
    
    // 监听播放位置
    _audioService.positionStream.listen((position) {
      _currentPosition = position;
      notifyListeners();
    });
  }

  /// 加载配置库
  Future<void> loadLibrary() async {
    _library = await _configManager.loadLibrary();
    notifyListeners();
  }

  /// 加载并播放音频
  Future<void> loadAndPlay(String filePath, LoopConfig config) async {
    try {
      await _audioService.loadAudio(filePath, config);
      _currentConfig = config;
      _totalDuration = _audioService.duration ?? Duration.zero;
      notifyListeners();
      
      await play();
    } catch (e) {
      print('Error loading audio: $e');
      rethrow;
    }
  }

  /// 播放
  Future<void> play() async {
    await _audioService.play();
  }

  /// 暂停
  Future<void> pause() async {
    await _audioService.pause();
  }

  /// 停止
  Future<void> stop() async {
    await _audioService.stop();
  }

  /// 跳转
  Future<void> seek(Duration position) async {
    await _audioService.seek(position);
  }

  /// 设置音量
  Future<void> setVolume(double volume) async {
    await _audioService.setVolume(volume);
  }

  /// 切换循环点
  Future<void> switchLoop(LoopPoint loop) async {
    await _audioService.switchLoop(loop);
    notifyListeners();
  }

  /// 添加或更新配置
  Future<void> addOrUpdateConfig(LoopConfig config) async {
    await _configManager.addOrUpdateConfig(config);
    await loadLibrary();
  }

  /// 根据文件名查找配置
  Future<LoopConfig?> findConfigByFilename(String filename) async {
    return await _configManager.findConfig(filename);
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }
}
