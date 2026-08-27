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

  // Det ljusa temat följer produktens egen grafiska profil (webbplatsen):
  // varm gräddvit botten, nästan svart text, och varumärkets mint och gult
  // som knappfärger. Det första ljusa temat var blågrått Material och kändes
  // som en annan produkt.

  /// Sidbakgrund — varm gräddvit, inte blågrå.
  static Color get bg => _d ? const Color(0xFF0F172A) : const Color(0xFFF2F0E9);

  /// Kort- och panelyta.
  static Color get surface => _d ? const Color(0xFF1E293B) : const Color(0xFFFBFAF6);

  /// Ytan en nivå djupare (kodrutor, inbäddade listor).
  static Color get surfaceDeep => _d ? const Color(0xFF0F172A) : const Color(0xFFEDEBE2);

  /// Ramar och avdelare.
  static Color get border => _d ? const Color(0xFF334155) : const Color(0xFFD6D3C8);

  /// Svag avdelare.
  static Color get divider => _d ? Colors.white10 : Colors.black12;

  /// Brödtext — nästan svart, som på webbplatsen.
  static Color get text => _d ? Colors.white : const Color(0xFF1A1A1A);

  /// Sekundär text.
  static Color get textMuted => _d ? Colors.white70 : const Color(0xFF4A4A45);

  /// Svag text (platshållare, "—", överstrukna gamla värden).
  /// I ljust läge mörkare än man först tror: 0xFF94A3B8 mot vitt ger under
  /// 3:1 i kontrast och blev i praktiken oläsligt.
  static Color get textFaint => _d ? Colors.white38 : const Color(0xFF6B6B62);

  /// Platshållartext i inmatningsfält.
  static Color get hint => _d ? const Color(0xFF64748B) : const Color(0xFF8A8A80);

  /// Accent för TEXT och ikoner.
  ///
  /// Varumärkets mint (0xFF3DDC97) fungerar inte som textfärg — den ger runt
  /// 1.9:1 mot gräddvitt. Här används därför en mörk variant i samma
  /// hue-familj: det läses som samma färg, men går att läsa.
  static Color get accent => _d ? Colors.cyanAccent : const Color(0xFF0B6E4F);

  /// Text ovanpå accentfärgade knappar.
  static Color get onAccent => _d ? Colors.black : Colors.white;

  /// PRIMÄRKNAPPENS bakgrund — varumärkets mint.
  ///
  /// Egen färg skild från [accent] just för att den bär text i stället för
  /// att VARA text: på en knapp ligger färgen bakom svart text, precis som på
  /// webbplatsen, och då är den ljusa minten rätt.
  static Color get accentBg => _d ? Colors.cyanAccent : const Color(0xFF3DDC97);
  static Color get onAccentBg => Colors.black;

  /// SEKUNDÄRKNAPPENS bakgrund — varumärkets gula.
  static Color get warnBg => _d ? Colors.amberAccent : const Color(0xFFFFE500);
  static Color get onWarnBg => Colors.black;

  /// Betydelsebärande statusfärger.
  ///
  /// Materials `*Accent`-nyanser är ljusa — de är gjorda för att lysa mot en
  /// mörk yta. Mot vitt ger de under 2:1 i kontrast och blir närmast
  /// osynliga (rapporterat 2026-08-26). I ljust läge används därför mörka
  /// motsvarigheter med samma INNEBÖRD: grönt är fortfarande accept, rött
  /// deny, bärnsten varning.
  // Skilt från [accent], som också är grön i ljust läge: "accept" och
  // UI-accenten får inte vara samma färg — då bär färgkodningen ingen
  // information. Ett test vaktar att de inte kollapsar.
  static Color get ok => _d ? Colors.tealAccent : const Color(0xFF15803D);
  static Color get warn => _d ? Colors.amberAccent : const Color(0xFF8A6A00);
  /// Kategoripalett för cirkeldiagram (enhets-dashboarden). Färgerna ska gå
  /// att skilja åt bredvid varandra i både ljust och mörkt tema, och används
  /// cykliskt om det finns fler skivor än färger.
  static const List<Color> piePalette = [
    Color(0xFF4FC3F7), Color(0xFF81C784), Color(0xFFFFB74D), Color(0xFFE57373),
    Color(0xFFBA68C8), Color(0xFF4DD0E1), Color(0xFFFFF176), Color(0xFFA1887F),
    Color(0xFF90A4AE), Color(0xFFF06292),
  ];

  /// Reserverad för "Övriga"-skivan, som ska läsas som en samlingspost och
  /// aldrig förväxlas med en enskild enhet.
  static const Color pieOther = Color(0xFF546E7A);

  static Color get danger => _d ? Colors.redAccent : const Color(0xFFB3261E);

  /// Orange — "reject" och återställningsknappen. Egen färg, inte samma som
  /// [warn]: skillnaden mellan en varning och ett aktivt avslag ska synas.
  static Color get caution => _d ? Colors.orangeAccent : const Color(0xFFB4530A);

  /// Blått — DNAT/port forward.
  static Color get info => _d ? Colors.lightBlueAccent : const Color(0xFF1D4ED8);

  /// Tonad bakgrund för de LÅSTA default-deny-raderna i policylistan.
  /// Låg tidigare hårdkodad som 0xFF2A1518 och missades i den första
  /// temaomskrivningen — raderna förblev mörka mitt i det ljusa temat.
  static Color get dangerSurface =>
      _d ? const Color(0xFF2A1518) : const Color(0xFFFBE9E7);

  // Tonade banderollbakgrunder. I mörkt läge mörka mättade toner, i ljust
  // läge bleka toner av samma färg — texten ovanpå är [text], som vänder med
  // temat, så bakgrunden måste vända åt andra hållet.
  static Color get warnSurface =>
      _d ? const Color(0xFF78350F) : const Color(0xFFFEF3C7);
  static Color get dangerBanner =>
      _d ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2);
  static Color get infoSurface =>
      _d ? const Color(0xFF0284C7) : const Color(0xFFDBEAFE);
  static Color get cautionSurface =>
      _d ? const Color(0xFF9A3412) : const Color(0xFFFFEDD5);

  /// Text ovanpå en statusfärgad knapp. Statusfärgerna är LJUSA i mörkt läge
  /// och MÖRKA i ljust, så förgrunden måste vända med dem.
  static Color get onStatus => _d ? Colors.black : Colors.white;

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
