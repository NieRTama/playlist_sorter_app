import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/app_state.dart';
import '../models/playlist_config.dart';
import '../services/file_service.dart';
import '../services/audio_service.dart';
import 'sort_screen.dart';
import 'export_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  bool _loading = false;
  final _fileService = FileService();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (!appState.initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.queue_music_rounded,
                  size: 80, color: Color(0xFF6C63FF)),
              const SizedBox(height: 16),
              Text(
                'Playlist Sorter',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'スワイプで曲を仕分けよう',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Resume card
              if (appState.hasSession && !appState.isComplete) ...[
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.history_rounded,
                                size: 18, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text('前回の続き',
                                style:
                                    Theme.of(context).textTheme.titleSmall),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: appState.progress,
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${appState.processedCount} / ${appState.totalCount} 曲完了'
                          '  (${(appState.progress * 100).toStringAsFixed(0)}%)',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('続きから再開'),
                            onPressed: () => _resumeSession(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Completed session
              if (appState.hasSession && appState.isComplete) ...[
                Card(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: Colors.green, size: 36),
                        const SizedBox(height: 8),
                        const Text('前回のセッションが完了しています'),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            icon: const Icon(Icons.download_rounded),
                            label: const Text('結果をエクスポート'),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ExportScreen()),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // New session button
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.folder_open_rounded),
                  label: Text(appState.hasSession
                      ? '新しいセッションを開始'
                          : kIsWeb
                          ? 'フォルダを選択して開始'
                          : defaultTargetPlatform == TargetPlatform.iOS
                              ? 'ミュージックライブラリから読み込む'
                              : 'フォルダを選択して開始'),
                  onPressed: _loading ? null : () => _startNew(context),
                ),
              ),
              const SizedBox(height: 12),

              // Settings
              TextButton.icon(
                icon: const Icon(Icons.tune_rounded),
                label: const Text('プレイリスト設定'),
                onPressed: () => _showSettings(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startNew(BuildContext context) async {
    final appState = context.read<AppState>();

    if (appState.hasSession) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('新しいセッション'),
          content: const Text('現在のセッションデータが失われます。続けますか？'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('キャンセル')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('開始する')),
          ],
        ),
      );
      if (confirmed != true) return;
      await appState.clearSession();
    }

    setState(() => _loading = true);
    try {
      final batchStream = await _fileService.pickFolderAndLoadSongsInBatches();
      if (!mounted) return;
      if (batchStream == null) return; // cancelled

      final iterator = StreamIterator<List<Song>>(batchStream);
      if (!await iterator.moveNext()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(kIsWeb
                ? '音楽ファイルが選択されませんでした'
                : defaultTargetPlatform == TargetPlatform.iOS
                    ? 'ミュージックライブラリに曲が見つかりませんでした'
                    : '音楽ファイルが見つかりませんでした'),
          ),
        );
        return;
      }

      appState.startSession(iterator.current);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => SortScreen(audioService: AudioService())),
        );
      }

      if (await iterator.moveNext()) {
        appState.setLoadingMoreSongs(true);
        appState.appendSongs(iterator.current);
        while (await iterator.moveNext()) {
          appState.appendSongs(iterator.current);
        }
        appState.setLoadingMoreSongs(false);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _resumeSession(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => SortScreen(audioService: AudioService())),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _SettingsSheet(),
    );
  }
}

// ─── Settings bottom sheet ────────────────────────────────────────────────────

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet();

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late TextEditingController _up, _down, _left, _right;

  @override
  void initState() {
    super.initState();
    final c = context.read<AppState>().config;
    _up = TextEditingController(text: c.up);
    _down = TextEditingController(text: c.down);
    _left = TextEditingController(text: c.left);
    _right = TextEditingController(text: c.right);
  }

  @override
  void dispose() {
    _up.dispose();
    _down.dispose();
    _left.dispose();
    _right.dispose();
    super.dispose();
  }

  void _applyPreset(PlaylistConfig h) {
    setState(() {
      _up.text = h.up;
      _down.text = h.down;
      _left.text = h.left;
      _right.text = h.right;
    });
  }

  void _save() {
    final appState = context.read<AppState>();
    appState.updateConfig(appState.config.copyWith(
      up: _up.text.trim().isEmpty ? '↑' : _up.text.trim(),
      down: _down.text.trim().isEmpty ? '↓' : _down.text.trim(),
      left: _left.text.trim().isEmpty ? '←' : _left.text.trim(),
      right: _right.text.trim().isEmpty ? '→' : _right.text.trim(),
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('プレイリスト設定',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 4),
            Text('スワイプ方向ごとにプレイリスト名を設定',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey)),
            const SizedBox(height: 20),

            _input(Icons.arrow_upward, '上スワイプ', _up, Colors.blue),
            const SizedBox(height: 10),
            _input(Icons.arrow_downward, '下スワイプ', _down, Colors.orange),
            const SizedBox(height: 10),
            _input(Icons.arrow_back, '左スワイプ', _left, Colors.purple),
            const SizedBox(height: 10),
            _input(Icons.arrow_forward, '右スワイプ', _right, Colors.green),

            // History
            if (appState.configHistory.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('過去の設定',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: appState.configHistory.map((h) {
                  return ActionChip(
                    label: Text(
                      '${h.up} / ${h.right} / ${h.down} / ${h.left}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    avatar: const Icon(Icons.history, size: 14),
                    onPressed: () => _applyPreset(h),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                  onPressed: _save, child: const Text('保存')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _input(IconData icon, String label, TextEditingController ctrl,
      Color color) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: color, size: 20),
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
