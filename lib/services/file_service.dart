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

  Future<List<Song>> _loadFromDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    final songs = <Song>[];

    try {
      await for (final entity
          in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final lowerPath = entity.path.toLowerCase();
          if (_audioExtensions.any((ext) => lowerPath.endsWith(ext))) {
            songs.add(_songFromPath(entity.path));
          }
        }
      }
    } catch (_) {
      // Permission denied or SAF URI — return whatever we collected
    }

    songs.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return songs;
  }

  Stream<List<Song>> _loadFromDirectoryBatches(String dirPath,
      {int batchSize = 100}) async* {
    final dir = Directory(dirPath);
    final paths = <String>[];

    try {
      await for (final entity
          in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final lowerPath = entity.path.toLowerCase();
          if (_audioExtensions.any((ext) => lowerPath.endsWith(ext))) {
            paths.add(entity.path);
          }
        }
      }
    } catch (_) {
      // Permission denied or SAF URI — continue with what we have
    }

    paths.sort((a, b) {
      final aTitle = _songFromPath(a).title.toLowerCase();
      final bTitle = _songFromPath(b).title.toLowerCase();
      return aTitle.compareTo(bTitle);
    });

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

  Song _songFromPath(String path) {
    final filename = path.split(RegExp(r'[/\\]')).last;
    final title = filename.contains('.')
        ? filename.substring(0, filename.lastIndexOf('.'))
        : filename;
    return Song(path: path, title: title);
  }

  Future<bool> _canAccessDirectory(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      return await dir.exists();
    } catch (_) {
      return false;
    }
  }

  Future<List<Song>?> _pickFilesFromDialog() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
        'mp3', 'm4a', 'flac', 'wav', 'aac', 'ogg', 'opus', 'wma'
      ],
      withData: false,
    );
    if (result == null) return null;
    final songs = result.paths.whereType<String>().map((path) {
      return _songFromPath(path);
    }).toList();
    songs.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return songs;
  }

  Stream<List<Song>> _pickFilesFromDialogBatches({int batchSize = 100}) async* {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
        'mp3', 'm4a', 'flac', 'wav', 'aac', 'ogg', 'opus', 'wma'
      ],
      withData: false,
    );
    if (result == null) return;

    final paths = result.paths.whereType<String>().toList()
      ..sort((a, b) {
        final aTitle = _songFromPath(a).title.toLowerCase();
        final bTitle = _songFromPath(b).title.toLowerCase();
        return aTitle.compareTo(bTitle);
      });

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
}
