import 'package:flutter/foundation.dart' show kIsWeb;
import '../theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localization.dart';
import '../providers/config_provider.dart';
import '../widgets/tls_trust_dialogs.dart';

/// Visas vid appstart (och efter utloggning) istället för att kräva att
/// användaren navigerar till Settings-vyn för att logga in. Brandväggens
/// URL förifylls från det senast sparade värdet (se
/// ConfigProvider._loadSavedUrl) — lösenordet sparas ALDRIG och måste
/// alltid anges manuellt.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late TextEditingController _urlController;
  // Kontonamnet förifylls INTE. "master" är bara fabriksinställningens konto —
  // på en brandvägg där man lagt upp egna konton fick man annars radera det
  // varje gång, och ett förifyllt fält gjorde det dessutom lätt att av misstag
  // logga in som fel användare. Namnet ligger kvar som hintText, så det syns
  // ändå vilket konto en fabriksny låda har.
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _urlControllerInitialized = false;

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login(ConfigProvider provider) async {
    await provider.changeAgentUrl(_urlController.text);
    if (!mounted) return;

    // Trust-on-first-use: kolla brandväggens TLS-certifikat INNAN vi
    // faktiskt loggar in. Hoppas över helt på web (webbläsaren sköter sin
    // egen certifikatvarning) eller om URL:en inte är https://.
    if (!kIsWeb) {
      final proceed = await runTlsTrustCheck(context, provider.api);
      if (!mounted || !proceed) return;
    }

    await provider.login(_usernameController.text, _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ConfigProvider>(context);

    // _urlController skapas först när det sparade värdet (om något) har
    // hunnit läsas in, så fältet inte hinner visas tomt och sedan hoppa
    // till ett värde efter att SharedPreferences svarat.
    if (!_urlControllerInitialized && !provider.isInitializing) {
      _urlController = TextEditingController(text: provider.api.baseUrl == 'https://localhost:8443' ? '' : provider.api.baseUrl);
      _urlControllerInitialized = true;
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: provider.isInitializing
            ? CircularProgressIndicator(color: AppColors.accent)
            : ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Bredden matchar kortet nedanför (samma ConstrainedBox/
                      // Padding-bredd) istället för en liten fast 120x120-ruta,
                      // så undertexten i loggan ("Linux Firewall") faktiskt
                      // syns istället för att bli för liten för att läsa.
                      SizedBox(
                        width: double.infinity,
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => Icon(Icons.security, color: AppColors.accent, size: 48),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(tr('login.subtitle'), style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      const SizedBox(height: 12),
                      _LanguageToggle(provider: provider),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!kIsWeb) ...[
                              TextField(
                                controller: _urlController,
                                style: TextStyle(color: AppColors.text, fontSize: 13),
                                decoration: InputDecoration(
                                  labelText: tr('login.url_label'),
                                  hintText: tr('login.url_hint'),
                                  border: const OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.link, color: AppColors.accent, size: 18),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                            TextField(
                              controller: _usernameController,
                              // Markören står i kontonamnsfältet direkt när
                              // inloggningen visas — man ska kunna börja skriva
                              // utan att först klicka (och på telefonen fälls
                              // tangentbordet upp med detsamma). URL-fältet
                              // ovanför är förifyllt från förra inloggningen
                              // och behöver sällan röras.
                              autofocus: true,
                              style: TextStyle(color: AppColors.text, fontSize: 13),
                              decoration: InputDecoration(
                                labelText: tr('login.username_label'),
                                hintText: tr('settings.master'),
                                border: const OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person, color: AppColors.accent, size: 18),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: TextStyle(color: AppColors.text, fontSize: 13),
                              onSubmitted: (_) => _login(provider),
                              decoration: InputDecoration(
                                labelText: tr('login.password_label'),
                                border: const OutlineInputBorder(),
                                prefixIcon: Icon(Icons.lock, color: AppColors.accent, size: 18),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off, size: 18, color: AppColors.textMuted),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 44,
                              child: ElevatedButton.icon(
                                icon: provider.isLoading
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                    : const Icon(Icons.login, size: 16),
                                label: Text(tr('login.submit'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentBg, foregroundColor: AppColors.onAccentBg),
                                onPressed: provider.isLoading ? null : () => _login(provider),
                              ),
                            ),
                            if (provider.errorMessage != null) ...[
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Icon(Icons.error_outline, color: AppColors.danger, size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(provider.errorMessage!, style: TextStyle(color: AppColors.danger, fontSize: 12))),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/// Diskret SV/EN-växlare på inloggningsskärmen — ConfigProvider finns
/// tillgänglig redan innan inloggning, så det här är den enda platsen en
/// icke-svensktalande användare annars skulle fastna innan de ens kommer
/// in i appen (den fullständiga växlaren finns annars i Settings).
class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle({required this.provider});
  final ConfigProvider provider;

  @override
  Widget build(BuildContext context) {
    Widget langButton(AppLanguage lang, String label) {
      final active = provider.language == lang;
      return TextButton(
        onPressed: active ? null : () => provider.setLanguage(lang),
        style: TextButton.styleFrom(
          foregroundColor: active ? AppColors.accent : AppColors.textMuted,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        langButton(AppLanguage.sv, 'SV'),
        Text('|', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
        langButton(AppLanguage.en, 'EN'),
      ],
    );
  }
}
