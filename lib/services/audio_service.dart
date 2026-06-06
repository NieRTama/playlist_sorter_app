import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'web_helpers.dart';
import 'windows_audio_helper.dart' if (dart.library.html) 'windows_audio_helper_stub.dart' as windows_audio;

class AudioService {
  final AudioPlayer _player = AudioPlayer();
  String? _currentObjectUrl;
  Timer? _clipTimer;
  double _volume = 1.0;

  Future<void> playPreview(
    String path, {
    dynamic bytes,
    String mimeType = 'audio/mpeg',
    String? uri,
  }) async {
    _clipTimer?.cancel();
    try {
      await _player.stop();
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
        _clipTimer = Timer(const Duration(seconds: 5), () => _player.stop());
      } else if (uri != null) {
        // iOS media library asset URL
        await _player.setAudioSource(AudioSource.uri(Uri.parse(uri)));
        await _player.setClip(
          start: Duration.zero,
          end: const Duration(seconds: 5),
        );
        // Ensure current volume is applied for the preview
        try {
          await _player.setVolume(_volume);
        } catch (_) {}
        await _player.play();
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        try {
          debugPrint('AudioService: Windows fallback using Win32 MCI, path=$path');
          await windows_audio.win32PlayAudio(path, _volume);
          _clipTimer = Timer(const Duration(seconds: 5), windows_audio.win32StopAudio);
          return;
        } catch (e) {
          debugPrint('AudioService: Win32 MCI playback failed for path="$path": $e');
          try {
            if (path.startsWith('file://')) {
              await _player.setAudioSource(AudioSource.uri(Uri.parse(path)));
            } else {
              await _player.setFilePath(path);
            }
          } catch (e2) {
            debugPrint('AudioService: just_audio Windows fallback failed for path="$path": $e2');
            rethrow;
          }
          await _player.setClip(
            start: Duration.zero,
            end: const Duration(seconds: 5),
          );
          try {
            await _player.setVolume(_volume);
          } catch (_) {}
          await _player.play();
          return;
        }
      } else {
        try {
          if (path.startsWith('file://')) {
            await _player.setAudioSource(AudioSource.uri(Uri.parse(path)));
          } else {
            await _player.setFilePath(path);
          }
        } catch (e) {
          debugPrint('AudioService: setFilePath/setAudioSource failed for path="$path": $e');
          try {
            await _player.setAudioSource(AudioSource.uri(Uri.file(path)));
          } catch (e2) {
            debugPrint('AudioService: fallback Uri.file failed for path="$path": $e2');
            rethrow;
          }
        }
        await _player.setClip(
          start: Duration.zero,
          end: const Duration(seconds: 5),
        );
        try {
          await _player.setVolume(_volume);
        } catch (_) {}
        await _player.play();
      }
    } catch (e, st) {
      debugPrint('AudioService.playPreview failed: $e');
      debugPrint('$st');
    }
  }

  /// Set playback volume (0.0 - 1.0)
  Future<void> setVolume(double v) async {
    _volume = v.clamp(0.0, 1.0);
    try {
      await _player.setVolume(_volume);
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










