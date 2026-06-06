import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/song.dart';
import '../models/playlist_config.dart';
import '../providers/app_state.dart';
import 'web_helpers.dart';

class ExportService {
  Future<Map<String, String>> exportAll(
    Map<SwipeDirection, List<Song>> playlists,
    PlaylistConfig config,
  ) async {
    final nameMap = {
      SwipeDirection.up: config.up,
      SwipeDirection.down: config.down,
      SwipeDirection.left: config.left,
      SwipeDirection.right: config.right,
    };

    if (kIsWeb) {
      return _exportWeb(playlists, nameMap);
    }

    final baseDir = await _resolveExportDir();
    final paths = <String, String>{};

    for (final entry in playlists.entries) {
      if (entry.value.isEmpty) continue;
      final name = nameMap[entry.key]!;
      final safe = _safeName(name);

      final m3u = File('$baseDir/$safe.m3u');
      await _writeM3u(entry.value, m3u, name);
      paths['${name}_m3u'] = m3u.path;

      final csv = File('$baseDir/$safe.csv');
      await _writeCsv(entry.value, csv);
      paths['${name}_csv'] = csv.path;
    }

    return paths;
  }

  Map<String, String> _exportWeb(
    Map<SwipeDirection, List<Song>> playlists,
    Map<SwipeDirection, String> nameMap,
  ) {
    final paths = <String, String>{};

    for (final entry in playlists.entries) {
      if (entry.value.isEmpty) continue;
      final name = nameMap[entry.key]!;
      final safe = _safeName(name);

      final m3uContent = _buildM3uString(entry.value, name);
      downloadFileWeb('$safe.m3u', m3uContent);
      paths['${name}_m3u'] = '$safe.m3u';

      final csvContent = _buildCsvString(entry.value);
      downloadFileWeb('$safe.csv', csvContent);
      paths['${name}_csv'] = '$safe.csv';
    }

    return paths;
  }

  Future<String> _resolveExportDir() async {
    Directory dir;
    if (Platform.isAndroid) {
      dir = Directory('/storage/emulated/0/Download/PlaylistSorter');
    } else {
      final docs = await getApplicationDocumentsDirectory();
      dir = Directory('${docs.path}/PlaylistSorter');
    }
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  Future<void> _writeM3u(List<Song> songs, File file, String name) async {
    await file.writeAsString(_buildM3uString(songs, name), flush: true);
  }

  Future<void> _writeCsv(List<Song> songs, File file) async {
    await file.writeAsString(_buildCsvString(songs), flush: true);
  }

  String _buildM3uString(List<Song> songs, String name) {
    final buf = StringBuffer()
      ..writeln('#EXTM3U')
      ..writeln('#PLAYLIST:$name');
    for (final s in songs) {
      final dur = s.durationMs != null ? s.durationMs! ~/ 1000 : -1;
      final label = s.artist.isNotEmpty ? '${s.artist} - ${s.title}' : s.title;
      buf
        ..writeln('#EXTINF:$dur,$label')
        ..writeln(s.path);
    }
    return buf.toString();
  }

  String _buildCsvString(List<Song> songs) {
    final buf = StringBuffer()
      ..writeln('Title,Artist,Album,DurationMs,FilePath');
    for (final s in songs) {
      buf.writeln(
        '"${_esc(s.title)}","${_esc(s.artist)}","${_esc(s.album)}",'
        '${s.durationMs ?? ''},"${_esc(s.path)}"',
      );
    }
    return buf.toString();
  }

  String _safeName(String name) =>
      name.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');

  String _esc(String s) => s.replaceAll('"', '""');
}
