import 'dart:io';
import 'package:on_audio_query/on_audio_query.dart';
import '../models/song.dart';

Future<List<Song>?> loadFromMusicLibrary() async {
  if (!Platform.isIOS) return null;

  final query = OnAudioQuery();

  final hasPermission = await query.permissionsStatus();
  if (!hasPermission) {
    final granted = await query.permissionsRequest();
    if (!granted) return null;
  }

  final songModels = await query.querySongs(
    sortType: SongSortType.TITLE,
    orderType: OrderType.ASC_OR_SMALLER,
    ignoreCase: true,
  );

  return songModels
      .where((s) => s.uri != null)
      .map((s) => Song(
            path: s.data,
            title: s.title,
            artist: s.artist ?? '',
            album: s.album ?? '',
            durationMs: s.duration,
            uri: s.uri,
          ))
      .toList();
}
