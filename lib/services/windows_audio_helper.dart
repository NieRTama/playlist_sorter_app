import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

String? _mciAlias;

/// Copies [path] to an ASCII-only temp path and returns it.
///
/// just_audio_windows cannot open files whose path contains non-ASCII
/// characters (e.g. Japanese folder names) — it reports "path not found".
/// Copying to an ASCII path under the system temp dir works around this,
/// letting Media Foundation decode files (incl. those with large ID3 tags)
/// that the legacy MCI device also fails on.
Future<String> win32CopyToAsciiTemp(String path) async {
  final dotIdx = path.lastIndexOf('.');
  final ext = dotIdx >= 0 ? path.substring(dotIdx) : '.mp3';
  final dir = Directory('${Directory.systemTemp.path}\\plsorter_preview');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  } else {
    // Best-effort cleanup of previous previews (ignore locked files).
    try {
      await for (final e in dir.list()) {
        if (e is File) {
          try {
            await e.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }
  final dest = '${dir.path}\\p${DateTime.now().microsecondsSinceEpoch}$ext';
  await File(path).copy(dest);
  return dest;
}

Future<void> win32PlayAudio(String path, double volume) async {
  win32StopAudio();

  final escapedPath = path.replaceAll('"', '\\"');
  _mciAlias = 'playlist_sorter_${DateTime.now().microsecondsSinceEpoch}';

  final openCommand = 'open "$escapedPath" alias $_mciAlias';
  final openPtr = TEXT(openCommand).cast<Utf16>();
  final result = mciSendString(openPtr, nullptr, 0, NULL);
  calloc.free(openPtr);

  if (result != 0) {
    final errorMessage = _getMciErrorString(result);
    _mciAlias = null;
    throw Exception('MCI open failed ($result): $errorMessage');
  }

  final volumeValue = (volume.clamp(0.0, 1.0) * 1000).round();
  final setVolumeCommand = 'setaudio $_mciAlias volume to $volumeValue';
  final volumePtr = TEXT(setVolumeCommand).cast<Utf16>();
  final volumeResult = mciSendString(volumePtr, nullptr, 0, NULL);
  calloc.free(volumePtr);
  if (volumeResult != 0) {
    final errorMessage = _getMciErrorString(volumeResult);
    win32StopAudio();
    throw Exception('MCI set volume failed ($volumeResult): $errorMessage');
  }

  final playCommand = 'play $_mciAlias';
  final playPtr = TEXT(playCommand).cast<Utf16>();
  final playResult = mciSendString(playPtr, nullptr, 0, NULL);
  calloc.free(playPtr);
  if (playResult != 0) {
    final errorMessage = _getMciErrorString(playResult);
    win32StopAudio();
    throw Exception('MCI play failed ($playResult): $errorMessage');
  }
}

/// Updates the volume (0.0 - 1.0) of the currently-playing MCI stream.
/// No-op if nothing is playing via MCI.
void win32SetVolume(double volume) {
  if (_mciAlias == null) return;
  final volumeValue = (volume.clamp(0.0, 1.0) * 1000).round();
  final cmd = 'setaudio $_mciAlias volume to $volumeValue';
  final ptr = TEXT(cmd).cast<Utf16>();
  mciSendString(ptr, nullptr, 0, NULL);
  calloc.free(ptr);
}

void win32StopAudio() {
  if (_mciAlias == null) return;

  final stopCommand = 'stop $_mciAlias';
  final stopPtr = TEXT(stopCommand);
  mciSendString(stopPtr, nullptr, 0, NULL);
  calloc.free(stopPtr);

  final closeCommand = 'close $_mciAlias';
  final closePtr = TEXT(closeCommand);
  mciSendString(closePtr, nullptr, 0, NULL);
  calloc.free(closePtr);

  _mciAlias = null;
}

String _getMciErrorString(int errorCode) {
  final buffer = calloc<Uint16>(256).cast<Utf16>();
  mciGetErrorString(errorCode, buffer, 256);
  final message = buffer.toDartString();
  calloc.free(buffer);
  return message;
}
