import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';
import '../localization.dart';

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
    case TlsTrustStatus.probeFailed:
      // Skiljer sig medvetet från "skipped": vi kan INTE bara låta
      // inloggningen fortsätta här, för då avvisar appens egen
      // badCertificateCallback det obetrodda certifikatet TYST (se
      // probeCertificateSha256-kommentaren) — administratören såg då bara
      // ett obegripligt "Inloggning misslyckades" utan att förstå varför.
      await showTlsProbeFailedDialog(context, check.error ?? tr('tls.okant_fel'));
      return false;
  }
}

/// Visas när certifikat-kontrollen (proben) misslyckas av en okänd
/// anledning INNAN inloggningen ens försöks — se TlsTrustStatus.probeFailed.
Future<void> showTlsProbeFailedDialog(BuildContext context, String error) {
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.danger),
          SizedBox(width: 8),
          Text(tr('tls.kunde_inte_kontrollera_certifikatet'), style: TextStyle(color: AppColors.danger, fontSize: 15)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('tls.probe_failed_body'),
            style: TextStyle(color: AppColors.text, fontSize: 12),
          ),
          const SizedBox(height: 8),
          SelectableText(error, style: TextStyle(color: AppColors.warn, fontSize: 11, fontFamily: 'monospace')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('tls.ok'))),
      ],
    ),
  );
}

/// Dialog för trust-on-first-use: ett HELT NYTT certifikat (ingen tidigare
/// sparad för den här host:port). Visas innan anslutning fullföljs.
Future<bool?> showTrustNewCertificateDialog(BuildContext context, String fingerprint) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(tr('tls.nytt_certifikat'), style: TextStyle(color: AppColors.text, fontSize: 15)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('tls.brandvaggens_certifikat'), style: TextStyle(color: AppColors.text, fontSize: 12)),
          const SizedBox(height: 8),
          SelectableText(fingerprint, style: TextStyle(color: AppColors.accent, fontSize: 11, fontFamily: 'monospace')),
          const SizedBox(height: 12),
          Text(tr('tls.lita_pa_detta_certifikat'), style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('tls.avbryt'))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentBg, foregroundColor: AppColors.onAccentBg),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(tr('tls.lita_pa_anslut')),
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
      backgroundColor: AppColors.surface,
      title: Row(
        children: [
          Icon(Icons.warning_amber, color: AppColors.danger),
          SizedBox(width: 8),
          Text(tr('tls.certifikatet_har_andrats'), style: TextStyle(color: AppColors.danger, fontSize: 15)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('tls.detta_kan_betyda_ett_man_in'), style: TextStyle(color: AppColors.text, fontSize: 12)),
          const SizedBox(height: 12),
          Text(tr('tls.forvantat'), style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          SelectableText(expected, style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontFamily: 'monospace')),
          const SizedBox(height: 8),
          Text(tr('tls.faktiskt'), style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          SelectableText(actual, style: TextStyle(color: AppColors.danger, fontSize: 11, fontFamily: 'monospace')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('tls.avbryt'))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: AppColors.onStatus),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(tr('tls.anslut_anda')),
        ),
      ],
    ),
  );
}
