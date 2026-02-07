import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../data/loop_config.dart';

/// 配置文件管理服务
class ConfigManager {
  static const String _configFileName = 'loop_config.json';
  
  /// 获取配置文件路径
  Future<String> getConfigFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$_configFileName';
  }

  /// 加载配置库
  Future<List<LoopConfig>> loadLibrary() async {
    try {
      final filePath = await getConfigFilePath();
      final file = File(filePath);
      
      if (!await file.exists()) {
        return [];
      }

      final jsonString = await file.readAsString();
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      
      final library = jsonData['library'] as List;
      return library
          .map((e) => LoopConfig.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error loading config: $e');
      return [];
    }
  }

  /// 保存配置库
  Future<void> saveLibrary(List<LoopConfig> library) async {
    try {
      final filePath = await getConfigFilePath();
      final file = File(filePath);
      
      final jsonData = {
        'version': '1.0',
        'library': library.map((e) => e.toJson()).toList(),
      };
      
      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);
      await file.writeAsString(jsonString);
    } catch (e) {
      print('Error saving config: $e');
      rethrow;
    }
  }

  /// 添加或更新配置
  Future<void> addOrUpdateConfig(LoopConfig config) async {
    final library = await loadLibrary();
    
    // 查找是否已存在
    final index = library.indexWhere((c) => c.filename == config.filename);
    
    if (index >= 0) {
      library[index] = config;
    } else {
      library.add(config);
    }
    
    await saveLibrary(library);
  }

  /// 删除配置
  Future<void> removeConfig(String filename) async {
    final library = await loadLibrary();
    library.removeWhere((c) => c.filename == filename);
    await saveLibrary(library);
  }

  /// 根据文件名查找配置
  Future<LoopConfig?> findConfig(String filename) async {
    final library = await loadLibrary();
    try {
      return library.firstWhere((c) => c.filename == filename);
    } catch (_) {
      return null;
    }
  }
}
