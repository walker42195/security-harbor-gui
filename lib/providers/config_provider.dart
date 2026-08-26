import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../localization.dart';
import '../models/config_model.dart';
import '../services/api_service.dart';

enum ApplyStatus { idle, unconfirmed, confirming, error }

const String _prefsUrlKey = 'firewall_url';
const String _prefsLangKey = 'app_language';
// Sessionens token (kortlivad, serversignerad med utgång) sparas så att en
// sid-refresh i webb-GUI:t inte loggar ut användaren — webbläsaren laddar om
// hela Flutter-appen vid refresh, och en token som bara låg i minnet gick då
// förlorad. Token valideras alltid mot agenten vid start innan den litas på,
// och rensas om den avvisats/gått ut. Lösenordet sparas ALDRIG (se nedan).
const String _prefsTokenKey = 'firewall_token';
const String _prefsRoleKey = 'firewall_role';
const String _prefsUserKey = 'firewall_user';

class ConfigProvider extends ChangeNotifier {
  final ApiService api = ApiService();

  bool isAuthenticated = false;
  bool isLoading = false;
  // Sant tills den sparade brandvägg-URL:en (om någon) hunnit läsas in från
  // disk — LoginScreen väntar med att rendera fältet förifyllt tills dess.
  bool isInitializing = true;
  bool hasUnappliedChanges = false;
  String? errorMessage;
  String? statusMessage;

  ConfigModel? runningConfig;
  ConfigModel? candidateConfig;
  Map<String, dynamic>? systemStatus;

  ApplyStatus applyStatus = ApplyStatus.idle;
  int rollbackSecondsRemaining = 0;
  Timer? _rollbackCountdownTimer;

  // Fas 8 — flera användare/roller. isAdmin styr t.ex. om GUI:t visar
  // skriv-knappar/användarhantering; den FAKTISKA behörighetskontrollen
  // sker alltid på agenten (authMiddlewareAdmin), detta är bara för UX.
  bool get isAdmin => api.role == 'admin';

  // Språkval. Svenska är default tills användaren aktivt växlar (matchar
  // appens tidigare hårdkodade beteende exakt) — se localization.dart för
  // själva tr()-uppslagningen. Måste gå att ändra redan innan inloggning
  // (LoginScreen), så det ligger på ConfigProvider och inte bakom auth.
  AppLanguage language = AppLanguage.sv;

