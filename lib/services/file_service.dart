import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../models/song.dart';
import 'media_library_service.dart';
import 'file_service_io.dart' if (dart.library.html) 'file_service_web.dart';

class FileService {
  static const _audioExtensions = {
    '.mp3', '.m4a', '.flac', '.wav', '.aac', '.ogg', '.opus', '.wma',
  };

  /// Same extensions without the leading dot, for FilePicker's allowedExtensions.
  static final _pickerExtensions =
      _audioExtensions.map((e) => e.substring(1)).toList();

  Future<List<Song>?> pickFolderAndLoadSongs() async {
    if (kIsWeb) {
      return _pickFilesWeb();
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return loadFromMusicLibrary();
    }
    final dirPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '音楽フォルダを選択してください',
    );
    if (dirPath == null || dirPath.isEmpty) {
      return _pickFilesFromDialog();
    }

    if (!await _canAccessDirectory(dirPath)) {
      return _pickFilesFromDialog();
    }
    return _loadFromDirectory(dirPath);
  }

  Future<Stream<List<Song>>?> pickFolderAndLoadSongsInBatches({int batchSize = 100}) async {
    if (kIsWeb) {
      return _pickFilesWebBatches(batchSize: batchSize);
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final songs = await loadFromMusicLibrary();
      if (songs == null) return null;
      return Stream.fromIterable(
        List.generate(
          (songs.length + batchSize - 1) ~/ batchSize,
          (index) {
            final start = index * batchSize;
            final end = start + batchSize > songs.length
                ? songs.length
                : start + batchSize;
            return songs.sublist(start, end);
          },
        ),
      );
    }
    final dirPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '音楽フォルダを選択してください',
    );
    if (dirPath == null || dirPath.isEmpty) {
      return _pickFilesFromDialogBatches(batchSize: batchSize);
    }

    if (!await _canAccessDirectory(dirPath)) {
      return _pickFilesFromDialogBatches(batchSize: batchSize);
    }
    return _loadFromDirectoryBatches(dirPath, batchSize: batchSize);
  }

  Future<List<Song>?> _pickFilesWeb() => pickFilesWeb();
  Stream<List<Song>> _pickFilesWebBatches({int batchSize = 100}) =>
      pickFilesWebBatches(batchSize: batchSize);

  /// Recursively collects audio file paths under [dirPath]. Returns whatever
  /// was gathered if scanning is interrupted (permission denied / SAF URI).
  Future<List<String>> _collectAudioPaths(String dirPath) async {
    final paths = <String>[];
    try {
      await for (final entity
          in Directory(dirPath).list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final lowerPath = entity.path.toLowerCase();
          if (_audioExtensions.any((ext) => lowerPath.endsWith(ext))) {
            paths.add(entity.path);
          }
        }
      }
    } catch (_) {
      // Permission denied or SAF URI — return whatever we collected.
    }
    return paths;
  }

  /// Sorts [paths] by title and maps them to [Song]s.
  List<Song> _toSortedSongs(List<String> paths) {
    paths.sort((a, b) => _titleKey(a).compareTo(_titleKey(b)));
    return paths.map(_songFromPath).toList();
  }

  /// Sorts [paths] by title and yields [Song]s in chunks of [batchSize].
  Stream<List<Song>> _batchify(List<String> paths, int batchSize) async* {
    paths.sort((a, b) => _titleKey(a).compareTo(_titleKey(b)));
    var batch = <Song>[];
    for (final path in paths) {
      batch.add(_songFromPath(path));
      if (batch.length >= batchSize) {
        yield List.unmodifiable(batch);
        batch = <Song>[];
      }
    }
    if (batch.isNotEmpty) {
      yield List.unmodifiable(batch);
    }
  }

  Future<List<Song>> _loadFromDirectory(String dirPath) async =>
      _toSortedSongs(await _collectAudioPaths(dirPath));

  Stream<List<Song>> _loadFromDirectoryBatches(String dirPath,
      {int batchSize = 100}) async* {
    yield* _batchify(await _collectAudioPaths(dirPath), batchSize);
  }

  Song _songFromPath(String path) {
    final filename = path.split(RegExp(r'[/\\]')).last;
    final title = filename.contains('.')
        ? filename.substring(0, filename.lastIndexOf('.'))
        : filename;
    return Song(path: path, title: title);
  }

  String _titleKey(String path) {
    final filename = path.split(RegExp(r'[/\\]')).last;
    final dot = filename.lastIndexOf('.');
    return (dot > 0 ? filename.substring(0, dot) : filename).toLowerCase();
  }

  Future<bool> _canAccessDirectory(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      return await dir.exists();
    } catch (_) {
      return false;
    }
  }

  Future<FilePickerResult?> _pickAudioFiles() => FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: _pickerExtensions,
        withData: false,
      );

  Future<List<Song>?> _pickFilesFromDialog() async {
    final result = await _pickAudioFiles();
    if (result == null) return null;
    return _toSortedSongs(result.paths.whereType<String>().toList());
  }

  Stream<List<Song>> _pickFilesFromDialogBatches({int batchSize = 100}) async* {
    final result = await _pickAudioFiles();
    if (result == null) return;
    yield* _batchify(result.paths.whereType<String>().toList(), batchSize);
  }
}
