import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/config_provider.dart';
import 'screens/main_screen.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const SecurityHarborApp());
}

class SecurityHarborApp extends StatelessWidget {
  const SecurityHarborApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ConfigProvider(),
      child: MaterialApp(
        title: 'Security Harbor GUI',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0F172A),
          colorScheme: const ColorScheme.dark(
            primary: Colors.cyanAccent,
            surface: Color(0xFF1E293B),
          ),
          // 'Roboto' pekar nu på det LOKALT BUNTADE typsnittet
          // (assets/fonts/, deklarerat i pubspec.yaml) — INTE Flutter Webs
          // implicita "hämta från Google Fonts vid behov"-beteende.
          // ('sans-serif' visade sig vara fel lösning: CanvasKit-
          // renderaren ritar all text via glyfdata från en riktig
          // typsnittsfil, inte via CSS-namn — utan en bundlad fil blev
          // resultatet en helt textlös sida, inte bara fel typsnitt.)
          fontFamily: 'Roboto',
          // Utan detta ärver varje TextField Materials DEFAULT
          // labelStyle (betydligt större typsnitt än den 11-12px vi
          // annars använder överallt i appen) och en underline-border
          // istället för den rutade OutlineInputBorder vi använder i de
          // flesta dialoger — resultatet blev synligt olika typsnittsstorlekar
          // och för lite luft mellan etikett och fält på många skärmar
          // (Interfaces, Objekt, DNAT-dialogen m.fl.). Genom att sätta
          // detta en gång globalt får ALLA fält, även de som inte
          // uttryckligen anger en border/labelStyle, samma utseende.
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFF334155))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFF334155))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Colors.cyanAccent)),
            labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
            floatingLabelStyle: const TextStyle(color: Colors.cyanAccent, fontSize: 12),
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 11),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            isDense: true,
          ),
        ),
        // Ingen auto-login längre (se ConfigProvider) — visa LoginScreen
        // tills en session faktiskt är upprättad, istället för att kräva
        // att man navigerar till Settings-vyn.
        home: Consumer<ConfigProvider>(
          builder: (context, provider, _) {
            // Vänta tills en ev. sparad session hunnit återställas och
            // valideras (se ConfigProvider._loadSavedUrl) — annars blinkar
            // inloggningsvyn till vid en sid-refresh i webb-GUI:t innan
            // sessionen återupptas.
            if (provider.isInitializing) {
              return const Scaffold(
                backgroundColor: Color(0xFF0F172A),
                body: Center(child: CircularProgressIndicator(color: Colors.cyanAccent)),
              );
            }
            return provider.isAuthenticated ? const MainScreen() : const LoginScreen();
          },
        ),
      ),
    );
  }
}
