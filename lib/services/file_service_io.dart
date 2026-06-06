import 'package:file_picker/file_picker.dart';
import '../models/song.dart';

// Fallback implementation used when not running on web.
Future<List<Song>?> pickFilesWeb() async {
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: true,
    type: FileType.custom,
    allowedExtensions: const [
      'mp3', 'm4a', 'flac', 'wav', 'aac', 'ogg', 'opus', 'wma'
    ],
    withData: true,
  );
  if (result == null) return null;
  final songs = result.files.map((f) {
    final name = f.name;
    final title = name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name;
    return Song(path: name, title: title, bytes: f.bytes);
  }).toList();
  songs.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  return songs;
}

Stream<List<Song>> pickFilesWebBatches({int batchSize = 100}) async* {
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: true,
    type: FileType.custom,
    allowedExtensions: const [
      'mp3', 'm4a', 'flac', 'wav', 'aac', 'ogg', 'opus', 'wma'
    ],
    withData: true,
  );
  if (result == null) return;

  final files = result.files.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  final batch = <Song>[];
  for (final f in files) {
    final name = f.name;
    final title = name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name;
    batch.add(Song(path: name, title: title, bytes: f.bytes));
    if (batch.length >= batchSize) {
      yield List.unmodifiable(batch);
      batch.clear();
    }
  }
  if (batch.isNotEmpty) {
    yield List.unmodifiable(batch);
  }
}
