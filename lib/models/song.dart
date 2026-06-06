import 'dart:typed_data';

class Song {
  final String path;
  final String title;
  final String artist;
  final String album;
  final int? durationMs;
  final Uint8List? bytes; // web only — not serialized
  final String? uri;     // iOS media library asset URL — not serialized

  const Song({
    required this.path,
    required this.title,
    this.artist = '',
    this.album = '',
    this.durationMs,
    this.bytes,
    this.uri,
  });

  String get filename {
    final parts = path.split(RegExp(r'[/\\]'));
    return parts.last;
  }

  String get mimeType {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'mp3':
        return 'audio/mpeg';
      case 'm4a':
        return 'audio/mp4';
      case 'flac':
        return 'audio/flac';
      case 'wav':
        return 'audio/wav';
      case 'aac':
        return 'audio/aac';
      case 'ogg':
      case 'opus':
        return 'audio/ogg';
      default:
        return 'audio/mpeg';
    }
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'title': title,
        'artist': artist,
        'album': album,
        'durationMs': durationMs,
      };

  factory Song.fromJson(Map<String, dynamic> json) => Song(
        path: json['path'] as String,
        title: json['title'] as String? ??
            (json['path'] as String).split('/').last,
        artist: json['artist'] as String? ?? '',
        album: json['album'] as String? ?? '',
        durationMs: json['durationMs'] as int?,
      );
}
