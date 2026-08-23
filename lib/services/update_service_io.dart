// Desktop-varianten (dart:io) av update_service — hämtar gui-repots release-
// manifest, laddar ner desktop-bunten, verifierar SHA256 + Ed25519-signatur
// (mot en INBYGGD publik nyckel, samma som agenten), och gör ett ett-klicks
// självbyte: ett fristående hjälpskript väntar på att appen avslutas, ersätter
// installationskatalogen och startar om appen.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

import '../app_version.dart';
import 'update_types.dart';

const bool desktopUpdateSupported = true;

/// Samma inbyggda publika Ed25519-nyckel som agenten (pkg/updater). Den privata
/// motparten finns aldrig i repot.
const String _publicKeyB64 = '++tmvTzBazVx/7g2McZ+spxww1imKpdUM/iYKFVH7So=';

/// gui-repots senaste release-manifest (kräver publikt repo).
const String _manifestUrl =
    'https://github.com/walker42195/security-harbor-gui/releases/latest/download/manifest.json';

/// Var den nedladdade+verifierade bunten packats upp, i väntan på självbytet.
String? _stagedBundleDir;

int _cmpVersion(String a, String b) {
  List<int> parse(String v) => v
      .replaceFirst('v', '')
      .split('.')
      .map((p) => int.tryParse(p.trim()) ?? -1)
      .toList();
  final pa = parse(a), pb = parse(b);
  for (var i = 0; i < pa.length && i < pb.length; i++) {
    if (pa[i] != pb[i]) return pa[i] - pb[i];
  }
  return pa.length - pb.length;
}

Future<DesktopUpdate?> checkDesktopUpdate() async {
  try {
    final res = await http.get(Uri.parse(_manifestUrl)).timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) return null;
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    final d = m['desktop'] as Map<String, dynamic>?;
    if (d == null) {
      return const DesktopUpdate(current: kGuiVersion, available: 'okänd', updateAvailable: false);
    }
    final available = (d['version'] ?? 'okänd').toString();
    return DesktopUpdate(
      current: kGuiVersion,
      available: available,
      updateAvailable: _cmpVersion(available, kGuiVersion) > 0,
      url: d['url']?.toString(),
      sha256: d['sha256']?.toString(),
      sig: d['sig']?.toString(),
    );
  } catch (_) {
    return null;
  }
}

/// Laddar ner desktop-bunten, verifierar SHA256 + Ed25519 och packar upp den
/// till en temp-katalog (stagas i _stagedBundleDir). Returnerar null vid
/// framgång, annars ett felmeddelande. Uppgradera ska låsas upp först vid null.
Future<String?> downloadDesktopUpdate(DesktopUpdate update) async {
  try {
    if (update.url == null || update.sha256 == null || update.sig == null) {
      return 'Manifestet saknar url/sha256/signatur för desktop-bunten';
    }
    final res = await http.get(Uri.parse(update.url!)).timeout(const Duration(minutes: 5));
    if (res.statusCode != 200) return 'Nedladdning misslyckades (HTTP ${res.statusCode})';
    final bytes = res.bodyBytes;

    // SHA256
    final gotSha = crypto.sha256.convert(bytes).toString();
    if (gotSha.toLowerCase() != update.sha256!.toLowerCase()) {
      return 'SHA256 stämmer inte — avbryter';
    }

    // Ed25519-signatur mot den inbyggda publika nyckeln.
    final ok = await _verifyEd25519(bytes, update.sig!);
    if (!ok) return 'Signaturen kunde inte verifieras mot den inbyggda nyckeln';

    // Packa upp till temp via systemets tar (Linux-desktop har alltid tar).
    final tmp = await Directory.systemTemp.createTemp('sh-gui-update-');
    final tarPath = '${tmp.path}/bundle.tar.gz';
    await File(tarPath).writeAsBytes(bytes, flush: true);
    final bundleDir = Directory('${tmp.path}/bundle')..createSync();
    final r = await Process.run('tar', ['-xzf', tarPath, '-C', bundleDir.path]);
    if (r.exitCode != 0) return 'Kunde inte packa upp bunten: ${r.stderr}';

    _stagedBundleDir = bundleDir.path;
    return null;
  } catch (e) {
    return 'Nedladdning misslyckades: $e';
  }
}

Future<bool> _verifyEd25519(List<int> data, String sigB64) async {
  try {
    final pub = base64.decode(_publicKeyB64);
    final sig = base64.decode(sigB64.trim());
    if (pub.length != 32 || sig.length != 64) return false;
    final algorithm = Ed25519();
    final publicKey = SimplePublicKey(pub, type: KeyPairType.ed25519);
    return algorithm.verify(
      Uint8List.fromList(data),
      signature: Signature(sig, publicKey: publicKey),
    );
  } catch (_) {
    return false;
  }
}

/// Skriver ett fristående hjälpskript som väntar på att appen avslutas,
/// ersätter installationskatalogen med den stagade bunten och startar om
/// appen. Spawnar det detached och avslutar appen. Returnerar ett fel om något
/// saknas (annars återvänder funktionen aldrig — appen avslutas).
Future<String?> applyDesktopUpdate() async {
  final staged = _stagedBundleDir;
  if (staged == null) return 'Ingen nedladdad och verifierad bunt att installera';

  final exe = File(Platform.resolvedExecutable);
  final installDir = exe.parent.path; // t.ex. ~/.local/share/security-harbor-gui
  final exePath = exe.path;
  final myPid = pid;

  // Bunten kan antingen vara katalogens innehåll direkt eller ligga i en
  // underkatalog (t.ex. "bundle/"). Peka på den katalog som innehåller binären.
  var srcDir = staged;
  if (!File('$staged/${exe.uri.pathSegments.last}').existsSync()) {
    final sub = Directory(staged)
        .listSync()
        .whereType<Directory>()
        .where((d) => File('${d.path}/${exe.uri.pathSegments.last}').existsSync())
        .toList();
    if (sub.isNotEmpty) srcDir = sub.first.path;
  }

  final script = '''#!/bin/bash
set -e
# Vänta tills den körande appen (PID $myPid) avslutats.
for i in \$(seq 1 100); do
  kill -0 $myPid 2>/dev/null || break
  sleep 0.3
done
# Ersätt installationskatalogen med den nya bunten.
if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete "$srcDir"/ "$installDir"/
else
  cp -a "$srcDir"/. "$installDir"/
fi
chmod +x "$exePath" || true
# Starta om appen.
nohup "$exePath" >/dev/null 2>&1 &
''';

  final helper = File('${Directory.systemTemp.path}/sh-gui-update-apply.sh');
  await helper.writeAsString(script);
  await Process.run('chmod', ['+x', helper.path]);

  // Spawna hjälpskriptet detached så det överlever att appen avslutas.
  await Process.start('/bin/bash', [helper.path], mode: ProcessStartMode.detached);

  // Ge processen en chans att starta, avsluta sedan appen så bytet kan ske.
  await Future.delayed(const Duration(milliseconds: 300));
  exit(0);
}
