// Unit tests for the Playlist Sorter app's core logic.

import 'package:flutter_test/flutter_test.dart';
import 'package:playlist_sorter/models/song.dart';
import 'package:playlist_sorter/models/playlist_config.dart';

void main() {
  group('Song', () {
    test('round-trips through JSON (excluding runtime-only fields)', () {
      const song = Song(
        path: '/music/track.mp3',
        title: 'Track',
        artist: 'Artist',
        album: 'Album',
        durationMs: 123000,
      );
      final restored = Song.fromJson(song.toJson());
      expect(restored.path, song.path);
      expect(restored.title, song.title);
      expect(restored.artist, song.artist);
      expect(restored.album, song.album);
      expect(restored.durationMs, song.durationMs);
    });

    test('fromJson falls back to filename when title missing', () {
      final song = Song.fromJson({'path': '/music/My Song.flac'});
      expect(song.title, 'My Song.flac');
      expect(song.artist, '');
    });

    test('mimeType maps known extensions', () {
      expect(const Song(path: 'a.mp3', title: 'a').mimeType, 'audio/mpeg');
      expect(const Song(path: 'a.flac', title: 'a').mimeType, 'audio/flac');
      expect(const Song(path: 'a.opus', title: 'a').mimeType, 'audio/ogg');
      expect(const Song(path: 'a.xyz', title: 'a').mimeType, 'audio/mpeg');
    });
  });

  group('PlaylistConfig', () {
    test('equality ignores createdAt', () {
      final a = PlaylistConfig(up: '春', down: '秋', left: '冬', right: '夏');
      final b = PlaylistConfig(
        up: '春',
        down: '秋',
        left: '冬',
        right: '夏',
        createdAt: DateTime(2000),
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('copyWith overrides only given fields', () {
      final base = PlaylistConfig.defaultConfig;
      final updated = base.copyWith(up: 'Morning');
      expect(updated.up, 'Morning');
      expect(updated.down, base.down);
      expect(updated.left, base.left);
      expect(updated.right, base.right);
    });

    test('fromJson supplies defaults for missing keys', () {
      final config = PlaylistConfig.fromJson({'up': 'A'});
      expect(config.up, 'A');
      expect(config.down, '↓');
      expect(config.left, '←');
      expect(config.right, '→');
    });
  });
}
