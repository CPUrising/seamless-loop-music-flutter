import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:loopmusic_flutter/core/services/mp3_reader.dart';
import 'package:loopmusic_flutter/core/services/mp3_reader_ffi.dart';

/// MP3 读取器性能对比测试
/// 
/// 对比 ffmpeg 方案和 FFI + minimp3 方案的性能差异
void main() {
  // 注意：需要准备一个测试用的 MP3 文件
  const testMp3Path = 'D:/test.mp3';  // 请修改为实际的 MP3 文件路径
  
  test('MP3 Reader FFI vs ffmpeg 性能对比', () async {
    // 检查测试文件是否存在
    if (!await File(testMp3Path).exists()) {
      print('⚠️ 测试文件不存在: $testMp3Path');
      print('请修改 testMp3Path 为实际的 MP3 文件路径');
      return;
    }
    
    print('📊 开始性能对比测试...\n');
    
    // ========== FFI 方案测试 ==========
    print('🚀 测试 FFI + minimp3 方案:');
    
    if (Mp3ReaderFFI.isFFIAvailable()) {
      final ffiReader = Mp3ReaderFFI(testMp3Path);
      
      // 解析头部
      final ffiHeaderStart = DateTime.now();
      await ffiReader.parseHeader();
      final ffiHeaderTime = DateTime.now().difference(ffiHeaderStart);
      
      print('   - 采样率: ${ffiReader.sampleRate} Hz');
      print('   - 声道数: ${ffiReader.channels}');
      print('   - 总采样数: ${ffiReader.totalSamples}');
      print('   - 解析头部耗时: ${ffiHeaderTime.inMilliseconds} ms');
      
      // 读取 1 秒音频
      final ffiRead1Start = DateTime.now();
      await ffiReader.readSamples(0, ffiReader.sampleRate);
      final ffiRead1Time = DateTime.now().difference(ffiRead1Start);
      print('   - 读取 1 秒音频耗时: ${ffiRead1Time.inMilliseconds} ms');
      
      // 读取 4 秒音频
      final ffiRead4Start = DateTime.now();
      await ffiReader.readSamples(0, ffiReader.sampleRate * 4);
      final ffiRead4Time = DateTime.now().difference(ffiRead4Start);
      print('   - 读取 4 秒音频耗时: ${ffiRead4Time.inMilliseconds} ms');
      
      ffiReader.dispose();
      print('   ✅ FFI 方案测试完成\n');
    } else {
      print('   ❌ FFI 库不可用\n');
    }
    
    // ========== ffmpeg 方案测试 ==========
    print('🐢 测试 ffmpeg 方案:');
    
    if (await Mp3Reader.isFFmpegAvailable()) {
      final ffmpegReader = Mp3Reader(testMp3Path);
      
      // 解析头部
      final ffmpegHeaderStart = DateTime.now();
      await ffmpegReader.parseHeader();
      final ffmpegHeaderTime = DateTime.now().difference(ffmpegHeaderStart);
      
      print('   - 采样率: ${ffmpegReader.sampleRate} Hz');
      print('   - 声道数: ${ffmpegReader.channels}');
      print('   - 总采样数: ${ffmpegReader.totalSamples}');
      print('   - 解析头部耗时: ${ffmpegHeaderTime.inMilliseconds} ms');
      
      // 读取 1 秒音频
      final ffmpegRead1Start = DateTime.now();
      await ffmpegReader.readSamples(0, ffmpegReader.sampleRate);
      final ffmpegRead1Time = DateTime.now().difference(ffmpegRead1Start);
      print('   - 读取 1 秒音频耗时: ${ffmpegRead1Time.inMilliseconds} ms');
      
      // 读取 4 秒音频
      final ffmpegRead4Start = DateTime.now();
      await ffmpegReader.readSamples(0, ffmpegReader.sampleRate * 4);
      final ffmpegRead4Time = DateTime.now().difference(ffmpegRead4Start);
      print('   - 读取 4 秒音频耗时: ${ffmpegRead4Time.inMilliseconds} ms');
      
      print('   ✅ ffmpeg 方案测试完成\n');
    } else {
      print('   ❌ ffmpeg 不可用\n');
    }
    
    print('📊 性能对比测试完成!');
  });
}
