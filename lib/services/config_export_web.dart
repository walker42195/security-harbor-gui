import 'dart:convert';

import 'package:web/web.dart' as web;

/// Laddar ner konfigurationen via webbläsaren.
///
/// En webbsida kan inte skriva till filsystemet; det närmaste är en
/// nedladdning, vilket är precis vad användaren vill ha. Returnerar filnamnet
/// (inte en sökväg — var filen hamnar bestämmer webbläsaren).
Future<String?> saveTextFile(String filename, String content) async {
  final url = 'data:application/octet-stream;base64,${base64Encode(utf8.encode(content))}';
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  return filename;
}
