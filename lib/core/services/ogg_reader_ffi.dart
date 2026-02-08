import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'ogg_decoder_ffi.dart';

/// OGG 文件读取器（使用 stb_vorbis FFI）
/// 
/// 高性能 OGG 解码,类似 MP3 FFI 方案
class OggReaderFFI {
  final File _file;
  ffi.Pointer<OggDecoder>? _decoder;
  late final OggDecoderBindings _bindings;
  
  int? _sampleRate;
  int? _channels;
  int? _totalSamples;
  
  OggReaderFFI(String filePath) : _file = File(filePath) {
    _bindings = OggDecoderBindings();
  }
  
  /// 检查 FFI 库是否可用
  static bool isFFIAvailable() {
    try {
      OggDecoderFFI.initialize();
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// 解析 OGG 文件信息
  Future<void> parseHeader() async {
    if (!await _file.exists()) {
      throw Exception('文件不存在: ${_file.path}');
    }
    
    try {
      // 打开 OGG 文件
      final pathPtr = _file.path.toNativeUtf8();
      _decoder = _bindings.oggOpen(pathPtr);
      malloc.free(pathPtr);
      
      if (_decoder == null || _decoder!.address == 0) {
        throw Exception('无法打开 OGG 文件');
      }
      
      // 获取文件信息
      _sampleRate = _bindings.oggGetSampleRate(_decoder!);
      _channels = _bindings.oggGetChannels(_decoder!);
      _totalSamples = _bindings.oggGetTotalSamples(_decoder!);
      
      if (_sampleRate == 0 || _channels == 0) {
        throw Exception('无法解析 OGG 文件信息');
      }
    } catch (e) {
      if (_decoder != null && _decoder!.address != 0) {
        _bindings.oggClose(_decoder!);
        _decoder = null;
      }
      throw Exception('解析 OGG 文件失败: $e');
    }
  }
  
  /// 读取指定范围的采样数据
  /// 
  /// 使用 stb_vorbis FFI 进行高性能解码
  Future<Float32List> readSamples(int startSample, int count) async {
    if (_decoder == null || _decoder!.address == 0) {
      throw Exception('请先调用 parseHeader()');
    }
    
    try {
      // 分配缓冲区
      final bufferPtr = malloc.allocate<ffi.Float>(count * ffi.sizeOf<ffi.Float>());
      
      // 读取采样数据
      final samplesRead = _bindings.oggReadSamples(
        _decoder!,
        startSample,
        count,
        bufferPtr,
      );
      
      if (samplesRead < 0) {
        malloc.free(bufferPtr);
        throw Exception('读取 OGG 采样数据失败');
      }
      
      // 转换为 Float32List
      final samples = Float32List(samplesRead);
      for (int i = 0; i < samplesRead; i++) {
        samples[i] = bufferPtr[i];
      }
      
      malloc.free(bufferPtr);
      return samples;
    } catch (e) {
      throw Exception('读取 OGG 采样数据失败: $e');
    }
  }
  
  /// 获取采样率
  int get sampleRate => _sampleRate ?? 0;
  
  /// 获取声道数
  int get channels => _channels ?? 0;
  
  /// 获取总采样数
  int get totalSamples => _totalSamples ?? 0;
  
  /// 关闭解码器
  void dispose() {
    if (_decoder != null && _decoder!.address != 0) {
      _bindings.oggClose(_decoder!);
      _decoder = null;
    }
  }
}
