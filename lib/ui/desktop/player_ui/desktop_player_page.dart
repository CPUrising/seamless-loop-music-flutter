import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/audio/audio_player_state.dart';
import '../../../core/data/loop_config.dart';
import '../../../core/services/loop_matcher_service.dart';
import '../../../src/rust/api.dart' as rust_api;

/// 桌面端播放器主界面
class DesktopPlayerPage extends StatefulWidget {
  const DesktopPlayerPage({super.key});

  @override
  State<DesktopPlayerPage> createState() => _DesktopPlayerPageState();
}

class _DesktopPlayerPageState extends State<DesktopPlayerPage> {
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  final LoopMatcherService _matcherService = LoopMatcherService();
  String? _selectedFilePath;

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  /// 选择音频文件
  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final filePath = result.files.single.path!;
      final fileName = result.files.single.name;
      
      setState(() {
        _selectedFilePath = filePath;
      });

      // 加载文件
      await _loadAudioFile(filePath, fileName);
    }
  }

  /// 加载音频文件
  Future<void> _loadAudioFile(String filePath, String fileName) async {
    final playerState = context.read<AudioPlayerState>();

    try {
      // 检查是否已有配置
      var config = await playerState.findConfigByFilename(fileName);

      if (config == null) {
        // 使用 Rust 获取准确的元数据
        final info = await playerState.getAudioInfo(filePath);
        
        // 创建真实配置
        config = _createRealConfig(filePath, fileName, info);
        
        // 保存配置
        await playerState.addOrUpdateConfig(config);
      }

      // 加载并播放
      await playerState.loadAndPlay(filePath, config);

      // 更新输入框
      if (config.primaryLoop != null) {
        _startController.text = config.primaryLoop!.startSample.toString();
        _endController.text = config.primaryLoop!.endSample.toString();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已加载: $fileName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 创建真实配置（基于 Rust 获取的元数据）
  LoopConfig _createRealConfig(String filePath, String fileName, rust_api.SimpleAudioInfo info) {
    final sampleRate = info.sampleRate ?? 44100;
    final totalSamples = info.totalSamples?.toInt() ?? (sampleRate * 180);

    return LoopConfig(
      filename: fileName,
      filePath: filePath,
      title: info.title ?? fileName.replaceAll(RegExp(r'\.(mp3|wav|ogg|flac|m4a)$', caseSensitive: false), ''),
      artist: info.artist ?? 'Unknown',
      sampleRate: sampleRate,
      totalSamples: totalSamples,
      loops: [
        LoopPoint(
          startSample: 0,
          endSample: totalSamples,
          score: 1.0,
          isPrimary: true,
        ),
      ],
    );
  }

  /// 应用循环点并试听
  Future<void> _applyLoopPoints() async {
    final playerState = context.read<AudioPlayerState>();
    final currentConfig = playerState.currentConfig;

    if (currentConfig == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先加载音频文件'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 解析输入的循环点
    final startText = _startController.text.trim();
    final endText = _endController.text.trim();

    if (startText.isEmpty || endText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入循环点'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final startSample = int.tryParse(startText);
    final endSample = int.tryParse(endText);

    if (startSample == null || endSample == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('循环点必须是数字'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 验证循环点范围
    if (startSample < 0 || endSample > currentConfig.totalSamples) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('循环点超出范围 (0 - ${currentConfig.totalSamples})'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (startSample >= endSample) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('起点必须小于终点'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // 创建新的循环点
      final newLoop = LoopPoint(
        startSample: startSample,
        endSample: endSample,
        score: 1.0,
        isPrimary: true,
      );

      // 更新配置
      final updatedConfig = LoopConfig(
        filename: currentConfig.filename,
        filePath: currentConfig.filePath,
        title: currentConfig.title,
        artist: currentConfig.artist,
        sampleRate: currentConfig.sampleRate,
        totalSamples: currentConfig.totalSamples,
        loops: [newLoop], // 替换为新的循环点
      );

      // 保存配置
      await playerState.addOrUpdateConfig(updatedConfig);

      // 重新加载音频以应用新的循环点
      final filePath = currentConfig.filePath ?? currentConfig.filename;
      await playerState.loadAndPlay(filePath, updatedConfig);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('循环点已应用，开始试听'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('应用失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 运行智能匹配（人工算法）
  Future<void> _runSmartMatch() async {
    final playerState = context.read<AudioPlayerState>();
    final currentConfig = playerState.currentConfig;

    if (currentConfig == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先加载音频文件'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 获取当前循环点
    final currentLoop = currentConfig.primaryLoop;
    if (currentLoop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先设置初始循环点'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 显示加载对话框
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在分析循环点，请稍候...'),
                  SizedBox(height: 8),
                  Text(
                    '使用 SAD 算法匹配',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    try {
      // 获取文件路径
      final filePath = currentConfig.filePath ?? currentConfig.filename;

      // 调用匹配算法
      final (bestStart, bestEnd, score) = await _matcherService.findBestLoopPoints(
        filePath: filePath,
        currentStart: currentLoop.startSample,
        currentEnd: currentLoop.endSample,
        sampleRate: currentConfig.sampleRate,
      );

      // 关闭加载对话框
      if (mounted) {
        Navigator.of(context).pop();
      }

      // 更新输入框
      setState(() {
        _startController.text = bestStart.toString();
        _endController.text = bestEnd.toString();
      });

      // 创建新的循环点
      final newLoop = LoopPoint(
        startSample: bestStart,
        endSample: bestEnd,
        score: score,
        isPrimary: true,
      );

      // 更新配置
      final updatedConfig = LoopConfig(
        filename: currentConfig.filename,
        filePath: currentConfig.filePath,
        title: currentConfig.title,
        artist: currentConfig.artist,
        sampleRate: currentConfig.sampleRate,
        totalSamples: currentConfig.totalSamples,
        loops: [newLoop],
      );

      // 保存配置
      await playerState.addOrUpdateConfig(updatedConfig);

      // 重新加载音频
      await playerState.loadAndPlay(filePath, updatedConfig);

      if (mounted) {
        final shift = bestStart - currentLoop.startSample;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '智能匹配完成！\n'
              'Start: $bestStart (偏移 $shift)\n'
              'End: $bestEnd\n'
              'Score: ${score.toStringAsFixed(4)}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      // 关闭加载对话框
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('智能匹配失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: Row(
              children: [
                _buildFileList(),
                Expanded(child: _buildEditorPanel()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 顶部工具栏
  Widget _buildTopBar() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            const Icon(Icons.music_note, color: Colors.purple, size: 28),
            const SizedBox(width: 12),
            const Text(
              'Seamless Loop Music Player',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            _buildTopButton(
              icon: Icons.folder_open,
              label: '打开文件',
              onPressed: _pickAudioFile,
            ),
            const SizedBox(width: 12),
            _buildTopButton(
              icon: Icons.auto_fix_high,
              label: '智能匹配',
              onPressed: _runSmartMatch,
              // TODO: 以后集成 pymusiclooper
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// 左侧文件列表
  Widget _buildFileList() {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: Color(0xFF202020),
        border: Border(
          right: BorderSide(color: Color(0xFF333333), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '音乐库',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Consumer<AudioPlayerState>(
              builder: (context, playerState, child) {
                if (playerState.library.isEmpty) {
                  return const Center(
                    child: Text(
                      '暂无音乐\n请打开文件',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: playerState.library.length,
                  itemBuilder: (context, index) {
                    final config = playerState.library[index];
                    final isSelected = playerState.currentConfig == config;

                    return _buildFileItem(config, isSelected);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileItem(LoopConfig config, bool isSelected) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? Colors.purple.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isSelected
            ? Border.all(color: Colors.purple, width: 1)
            : null,
      ),
      child: ListTile(
        leading: Icon(
          Icons.music_note,
          color: isSelected ? Colors.purple : Colors.grey,
        ),
        title: Text(
          config.title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[300],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          config.artist,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () async {
          // 从库中加载并播放
          final playerState = context.read<AudioPlayerState>();
          
          // 使用保存的完整路径，如果没有则使用 filename
          final path = config.filePath ?? config.filename;
          
          try {
            await playerState.loadAndPlay(path, config);
            
            // 更新输入框
            if (config.primaryLoop != null) {
              setState(() {
                _startController.text = config.primaryLoop!.startSample.toString();
                _endController.text = config.primaryLoop!.endSample.toString();
              });
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('加载失败: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  /// 右侧编辑面板
  Widget _buildEditorPanel() {
    return Consumer<AudioPlayerState>(
      builder: (context, playerState, child) {
        return Container(
          color: const Color(0xFF1A1A1A),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('当前文件'),
                      const SizedBox(height: 12),
                      _buildFileInfoCard(playerState),
                      const SizedBox(height: 32),
                      _buildSectionTitle('循环点设置'),
                      const SizedBox(height: 12),
                      _buildLoopPointEditor(playerState),
                      const SizedBox(height: 32),
                      _buildSectionTitle('播放控制'),
                      const SizedBox(height: 12),
                      _buildPlaybackControls(playerState),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildFileInfoCard(AudioPlayerState playerState) {
    final config = playerState.currentConfig;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (config != null) ...[
            _buildInfoRow('标题', config.title),
            const SizedBox(height: 8),
            _buildInfoRow('艺术家', config.artist),
            const SizedBox(height: 8),
            _buildInfoRow('采样率', '${config.sampleRate} Hz'),
            const SizedBox(height: 8),
            _buildInfoRow('总采样数', config.totalSamples.toString()),
          ] else ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  '未加载文件',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildLoopPointEditor(AudioPlayerState playerState) {
    final loop = playerState.currentLoop;
    final config = playerState.currentConfig;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        children: [
          _buildLoopPointInput(
            label: 'Loop Start (采样点)',
            controller: _startController,
            hintText: loop?.startSample.toString() ?? '0',
            icon: Icons.play_arrow,
          ),
          const SizedBox(height: 16),
          _buildLoopPointInput(
            label: 'Loop End (采样点)',
            controller: _endController,
            hintText: loop?.endSample.toString() ?? config?.totalSamples.toString() ?? '0',
            icon: Icons.stop,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _applyLoopPoints,
                  icon: const Icon(Icons.check),
                  label: const Text('应用并试听'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoopPointInput({
    required String label,
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.purple, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey[600]),
            filled: true,
            fillColor: const Color(0xFF1A1A1A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF333333)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF333333)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.purple, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaybackControls(AudioPlayerState playerState) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        children: [
          // 进度条
          Column(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.purple,
                  inactiveTrackColor: const Color(0xFF333333),
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
                padding: const EdgeInsets.symmetric(horizontal: 12),
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
          const SizedBox(height: 20),
          // 播放按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildControlButton(
                icon: Icons.skip_previous,
                onPressed: () {},
              ),
              const SizedBox(width: 16),
              Container(
                width: 64,
                height: 64,
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
                    size: 32,
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
              const SizedBox(width: 16),
              _buildControlButton(
                icon: Icons.skip_next,
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF333333),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
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
