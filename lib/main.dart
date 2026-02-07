import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/audio/audio_player_state.dart';
import 'ui/mobile/player_page/mobile_player_page.dart';
import 'ui/desktop/player_ui/desktop_player_page.dart';

void main() {
  runApp(const LoopMusicApp());
}

class LoopMusicApp extends StatelessWidget {
  const LoopMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AudioPlayerState(),
      child: MaterialApp(
        title: 'Seamless Loop Music',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.purple,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: _buildPlatformHome(),
      ),
    );
  }

  /// 根据平台加载不同的界面
  Widget _buildPlatformHome() {
    if (Platform.isAndroid || Platform.isIOS) {
      // 移动端：纯粹播放界面
      return const MobilePlayerPage();
    } else {
      // 桌面端：完整功能界面
      return const DesktopPlayerPage();
    }
  }
}
