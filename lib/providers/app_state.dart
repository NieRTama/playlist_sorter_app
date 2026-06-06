import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';
import '../models/playlist_config.dart';

enum SwipeDirection { up, down, left, right }

class AppState extends ChangeNotifier {
  List<Song> _songs = [];
  int _currentIndex = 0;
  int _sessionId = 0;
  final Map<SwipeDirection, List<Song>> _playlists = {
    SwipeDirection.up: [],
    SwipeDirection.down: [],
    SwipeDirection.left: [],
    SwipeDirection.right: [],
  };
  PlaylistConfig _config = PlaylistConfig.defaultConfig;
  List<PlaylistConfig> _configHistory = [];
  bool _initialized = false;
  bool _needsCheckpoint = false;
  bool _isLoadingMoreSongs = false;

  List<Song> get songs => _songs;
  int get currentIndex => _currentIndex;
  Song? get currentSong =>
      _currentIndex < _songs.length ? _songs[_currentIndex] : null;
  Map<SwipeDirection, List<Song>> get playlists => Map.unmodifiable(_playlists);
  PlaylistConfig get config => _config;
  List<PlaylistConfig> get configHistory => List.unmodifiable(_configHistory);
  bool get initialized => _initialized;
  bool get isComplete => _songs.isNotEmpty && _currentIndex >= _songs.length;
  bool get hasSession => _songs.isNotEmpty;
  bool get needsCheckpoint => _needsCheckpoint;
  int get processedCount => _currentIndex;
  int get totalCount => _songs.length;
  double get progress => _songs.isEmpty ? 0.0 : _currentIndex / _songs.length;
  bool get isLoadingMoreSongs => _isLoadingMoreSongs;
  int get sessionId => _sessionId;

  String playlistName(SwipeDirection dir) {
    switch (dir) {
      case SwipeDirection.up:
        return _config.up;
      case SwipeDirection.down:
        return _config.down;
      case SwipeDirection.left:
        return _config.left;
      case SwipeDirection.right:
        return _config.right;
    }
  }

  AppState() {
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();

    final configJson = prefs.getString('config');
    if (configJson != null) {
      try {
        _config = PlaylistConfig.fromJson(
            jsonDecode(configJson) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('AppState: failed to parse config: $e');
      }
    }

    final historyJson = prefs.getStringList('configHistory') ?? [];
    _configHistory = historyJson.map((h) {
      try {
        return PlaylistConfig.fromJson(jsonDecode(h) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('AppState: failed to parse config history entry: $e');
        return null;
      }
    }).whereType<PlaylistConfig>().toList();

    final songsJson = prefs.getStringList('songs') ?? [];
    _songs = songsJson.map((s) {
      try {
        return Song.fromJson(jsonDecode(s) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('AppState: failed to parse song: $e');
        return null;
      }
    }).whereType<Song>().toList();

    _currentIndex = prefs.getInt('currentIndex') ?? 0;
    if (_currentIndex > _songs.length) _currentIndex = _songs.length;

    for (final dir in SwipeDirection.values) {
      final key = 'playlist_${dir.name}';
      final playlistJson = prefs.getStringList(key) ?? [];
      _playlists[dir] = playlistJson.map((s) {
        try {
          return Song.fromJson(jsonDecode(s) as Map<String, dynamic>);
        } catch (e) {
          debugPrint('AppState: failed to parse playlist song: $e');
          return null;
        }
      }).whereType<Song>().toList();
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('config', jsonEncode(_config.toJson()));
    await prefs.setStringList(
      'configHistory',
      _configHistory.map((c) => jsonEncode(c.toJson())).toList(),
    );
    await prefs.setStringList(
      'songs',
      _songs.map((s) => jsonEncode(s.toJson())).toList(),
    );
    await prefs.setInt('currentIndex', _currentIndex);
    for (final dir in SwipeDirection.values) {
      await prefs.setStringList(
        'playlist_${dir.name}',
        _playlists[dir]!.map((s) => jsonEncode(s.toJson())).toList(),
      );
    }
  }

  void startSession(List<Song> songs) {
    _sessionId++;
    _songs = songs;
    _currentIndex = 0;
    for (final dir in SwipeDirection.values) {
      _playlists[dir] = [];
    }
    _needsCheckpoint = false;
    notifyListeners();
    saveState();
  }

  void swipe(SwipeDirection direction) {
    if (currentSong == null) return;
    _playlists[direction]!.add(currentSong!);
    _currentIndex++;

    final isCheckpoint = _currentIndex % 50 == 0;
    _needsCheckpoint = isCheckpoint && _currentIndex < _songs.length;
    if (isCheckpoint) saveState();

    notifyListeners();
  }

  void appendSongs(List<Song> songs, {required int sessionId}) {
    if (songs.isEmpty || sessionId != _sessionId) return;
    _songs.addAll(songs);
    notifyListeners();
    saveState();
  }

  void setLoadingMoreSongs(bool value) {
    if (_isLoadingMoreSongs == value) return;
    _isLoadingMoreSongs = value;
    notifyListeners();
  }

  void acknowledgeCheckpoint() {
    _needsCheckpoint = false;
    // No notifyListeners needed - state change is cosmetic only
  }

  void updateConfig(PlaylistConfig newConfig) {
    if (_config != newConfig) {
      final alreadyInHistory = _configHistory.contains(_config);
      if (!alreadyInHistory) {
        _configHistory.insert(0, _config);
        if (_configHistory.length > 10) {
          _configHistory = _configHistory.sublist(0, 10);
        }
      }
    }
    _config = newConfig;
    notifyListeners();
    saveState();
  }

  Future<void> clearSession() async {
    _sessionId++;
    _isLoadingMoreSongs = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('songs');
    await prefs.remove('currentIndex');
    for (final dir in SwipeDirection.values) {
      await prefs.remove('playlist_${dir.name}');
    }
    _songs = [];
    _currentIndex = 0;
    for (final dir in SwipeDirection.values) {
      _playlists[dir] = [];
    }
    _needsCheckpoint = false;
    notifyListeners();
  }
}
