import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'web_helpers.dart';
import 'windows_audio_helper.dart' if (dart.library.html) 'windows_audio_helper_stub.dart' as windows_audio;

class AudioService {
  /// Length of the preview clip played for each song.
  static const Duration previewDuration = Duration(seconds: 120);

  /// Max time to wait for a just_audio load before treating it as failed and
  /// falling through to the next backend (guards against hangs).
  static const Duration _loadTimeout = Duration(seconds: 6);

  final AudioPlayer _player = AudioPlayer();
  String? _currentObjectUrl;
  Timer? _clipTimer;
  double _volume = 1.0;

  /// Incremented on every playPreview call. Lets a newer request supersede an
  /// in-flight one so concurrent calls (fast swipes, double init) don't cause
  /// just_audio "Loading interrupted" errors to cascade through the fallbacks.
  int _playToken = 0;

  /// Settles when the currently-running playPreview finishes its setup. A new
  /// call waits on it before touching the shared player, so overlapping load()
  /// calls never race on the same AudioPlayer.
  Future<void>? _pending;

  Future<void> playPreview(
    String path, {
    dynamic bytes,
    String mimeType = 'audio/mpeg',
    String? uri,
  }) async {
    final token = ++_playToken;
    final previous = _pending;
    final completer = Completer<void>();
    _pending = completer.future;
    try {
      // Let any in-flight request settle first, then bail if a newer call
      // arrived while we were waiting.
      if (previous != null) {
        try {
          await previous;
        } catch (_) {}
      }
      if (token != _playToken) return;

      _clipTimer?.cancel();
      await _player.stop();
      if (token != _playToken) return;
      if (!kIsWeb) {
        debugPrint('AudioService.playPreview path=$path uri=$uri platform=$defaultTargetPlatform');
      }

      if (kIsWeb) {
        if (bytes == null) return;
        if (_currentObjectUrl != null) {
          revokeObjectUrl(_currentObjectUrl!);
          _currentObjectUrl = null;
        }
        final url = createAudioObjectUrl(bytes, mimeType);
        if (url == null) return;
        _currentObjectUrl = url;
        await _player.setUrl(url);
        await _player.play();
        _clipTimer = Timer(previewDuration, () => _player.stop());
      } else if (uri != null) {
        // iOS media library asset URL
        await _playSource(AudioSource.uri(Uri.parse(uri)));
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        // Windows playback uses a 3-tier fallback because each backend has a
        // distinct blind spot:
        //   1. just_audio (Media Foundation): handles large ID3 tags / album
        //      art, but cannot open paths containing non-ASCII characters.
        //   2. Win32 MCI: handles non-ASCII paths, but fails to initialize
        //      (MCIERR 277) on files with large ID3 tags.
        //   3. Copy to an ASCII temp path, then just_audio: covers files that
        //      hit both blind spots (non-ASCII path AND large ID3 tag).
        //
        // just_audio_windows can never open a non-ASCII path (and worse, hangs
        // instead of erroring), so tier 1 is skipped for those — they go
        // straight to MCI / the ASCII-temp copy.
        final isAsciiPath = path.runes.every((r) => r < 128);
        if (isAsciiPath) {
          try {
            await _playViaJustAudio(path);
            return;
          } catch (e) {
            if (token != _playToken) return;
            debugPrint('AudioService: just_audio failed for "$path": $e');
          }
        }
        try {
          await windows_audio.win32PlayAudio(path, _volume);
          _clipTimer = Timer(previewDuration, windows_audio.win32StopAudio);
          return;
        } catch (e) {
          if (token != _playToken) return;
          debugPrint('AudioService: Win32 MCI failed for "$path": $e');
        }
        try {
          final tempPath = await windows_audio.win32CopyToAsciiTemp(path);
          if (token != _playToken) return;
          await _playViaJustAudio(tempPath);
          return;
        } catch (e) {
          if (token != _playToken) return;
          debugPrint('AudioService: ASCII-temp fallback failed for "$path": $e');
          rethrow;
        }
      } else {
        // macOS / Linux: play the file directly, retrying with a file:// URI.
        try {
          await _playViaJustAudio(path);
        } catch (e) {
          debugPrint('AudioService: playback failed for path="$path": $e');
          await _playSource(AudioSource.uri(Uri.file(path)));
        }
      }
    } catch (e, st) {
      debugPrint('AudioService.playPreview failed: $e');
      debugPrint('$st');
    } finally {
      completer.complete();
    }
  }

  /// Loads [source] into just_audio, clips it to [previewDuration] and starts
  /// playback at the current volume. A timer is armed as a backstop in case the
  /// platform backend does not honor setClip. Throws on load failure (or if the
  /// load hangs past [_loadTimeout]) so callers can fall through to a fallback.
  Future<void> _playSource(AudioSource source) async {
    await _player.setAudioSource(source).timeout(_loadTimeout);
    await _player.setClip(start: Duration.zero, end: previewDuration);
    try {
      await _player.setVolume(_volume);
    } catch (_) {}
    await _player.play();
    _clipTimer = Timer(previewDuration, () => _player.stop());
  }

  /// Resolves a file path or file:// URI to an [AudioSource] and plays it.
  Future<void> _playViaJustAudio(String source) => _playSource(
        source.startsWith('file://')
            ? AudioSource.uri(Uri.parse(source))
            : AudioSource.file(source),
      );

  /// Set playback volume (0.0 - 1.0).
  ///
  /// Updates both backends: just_audio (tiers 1 & 3) and the Win32 MCI stream
  /// (tier 2). win32SetVolume is a no-op when MCI isn't the active backend, so
  /// it's always safe to call.
  Future<void> setVolume(double v) async {
    _volume = v.clamp(0.0, 1.0);
    try {
      await _player.setVolume(_volume);
    } catch (_) {}
    try {
      windows_audio.win32SetVolume(_volume);
    } catch (_) {}
  }

  /// Current volume
  double get volume => _volume;

  Future<void> stop() async {
    _clipTimer?.cancel();
    try {
      await _player.stop();
    } catch (_) {}
    try {
      windows_audio.win32StopAudio();
    } catch (_) {}
  }

  void dispose() {
    _clipTimer?.cancel();
    if (_currentObjectUrl != null) {
      revokeObjectUrl(_currentObjectUrl!);
    }
    _player.dispose();
    try {
      windows_audio.win32StopAudio();
    } catch (_) {}
  }
}


