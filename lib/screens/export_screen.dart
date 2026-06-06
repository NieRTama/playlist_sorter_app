import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/export_service.dart';
import 'setup_screen.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  bool _exporting = false;
  Map<String, String>? _exportedPaths;
  final _exportService = ExportService();

  static const _colors = {
    SwipeDirection.up: Colors.blue,
    SwipeDirection.down: Colors.orange,
    SwipeDirection.left: Colors.purple,
    SwipeDirection.right: Colors.green,
  };

  static const _icons = {
    SwipeDirection.up: Icons.arrow_upward,
    SwipeDirection.down: Icons.arrow_downward,
    SwipeDirection.left: Icons.arrow_back,
    SwipeDirection.right: Icons.arrow_forward,
  };

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final playlists = appState.playlists;
    final config = appState.config;

    final nameMap = {
      SwipeDirection.up: config.up,
      SwipeDirection.down: config.down,
      SwipeDirection.left: config.left,
      SwipeDirection.right: config.right,
    };

    final total = playlists.values.fold<int>(0, (s, l) => s + l.length);

    return Scaffold(
      appBar: AppBar(
        title: const Text('エクスポート'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const SetupScreen()),
                (route) => false,
              );
            },
            child: const Text('ホームへ'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary card
          Card(
            color: Colors.green.withValues(alpha: 0.12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.green, size: 52),
                  const SizedBox(height: 12),
                  Text(
                    '$total曲の仕分けが完了！',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text('プレイリスト内訳',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),

          // Playlist breakdown
          ...SwipeDirection.values.map((dir) {
            final songs = playlists[dir] ?? [];
            final name = nameMap[dir]!;
            final color = _colors[dir]!;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.2),
                  child: Text(
                    songs.length.toString(),
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(name),
                subtitle: Text(
                  songs.isEmpty
                      ? '曲なし'
                      : songs.take(3).map((s) => s.title).join(', ') +
                          (songs.length > 3 ? '...' : ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Icon(_icons[dir], color: color),
              ),
            );
          }),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),

          Text('出力形式について',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _formatRow(context, 'M3U',
                    'Apple Music (Mac) でインポート可能。ローカルファイルのパスを含みます。'),
                const SizedBox(height: 8),
                _formatRow(context, 'CSV',
                    'スプレッドシートや各種ツールで利用可能。Spotify連携ツール (Soundiiz等) に対応。'),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Export result
          if (_exportedPaths != null) ...[
            Card(
              color: Colors.blue.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.folder_open, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text('保存先',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ..._exportedPaths!.entries.map((e) => GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: e.value));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('パスをコピーしました'),
                                  duration: Duration(seconds: 1)),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Icon(
                                  e.key.endsWith('_m3u')
                                      ? Icons.playlist_play
                                      : Icons.table_chart,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    e.value,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontFamily: 'monospace'),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              icon: _exporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.download_rounded),
              label: Text(_exportedPaths == null
                  ? 'すべてエクスポート (M3U + CSV)'
                  : '再エクスポート'),
              onPressed: _exporting ? null : () => _exportAll(appState),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _formatRow(BuildContext context, String format, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(format,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(desc,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
      ],
    );
  }

  Future<void> _exportAll(AppState appState) async {
    setState(() => _exporting = true);
    try {
      final paths = await _exportService.exportAll(
        appState.playlists,
        appState.config,
      );
      if (mounted) {
        setState(() => _exportedPaths = paths);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('エクスポートが完了しました ✓')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エクスポートに失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}
