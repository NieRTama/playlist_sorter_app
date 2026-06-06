Future<void> win32PlayAudio(String path, double volume) async {
  throw UnsupportedError('Windows audio helper is not supported on this platform.');
}

void win32StopAudio() {}

void win32SetVolume(double volume) {}

Future<String> win32CopyToAsciiTemp(String path) async => path;
