import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

String? _mciAlias;

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
