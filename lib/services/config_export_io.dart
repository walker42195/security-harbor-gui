import 'dart:io';

/// Skriver konfigurationen till en fil och returnerar sökvägen.
///
/// Väljer den första katalog som faktiskt finns: användarens
/// nedladdningskatalog, annars hemkatalogen, annars systemets temp. Att inte
/// hitta någon skrivbar plats alls är inget fel vi kan lösa åt användaren —
/// då returneras null och anroparen får visa "kopiera" i stället.
Future<String?> saveTextFile(String filename, String content) async {
  for (final dir in _candidateDirectories()) {
    try {
      if (!dir.existsSync()) continue;
      final file = File('${dir.path}${Platform.pathSeparator}$filename');
      await file.writeAsString(content, flush: true);
      // Konfigurationen innehåller privata nycklar — den ska inte vara
      // läsbar för andra konton på maskinen.
      if (!Platform.isWindows) {
        await Process.run('chmod', ['600', file.path]);
      }
      return file.path;
    } catch (_) {
      continue;
    }
  }
  return null;
}

List<Directory> _candidateDirectories() {
  final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  return [
    if (home != null) Directory('$home${Platform.pathSeparator}Downloads'),
    if (home != null) Directory('$home${Platform.pathSeparator}Hämtningar'),
    if (home != null) Directory(home),
    Directory.systemTemp,
  ];
}
