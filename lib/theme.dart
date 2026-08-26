/// Färgpalett och temaväxling.
///
/// GUI:t hade färgerna hårdkodade på 1332 ställen i 19 filer — bakgrunden
/// `0xFF0F172A`, kortytan `0xFF1E293B`, ramen `0xFF334155` och `Colors.white`
/// för text. Ett ljust tema krävde därför att varje sådant ställe blev
/// utbytbart.
///
/// Lösningen är statiska getters som läser [AppTheme.mode]. Alternativet —
/// `Theme.of(context)` överallt — hade krävt en BuildContext på ställen som
/// inte har någon, och hade dessutom brutit varje `const`-konstruktor i
/// trädet. Med getters räcker det att byta ut värdet; anropsstället ser
/// likadant ut.
///
/// Priset är att getters inte är `const`. Där en färg låg i ett
/// `const`-uttryck har det `const` tagits bort — det är en ren
/// prestandadetalj i en app som ändå bygger om vid varje temabyte.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Vilket tema som är aktivt.
enum AppThemeMode { dark, light }

/// Global temastyrning. Notifierar så att hela appen byggs om vid byte.
class AppTheme extends ChangeNotifier {
  AppTheme._();
  static final AppTheme instance = AppTheme._();

  static const _prefsKey = 'app_theme_mode';

  /// Nuvarande läge. Statiskt så att [AppColors] kan läsa det utan context.
  static AppThemeMode mode = AppThemeMode.dark;

  static bool get isDark => mode == AppThemeMode.dark;

  /// Läser sparat val vid uppstart. Mörkt är standard — det är vad appen
  /// alltid sett ut som, och ett tema ska inte byta av sig självt.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved == AppThemeMode.light.name) {
        mode = AppThemeMode.light;
        notifyListeners();
      }
    } catch (_) {
      // Kan inte läsa inställningen (t.ex. första starten): behåll mörkt.
    }
  }

  Future<void> toggle() => setMode(isDark ? AppThemeMode.light : AppThemeMode.dark);

  Future<void> setMode(AppThemeMode next) async {
    if (mode == next) return;
    mode = next;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, next.name);
    } catch (_) {
      // Valet gäller ändå för den här sessionen.
    }
  }
}

/// Färgerna som byter med temat.
///
/// Accentfärgerna (cyan, bärnsten, rött, grönt) är AVSIKTLIGT nästan
/// oförändrade mellan temana: de bär betydelse i det här gränssnittet —
/// rött är deny, grönt är accept, bärnsten är varning — och en färgkodning
/// som byter innebörd mellan teman vore direkt farlig i en brandvägg.
/// I ljust tema mörkas de bara så mycket att de får tillräcklig kontrast
/// mot vit bakgrund.
class AppColors {
  const AppColors._();

  static bool get _d => AppTheme.isDark;

  /// Sidbakgrund.
  static Color get bg => _d ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);

  /// Kort- och panelyta.
  static Color get surface => _d ? const Color(0xFF1E293B) : Colors.white;

  /// Ytan en nivå djupare (kodrutor, inbäddade listor).
  static Color get surfaceDeep => _d ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

  /// Ramar och avdelare.
  static Color get border => _d ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

  /// Svag avdelare.
  static Color get divider => _d ? Colors.white10 : Colors.black12;

  /// Brödtext.
  static Color get text => _d ? Colors.white : const Color(0xFF0F172A);

  /// Sekundär text.
  static Color get textMuted => _d ? Colors.white70 : const Color(0xFF475569);

  /// Svag text (platshållare, "—").
  static Color get textFaint => _d ? Colors.white38 : const Color(0xFF94A3B8);

  /// Platshållartext i inmatningsfält.
  static Color get hint => _d ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

  /// Accent — den genomgående cyanfärgen.
  static Color get accent => _d ? Colors.cyanAccent : const Color(0xFF0E7490);

  /// Text ovanpå accentfärgade knappar.
  static Color get onAccent => _d ? Colors.black : Colors.white;

  /// Betydelsebärande statusfärger.
  static Color get ok => _d ? Colors.tealAccent : const Color(0xFF047857);
  static Color get warn => _d ? Colors.amberAccent : const Color(0xFFB45309);
  static Color get danger => _d ? Colors.redAccent : const Color(0xFFB91C1C);

  /// ThemeData för MaterialApp, så att Flutters egna widgets (dialoger,
  /// snackbars, textmarkering) följer med i temabytet.
  static ThemeData themeData() {
    final base = _d ? ThemeData.dark() : ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      canvasColor: surface,
      cardColor: surface,
      dividerColor: border,
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        surface: surface,
        error: danger,
      ),
      dialogTheme: DialogThemeData(backgroundColor: surface),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _d ? const Color(0xFF334155) : const Color(0xFF1E293B),
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: accent.withValues(alpha: 0.3),
      ),
    );
  }
}
