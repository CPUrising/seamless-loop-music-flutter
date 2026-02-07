import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/audio/audio_player_state.dart';

/// 移动端播放页面
class MobilePlayerPage extends StatelessWidget {
  const MobilePlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Consumer<AudioPlayerState>(
          builder: (context, playerState, child) {
            final config = playerState.currentConfig;
            
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                
                // 封面
                Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.music_note,
                    size: 120,
                    color: Colors.white24,
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // 歌曲信息
                Text(
                  config?.title ?? 'No Track',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  config?.artist ?? '',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 16,
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // 进度条
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.purple,
                          inactiveTrackColor: Colors.grey[800],
                          thumbColor: Colors.purple,
                          overlayColor: Colors.purple.withOpacity(0.2),
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: playerState.currentPosition.inMilliseconds.toDouble(),
                          max: playerState.totalDuration.inMilliseconds.toDouble().clamp(1, double.infinity),
                          onChanged: (value) {
                            playerState.seek(Duration(milliseconds: value.toInt()));
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(playerState.currentPosition),
                              style: TextStyle(color: Colors.grey[400], fontSize: 12),
                            ),
                            Text(
                              _formatDuration(playerState.totalDuration),
                              style: TextStyle(color: Colors.grey[400], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // 播放控制
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous),
                      iconSize: 48,
                      color: Colors.white,
                      onPressed: () {},
                    ),
                    const SizedBox(width: 20),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Colors.purple, Colors.deepPurple],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purple.withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          playerState.isPlaying ? Icons.pause : Icons.play_arrow,
                          size: 40,
                        ),
                        color: Colors.white,
                        onPressed: () {
                          if (playerState.isPlaying) {
                            playerState.pause();
                          } else {
                            playerState.play();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 20),
                    IconButton(
                      icon: const Icon(Icons.skip_next),
                      iconSize: 48,
                      color: Colors.white,
                      onPressed: () {},
                    ),
                  ],
                ),
                
                const Spacer(),
                
                // 循环标识
                if (config?.primaryLoop != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.repeat, color: Colors.purple, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Seamless Loop Active',
                          style: TextStyle(color: Colors.purple[200], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 40),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
