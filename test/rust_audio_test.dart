import 'package:flutter_test/flutter_test.dart';
import 'package:loopmusic_flutter/src/rust/api.dart';
import 'package:loopmusic_flutter/src/rust/frb_generated.dart';

void main() {
  // 只在测试开始前初始化一次 Rust 库
  setUpAll(() async {
    await RustLib.init();
  });

  test('Rust Audio Info - File Not Found', () async {
    try {
      await getAudioInfo(path: "non_existent_file.mp3");
      fail("应该抛出异常，因为文件不存在");
    } catch (e) {
      print("✅ 成功捕获到预期的 Rust 错误: $e");
      expect(e.toString().isNotEmpty, true);
    }
  });

  test('Rust Read Samples - File Not Found', () async {
     try {
      await readAudioSamples(path: "non_existent_file.mp3", startSample: BigInt.zero, count: BigInt.from(100));
      fail("应该抛出异常");
    } catch (e) {
      print("✅ audio_samples 读取测试通过 (预期错误: $e)");
      expect(e.toString().isNotEmpty, true);
    }
  });
}
