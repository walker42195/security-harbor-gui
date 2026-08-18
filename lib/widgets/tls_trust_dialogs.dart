import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Kör hela trust-on-first-use-flödet: kollar certifikatet, visar rätt
/// dialog vid behov, och returnerar true om anslutningen ska fortsätta
/// (false om användaren avbröt). Delas mellan LoginScreen och
/// SettingsScreen så de två inloggningsvägarna beter sig identiskt.
Future<bool> runTlsTrustCheck(BuildContext context, ApiService api) async {
  final check = await api.checkServerCertificate();
  if (!context.mounted) return false;
  switch (check.status) {
    case TlsTrustStatus.newUnknown:
      final trust = await showTrustNewCertificateDialog(context, check.fingerprint!);
      if (trust != true) return false;
      await api.trustFingerprint(check.fingerprint!);
      return true;
    case TlsTrustStatus.mismatch:
      final proceed = await showCertificateMismatchDialog(context, check.expectedFingerprint!, check.fingerprint!);
      if (proceed != true) return false;
      await api.trustFingerprint(check.fingerprint!);
      return true;
    case TlsTrustStatus.trustedMatch:
    case TlsTrustStatus.skipped:
      return true;
  }
}

/// Dialog för trust-on-first-use: ett HELT NYTT certifikat (ingen tidigare
/// sparad för den här host:port). Visas innan anslutning fullföljs.
Future<bool?> showTrustNewCertificateDialog(BuildContext context, String fingerprint) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text('Nytt certifikat', style: TextStyle(color: Colors.white, fontSize: 15)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Brandväggens certifikat:', style: TextStyle(color: Colors.white, fontSize: 12)),
          const SizedBox(height: 8),
          SelectableText(fingerprint, style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontFamily: 'monospace')),
          const SizedBox(height: 12),
          const Text('Lita på detta certifikat?', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Avbryt')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Lita på & anslut'),
        ),
      ],
    ),
  );
}

/// Varningsdialog: certifikatet skiljer sig från det tidigare betrodda
/// (trust-on-first-use-mismatch — kan betyda ett man-in-the-middle-angrepp,
/// men kan också vara en avsiktlig omgenerering av certifikatet på servern).
Future<bool?> showCertificateMismatchDialog(BuildContext context, String expected, String actual) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.redAccent),
          SizedBox(width: 8),
          Text('Certifikatet har ändrats!', style: TextStyle(color: Colors.redAccent, fontSize: 15)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Detta kan betyda ett man-in-the-middle-angrepp.', style: TextStyle(color: Colors.white, fontSize: 12)),
          const SizedBox(height: 12),
          const Text('Förväntat:', style: TextStyle(color: Colors.grey, fontSize: 11)),
          SelectableText(expected, style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
          const SizedBox(height: 8),
          const Text('Faktiskt:', style: TextStyle(color: Colors.grey, fontSize: 11)),
          SelectableText(actual, style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontFamily: 'monospace')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Avbryt')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.black),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Anslut ändå'),
        ),
      ],
    ),
  );
}
