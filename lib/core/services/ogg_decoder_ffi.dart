import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';

/// OGG 解码器 FFI 绑定
/// 
/// 使用 stb_vorbis 库进行高性能 OGG 解码
class OggDecoderFFI {
  static ffi.DynamicLibrary? _dylib;
  
  /// 初始化动态库
  static void initialize() {
    if (_dylib != null) return;
    
    if (Platform.isWindows) {
      // Windows: 从 lib/native/build/Release 加载
      final libPath = _getLibraryPath();
      _dylib = ffi.DynamicLibrary.open(libPath);
    } else if (Platform.isLinux) {
      _dylib = ffi.DynamicLibrary.open('libogg_decoder.so');
    } else if (Platform.isMacOS) {
      _dylib = ffi.DynamicLibrary.open('libogg_decoder.dylib');
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
      'D:\\seamless loop music\\seamless-loop-music-flutter\\lib\\native\\build\\Release\\ogg_decoder.dll',
      // 相对于可执行文件的路径
      '$exeDir\\ogg_decoder.dll',
      '$exeDir\\data\\flutter_assets\\lib\\native\\build\\Release\\ogg_decoder.dll',
    ];
    
    for (final path in possiblePaths) {
      if (File(path).existsSync()) {
        return path;
      }
    }
    
    throw Exception('找不到 ogg_decoder.dll,请确保已编译动态库');
  }
  
  /// 获取动态库实例
  static ffi.DynamicLibrary get dylib {
    if (_dylib == null) {
      initialize();
    }
    return _dylib!;
  }
}

/// OGG 解码器句柄（不透明指针）
final class OggDecoder extends ffi.Opaque {}

/// 函数签名定义

// ogg_open
typedef OggOpenNative = ffi.Pointer<OggDecoder> Function(ffi.Pointer<Utf8> filename);
typedef OggOpen = ffi.Pointer<OggDecoder> Function(ffi.Pointer<Utf8> filename);

// ogg_read_samples
typedef OggReadSamplesNative = ffi.Int32 Function(
  ffi.Pointer<OggDecoder> decoder,
  ffi.Int64 startSample,
  ffi.Int32 count,
  ffi.Pointer<ffi.Float> buffer,
);
typedef OggReadSamples = int Function(
  ffi.Pointer<OggDecoder> decoder,
  int startSample,
  int count,
  ffi.Pointer<ffi.Float> buffer,
);

// ogg_get_sample_rate
typedef OggGetSampleRateNative = ffi.Int32 Function(ffi.Pointer<OggDecoder> decoder);
typedef OggGetSampleRate = int Function(ffi.Pointer<OggDecoder> decoder);

// ogg_get_channels
typedef OggGetChannelsNative = ffi.Int32 Function(ffi.Pointer<OggDecoder> decoder);
typedef OggGetChannels = int Function(ffi.Pointer<OggDecoder> decoder);

// ogg_get_total_samples
typedef OggGetTotalSamplesNative = ffi.Int64 Function(ffi.Pointer<OggDecoder> decoder);
typedef OggGetTotalSamples = int Function(ffi.Pointer<OggDecoder> decoder);

// ogg_close
typedef OggCloseNative = ffi.Void Function(ffi.Pointer<OggDecoder> decoder);
typedef OggClose = void Function(ffi.Pointer<OggDecoder> decoder);

/// FFI 函数绑定
class OggDecoderBindings {
  late final OggOpen oggOpen;
  late final OggReadSamples oggReadSamples;
  late final OggGetSampleRate oggGetSampleRate;
  late final OggGetChannels oggGetChannels;
  late final OggGetTotalSamples oggGetTotalSamples;
  late final OggClose oggClose;
  
  OggDecoderBindings() {
    final dylib = OggDecoderFFI.dylib;
    
    oggOpen = dylib
        .lookup<ffi.NativeFunction<OggOpenNative>>('ogg_open')
        .asFunction();
    
    oggReadSamples = dylib
        .lookup<ffi.NativeFunction<OggReadSamplesNative>>('ogg_read_samples')
        .asFunction();
    
    oggGetSampleRate = dylib
        .lookup<ffi.NativeFunction<OggGetSampleRateNative>>('ogg_get_sample_rate')
        .asFunction();
    
    oggGetChannels = dylib
        .lookup<ffi.NativeFunction<OggGetChannelsNative>>('ogg_get_channels')
        .asFunction();
    
    oggGetTotalSamples = dylib
        .lookup<ffi.NativeFunction<OggGetTotalSamplesNative>>('ogg_get_total_samples')
        .asFunction();
    
    oggClose = dylib
        .lookup<ffi.NativeFunction<OggCloseNative>>('ogg_close')
        .asFunction();
  }
}
