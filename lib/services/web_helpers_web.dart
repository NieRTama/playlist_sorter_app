// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
// NOTE: Uses dart:html (deprecated). A migration to package:web + dart:js_interop
// is pending; deferred until it can be verified against a real web build.
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

String? createAudioObjectUrl(Uint8List bytes, String mimeType) {
  final blob = html.Blob([bytes], mimeType);
  return html.Url.createObjectUrlFromBlob(blob);
}

void revokeObjectUrl(String url) {
  html.Url.revokeObjectUrl(url);
}

void downloadFileWeb(String filename, String content) {
  final bytes = utf8.encode(content);
  final blob = html.Blob([Uint8List.fromList(bytes)]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  (html.AnchorElement(href: url)
        ..setAttribute('download', filename))
      .click();
  html.Url.revokeObjectUrl(url);
}
