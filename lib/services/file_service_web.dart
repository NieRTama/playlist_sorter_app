// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
// NOTE: Uses dart:html (deprecated). A migration to package:web + dart:js_interop
// is pending; deferred until it can be verified against a real web build.
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import '../models/song.dart';

Future<List<Song>?> pickFilesWeb() async {
  final input = html.FileUploadInputElement();
  input.multiple = true;
  input.attributes['webkitdirectory'] = '';
  input.accept = '.mp3,.m4a,.flac,.wav,.aac,.ogg,.opus,.wma,audio/*';

  input.click();
  await input.onChange.first;
  final files = input.files;
  if (files == null || files.isEmpty) return null;

  final songs = <Song>[];
  for (final f in files) {
    try {
      final reader = html.FileReader();
      reader.readAsArrayBuffer(f);
      await reader.onLoad.first;
      final result = reader.result;
      if (result is ByteBuffer) {
        final bytes = Uint8List.view(result);
        final name = (f as dynamic).webkitRelativePath ?? f.name;
        final title = name.contains('.')
            ? name.substring(0, name.lastIndexOf('.'))
            : name;
        songs.add(Song(path: name, title: title, bytes: bytes));
      }
    } catch (_) {
      // ignore read errors per-file
    }
  }

  songs.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  return songs;
}

Stream<List<Song>> pickFilesWebBatches({int batchSize = 100}) async* {
  final input = html.FileUploadInputElement();
  input.multiple = true;
  input.attributes['webkitdirectory'] = '';
  input.accept = '.mp3,.m4a,.flac,.wav,.aac,.ogg,.opus,.wma,audio/*';

  input.click();
  await input.onChange.first;
  final files = input.files;
  if (files == null || files.isEmpty) return;

  final sortedFiles = files.toList()
    ..sort((a, b) {
      final aName = (a as dynamic).webkitRelativePath ?? a.name;
      final bName = (b as dynamic).webkitRelativePath ?? b.name;
      return aName.toLowerCase().compareTo(bName.toLowerCase());
    });

  final batch = <Song>[];
  for (final f in sortedFiles) {
    try {
      final reader = html.FileReader();
      reader.readAsArrayBuffer(f);
      await reader.onLoad.first;
      final result = reader.result;
      if (result is ByteBuffer) {
        final bytes = Uint8List.view(result);
        final name = (f as dynamic).webkitRelativePath ?? f.name;
        final title = name.contains('.')
            ? name.substring(0, name.lastIndexOf('.'))
            : name;
        batch.add(Song(path: name, title: title, bytes: bytes));
      }
    } catch (_) {
      // ignore read errors per-file
    }

    if (batch.length >= batchSize) {
      yield List.unmodifiable(batch);
      batch.clear();
    }
  }
  if (batch.isNotEmpty) {
    yield List.unmodifiable(batch);
  }
}