  Future<void> setLanguage(AppLanguage lang) async {
    language = lang;
    currentLanguage = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsLangKey, lang.name);
    notifyListeners();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsLangKey);
    if (saved == 'en') {
      language = AppLanguage.en;
      currentLanguage = AppLanguage.en;
    }
  }

  // OBS: Inget hop-kodat lösenord/auto-login här. Appen distribueras
  // publikt (APK/Linux-paket på security.novabase.se) — ett hårdkodat
  // lösenord i klientkoden hade skickats ut till VARJE nedladdning,
  // oavsett vilken server de sedan pekar appen mot. Bara URL:en (aldrig
  // lösenordet) sparas lokalt vid lyckad inloggning, se _saveUrl.

  ConfigProvider() {
    _loadLanguage().then((_) => _loadSavedUrl());
  }

  Future<void> _loadSavedUrl() async {
    final prefs = await SharedPreferences.getInstance();
    var savedUrl = prefs.getString(_prefsUrlKey);
    if (savedUrl != null && savedUrl.isNotEmpty) {
      // Migrera automatiskt en tidigare sparad http://-URL till https://
      // — Management-API:t kräver numera alltid TLS (Fas 8+), så en gammal
      // installation ska inte behöva mata in adressen manuellt igen bara
      // för att skemat ändrats.
      if (savedUrl.startsWith('http://')) {
        savedUrl = 'https://${savedUrl.substring('http://'.length)}';
        await prefs.setString(_prefsUrlKey, savedUrl);
      }
      api.setBaseUrl(savedUrl);

      // Försök återuppta en tidigare session (t.ex. efter en sid-refresh i
      // webb-GUI:t). Token valideras mot agenten (/api/v1/system) innan vi
      // litar på den — en utgången/avvisad token ger då inloggningsvyn i
      // stället, aldrig ett falskt "inloggad"-läge.
      final savedToken = prefs.getString(_prefsTokenKey);
      if (savedToken != null && savedToken.isNotEmpty) {
        api.token = savedToken;
        api.role = prefs.getString(_prefsRoleKey);
        api.username = prefs.getString(_prefsUserKey);
        final status = await api
            .getSystemStatus()
            .timeout(const Duration(seconds: 6), onTimeout: () => null);
        if (status != null) {
          isAuthenticated = true;
          statusMessage = tr('provider.status.logged_in');
          systemStatus = status;
          unawaited(fetchAll());
        } else {
          api.token = null;
          api.role = null;
          api.username = null;
          await _clearSession();
        }
      }
    }
    isInitializing = false;
    notifyListeners();
  }

  Future<void> _saveUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsUrlKey, url);
  }

  // Sparar sessionens token/roll/användarnamn (INTE lösenordet) så att en
  // refresh i webb-GUI:t behåller inloggningen. Token är serversignerad med
  // utgång och valideras vid nästa start.
  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (api.token != null) {
      await prefs.setString(_prefsTokenKey, api.token!);
    }
    if (api.role != null) {
      await prefs.setString(_prefsRoleKey, api.role!);
    }
    if (api.username != null) {
      await prefs.setString(_prefsUserKey, api.username!);
    }
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsTokenKey);
    await prefs.remove(_prefsRoleKey);
    await prefs.remove(_prefsUserKey);
  }

  Future<void> changeAgentUrl(String newUrl) async {
    api.setBaseUrl(newUrl);
  }

  Future<void> login(String user, String pass) async {
    isLoading = true;
    errorMessage = null;
    statusMessage = tr('provider.status.connecting');
    notifyListeners();

    final success = await api.login(user, pass);
    if (success) {
      isAuthenticated = true;
      statusMessage = tr('provider.status.logged_in');
      await _saveUrl(api.baseUrl);
      await _saveSession();
      await fetchAll();
    } else {
      isAuthenticated = false;
      errorMessage = trp('provider.error.login_failed', {'url': api.baseUrl});
      statusMessage = null;
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> logout() async {
    // Återkalla sessionen PÅ SERVERN först — att bara rensa klientens minne
    // lämnade tokenen giltig i upp till 24 timmar (kodgranskning
    // 2026-08-25). Fel ignoreras: kan agenten inte nås ska utloggningen
    // lokalt ändå gå igenom.
    await api.logout();
    isAuthenticated = false;
    api.token = null;
    api.role = null;
    api.username = null;
    runningConfig = null;
    candidateConfig = null;
    systemStatus = null;
    await _clearSession();
    notifyListeners();
  }

  /// Uppdaterar ENDAST systemStatus (CPU/RAM/uptime m.m.) utan att röra
  /// running/candidate-configen — anropas periodiskt från Dashboard så
  /// siffrorna faktiskt lever, se _pollBandwidth i dashboard_screen.dart.
  Future<void> refreshSystemStatus() async {
    if (!isAuthenticated) return;
    systemStatus = await api.getSystemStatus();
    notifyListeners();
  }

  Future<void> fetchAll() async {
    systemStatus = await api.getSystemStatus();
    runningConfig = await api.getRunningConfig();
    candidateConfig = await api.getCandidateConfig();
    notifyListeners();
  }

  /// Uppdaterar ALLT i GUI:t (systemstatus + running/candidate-config) på
  /// begäran — anropas av refresh-knappen i topbaren. Visar en kort
  /// laddningsbanner medan det pågår.
  Future<void> refreshAll() async {
    if (!isAuthenticated || isLoading) return;
    isLoading = true;
    statusMessage = tr('provider.status.updating');
    notifyListeners();
    await fetchAll();
    isLoading = false;
    statusMessage = null;
    notifyListeners();
  }

  Future<void> updateCandidate(ConfigModel newConfig) async {
    isLoading = true;
    statusMessage = tr('provider.status.saving_candidate');
    notifyListeners();

    final success = await api.setCandidateConfig(newConfig);
    if (success) {
      candidateConfig = newConfig;
      hasUnappliedChanges = true;
      statusMessage = null;
    } else {
      errorMessage = tr('provider.error.save_candidate_failed');
    }

    isLoading = false;
    notifyListeners();
  }

  /// Kastar bort alla ännu icke-applicerade ändringar i kandidat-
  /// konfigurationen och återställer den till den nu körande (running)
  /// konfigurationen. Används t.ex. om man råkat ta bort en regel men
  /// ännu inte tryckt Applicera — inget har då nått brandväggen, så det
  /// räcker att skriva tillbaka running som ny kandidat. (Detta är INTE
  /// samma sak som Rollback, som återställer en REDAN applicerad men
  /// obekräftad ändring.)
  Future<bool> discardChanges() async {
    isLoading = true;
    statusMessage = tr('provider.status.discarding');
    notifyListeners();

    final running = await api.getRunningConfig();
    if (running == null) {
      errorMessage = tr('provider.error.get_running_failed');
      statusMessage = null;
      isLoading = false;
      notifyListeners();
      return false;
    }

    final ok = await api.setCandidateConfig(running);
    if (ok) {
      runningConfig = running;
      candidateConfig = running;
      hasUnappliedChanges = false;
      statusMessage = null;
      errorMessage = null;
    } else {
      errorMessage = tr('provider.error.discard_failed');
      statusMessage = null;
    }
    isLoading = false;
    notifyListeners();
    return ok;
  }

  Future<bool> applyChanges() async {
    if (candidateConfig == null) return false;
    isLoading = true;
    statusMessage = tr('provider.status.applying');
    notifyListeners();

    final err = await api.applyConfig();
    if (err == null) {
      applyStatus = ApplyStatus.unconfirmed;
      hasUnappliedChanges = false;
      statusMessage = null;
      errorMessage = null;
      _startRollbackTimer(_rollbackTimeoutSeconds());
      isLoading = false;
      notifyListeners();
      return true;
    } else {
      errorMessage = err;
      statusMessage = null;
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> confirmChanges() async {
    isLoading = true;
    statusMessage = tr('provider.status.confirming');
    notifyListeners();

    final success = await api.confirmConfig();
    if (success) {
      _stopRollbackTimer();
      applyStatus = ApplyStatus.idle;
      hasUnappliedChanges = false;
      statusMessage = null;
      await fetchAll();
      isLoading = false;
      notifyListeners();
      return true;
    } else {
      errorMessage = tr('provider.error.confirm_failed');
      statusMessage = null;
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> rollbackChanges() async {
    isLoading = true;
    statusMessage = tr('provider.status.rolling_back');
    notifyListeners();

    final success = await api.rollbackConfig();
    _stopRollbackTimer();
    applyStatus = ApplyStatus.idle;
    hasUnappliedChanges = false;
    statusMessage = null;
    await fetchAll();
    isLoading = false;
    notifyListeners();
    return success;
  }

  /// Hur många sekunder agenten faktiskt kommer att vänta innan den rullar
  /// tillbaka. Nedräkningen var tidigare hårdkodad till 30 s och ignorerade
  /// inställningen helt: satte man 62 s väntade agenten i 62 s medan GUI:t
  /// räknade ned från 30 och sedan påstod att appliceringen redan var
  /// återställd (rapporterat 2026-08-26).
  ///
  /// Klampningen MÅSTE spegla engine.ApplyCandidate på serversidan, annars
  /// visar nedräkningen fortfarande fel tal för värden utanför intervallet.
  /// Källan är candidate-configen — det är den agenten läser värdet ur när
  /// den startar sin timer.
  int _rollbackTimeoutSeconds() {
    final seconds =
        (candidateConfig ?? runningConfig)?.settings.rollbackTimeoutSec ?? 30;
    if (seconds <= 0) return 30;
    if (seconds < 10) return 10;
    if (seconds > 600) return 600;
    return seconds;
  }

  void _startRollbackTimer(int seconds) {
    _stopRollbackTimer();
    rollbackSecondsRemaining = seconds;
    _rollbackCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (rollbackSecondsRemaining > 1) {
        rollbackSecondsRemaining--;
        notifyListeners();
      } else {
        _stopRollbackTimer();
        applyStatus = ApplyStatus.idle;
        hasUnappliedChanges = false;
        fetchAll();
      }
    });
  }

  void _stopRollbackTimer() {
    _rollbackCountdownTimer?.cancel();
    _rollbackCountdownTimer = null;
    rollbackSecondsRemaining = 0;
  }
}
