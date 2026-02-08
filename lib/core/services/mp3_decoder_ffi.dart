import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';

/// MP3 解码器 FFI 绑定
/// 
/// 使用 minimp3 库进行高性能 MP3 解码
class Mp3DecoderFFI {
  static ffi.DynamicLibrary? _dylib;
  
  /// 初始化动态库
  static void initialize() {
    if (_dylib != null) return;
    
    if (Platform.isWindows) {
      // Windows: 从 lib/native/build/Release 加载
      final libPath = _getLibraryPath();
      _dylib = ffi.DynamicLibrary.open(libPath);
    } else if (Platform.isLinux) {
      _dylib = ffi.DynamicLibrary.open('libmp3_decoder.so');
    } else if (Platform.isMacOS) {
      _dylib = ffi.DynamicLibrary.open('libmp3_decoder.dylib');
    } else {
      throw UnsupportedError('不支持的平台');
    }
  }
  
  /// 获取动态库路径
  static String _getLibraryPath() {
    // 获取当前可执行文件的目录
    final exePath = Platform.resolvedExecutable;
    final exeDir = File(exePath).parent.path;
    
    // 尝试多个可能的路径
    final possiblePaths = [
      // 开发环境路径
      'D:\\seamless loop music\\seamless-loop-music-flutter\\lib\\native\\build\\Release\\mp3_decoder.dll',
      // 相对于可执行文件的路径
      '$exeDir\\mp3_decoder.dll',
      '$exeDir\\data\\flutter_assets\\lib\\native\\build\\Release\\mp3_decoder.dll',
    ];
    
    for (final path in possiblePaths) {
      if (File(path).existsSync()) {
        return path;
      }
    }
    
    throw Exception('找不到 mp3_decoder.dll,请确保已编译动态库');
  }
  
  /// 获取动态库实例
  static ffi.DynamicLibrary get dylib {
    if (_dylib == null) {
      initialize();
    }
    return _dylib!;
  }
}

/// MP3 解码器句柄（不透明指针）
final class Mp3Decoder extends ffi.Opaque {}

/// 函数签名定义

// mp3_open
typedef Mp3OpenNative = ffi.Pointer<Mp3Decoder> Function(ffi.Pointer<Utf8> filename);
typedef Mp3Open = ffi.Pointer<Mp3Decoder> Function(ffi.Pointer<Utf8> filename);

// mp3_read_samples
typedef Mp3ReadSamplesNative = ffi.Int32 Function(
  ffi.Pointer<Mp3Decoder> decoder,
  ffi.Int64 startSample,
  ffi.Int32 count,
  ffi.Pointer<ffi.Float> buffer,
);
typedef Mp3ReadSamples = int Function(
  ffi.Pointer<Mp3Decoder> decoder,
  int startSample,
  int count,
  ffi.Pointer<ffi.Float> buffer,
);

// mp3_get_sample_rate
typedef Mp3GetSampleRateNative = ffi.Int32 Function(ffi.Pointer<Mp3Decoder> decoder);
typedef Mp3GetSampleRate = int Function(ffi.Pointer<Mp3Decoder> decoder);

// mp3_get_channels
typedef Mp3GetChannelsNative = ffi.Int32 Function(ffi.Pointer<Mp3Decoder> decoder);
typedef Mp3GetChannels = int Function(ffi.Pointer<Mp3Decoder> decoder);

// mp3_get_total_samples
typedef Mp3GetTotalSamplesNative = ffi.Int64 Function(ffi.Pointer<Mp3Decoder> decoder);
typedef Mp3GetTotalSamples = int Function(ffi.Pointer<Mp3Decoder> decoder);

// mp3_close
typedef Mp3CloseNative = ffi.Void Function(ffi.Pointer<Mp3Decoder> decoder);
typedef Mp3Close = void Function(ffi.Pointer<Mp3Decoder> decoder);

/// FFI 函数绑定
class Mp3DecoderBindings {
  late final Mp3Open mp3Open;
  late final Mp3ReadSamples mp3ReadSamples;
  late final Mp3GetSampleRate mp3GetSampleRate;
  late final Mp3GetChannels mp3GetChannels;
  late final Mp3GetTotalSamples mp3GetTotalSamples;
  late final Mp3Close mp3Close;
  
  Mp3DecoderBindings() {
    final dylib = Mp3DecoderFFI.dylib;
    
    mp3Open = dylib
        .lookup<ffi.NativeFunction<Mp3OpenNative>>('mp3_open')
        .asFunction();
    
    mp3ReadSamples = dylib
        .lookup<ffi.NativeFunction<Mp3ReadSamplesNative>>('mp3_read_samples')
        .asFunction();
    
    mp3GetSampleRate = dylib
        .lookup<ffi.NativeFunction<Mp3GetSampleRateNative>>('mp3_get_sample_rate')
        .asFunction();
    
    mp3GetChannels = dylib
        .lookup<ffi.NativeFunction<Mp3GetChannelsNative>>('mp3_get_channels')
        .asFunction();
    
    mp3GetTotalSamples = dylib
        .lookup<ffi.NativeFunction<Mp3GetTotalSamplesNative>>('mp3_get_total_samples')
        .asFunction();
    
    mp3Close = dylib
        .lookup<ffi.NativeFunction<Mp3CloseNative>>('mp3_close')
        .asFunction();
  }
}
