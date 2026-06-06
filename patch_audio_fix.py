from pathlib import Path
path = Path('lib/services/audio_service.dart')
text = path.read_text(encoding='utf-8')
old = '''      } else {
        try {
          await _player.setFilePath(path);
        } catch (_) {
          await _player.setAudioSource(AudioSource.uri(Uri.file(path)));
        }
        await _player.setClip(
          start: Duration.zero,
          end: const Duration(seconds: 5),
        );
        await _player.play();
      }
    } catch (_) {
      // Unsupported format or IO error — skip silently
    }
'''
new = '''      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        await _player.setAudioSource(AudioSource.uri(Uri.file(path)));
        await _player.setClip(
          start: Duration.zero,
          end: const Duration(seconds: 5),
        );
        await _player.play();
      } else {
        try {
          await _player.setFilePath(path);
        } catch (_) {
          await _player.setAudioSource(AudioSource.uri(Uri.file(path)));
        }
        await _player.setClip(
          start: Duration.zero,
          end: const Duration(seconds: 5),
        );
        await _player.play();
      }
    } catch (e, st) {
      debugPrint('AudioService.playPreview failed: %s' % e)
      debugPrint('%s' % st)
    }
'''
if old not in text:
    raise SystemExit('Old content not found')
path.write_text(text.replace(old, new), encoding='utf-8')
