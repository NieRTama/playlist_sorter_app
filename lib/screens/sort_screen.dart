import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/audio_service.dart';
import '../widgets/swipe_card.dart';
import '../widgets/direction_labels.dart';
import 'export_screen.dart';
import 'setup_screen.dart';

class SortScreen extends StatefulWidget {
  final AudioService audioService;

  const SortScreen({super.key, required this.audioService});

  @override
  State<SortScreen> createState() => _SortScreenState();
}

class _SortScreenState extends State<SortScreen> {
  SwipeDirection? _hintDirection;

  @override
  void initState() {
    super.initState();
    _playCurrentSong();
  }

  @override
  void dispose() {
    widget.audioService.dispose();
    super.dispose();
  }

  Future<void> _playCurrentSong() async {
    final song = context.read<AppState>().currentSong;
    if (song != null) {
      await widget.audioService.playPreview(
        song.path,
        bytes: song.bytes,
        mimeType: song.mimeType,
        uri: song.uri,
      );
    }
  }

  void _onDirectionChanged(SwipeDirection? dir) {
    if (dir != _hintDirection) {
      setState(() => _hintDirection = dir);
    }
  }

  Future<void> _onSwiped(SwipeDirection direction) async {
    final appState = context.read<AppState>();
    appState.swipe(direction);
    setState(() => _hintDirection = null);

    if (appState.isComplete) {
      await widget.audioService.stop();
      await appState.saveState();
      if (!mounted) return;
      _goToExport();
      return;
    }

    // Start next preview immediately
    await _playCurrentSong();

    // Checkpoint dialog (audio plays in background)
    if (appState.needsCheckpoint && mounted) {
      appState.acknowledgeCheckpoint();
      final cont = await _showCheckpointDialog(appState, context);
      if (!cont && mounted) {
        await widget.audioService.stop();
        if (!mounted) return;
        _goToExport();
      }
    }
  }

  void _goToExport() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ExportScreen()),
    );
  }

  void _openExport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ExportScreen()),
    );
  }

  void _goHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SetupScreen()),
      (route) => false,
    );
  }

  Future<bool> _showCheckpointDialog(AppState appState, BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('チェックポイント 💾'),
            content: Text(
              '${appState.processedCount}曲の仕分けが完了しました！\n'
              '残り${appState.totalCount - appState.processedCount}曲あります。\n\n'
              '続けますか？',
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('今すぐエクスポート'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('続ける'),
              ),
            ],
          ),
        ) ??
        true;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await widget.audioService.stop();
            await appState.saveState();
            if (!mounted) return;
            _goHome();
          },
        ),
        title: Column(
          children: [
            Text(
              '${appState.processedCount} / ${appState.totalCount}',
              style: const TextStyle(fontSize: 15),
            ),
            Text(
              '${(appState.progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up),
            tooltip: '音量',
            onPressed: () async {
              final currentContext = context;
              final initial = widget.audioService.volume;
              await showDialog<void>(
                context: currentContext,
                builder: (ctx) {
                  var tmp = initial;
                  return AlertDialog(
                    title: const Text('音量'),
                    content: StatefulBuilder(
                      builder: (c, setState) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Slider(
                            value: tmp,
                            min: 0.0,
                            max: 1.0,
                            divisions: 100,
                            label: '${(tmp * 100).toStringAsFixed(0)}%',
                            onChanged: (v) {
                              setState(() => tmp = v);
                              widget.audioService.setVolume(v);
                            },
                          ),
                          Text('${(tmp * 100).toStringAsFixed(0)}%'),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('閉じる'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: '途中でエクスポート',
            onPressed: () async {
              await widget.audioService.stop();
              if (!mounted) return;
              _openExport();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: appState.progress,
            minHeight: 3,
            backgroundColor: Colors.white12,
          ),
          if (appState.isLoadingMoreSongs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                '残りの曲を読み込み中…',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white70),
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                // Background direction labels
                DirectionLabels(
                  config: appState.config,
                  highlighted: _hintDirection,
                ),

                // Song card
                if (appState.currentSong != null)
                  Center(
                    child: SwipeCard(
                      key: ValueKey(appState.currentIndex),
                      song: appState.currentSong!,
                      config: appState.config,
                      onSwiped: _onSwiped,
                      onReplay: _playCurrentSong,
                      onDirectionChanged: _onDirectionChanged,
                    ),
                  )
                else if (!appState.isComplete)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
