import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/config_provider.dart';
import 'screens/main_screen.dart';

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
          fontFamily: 'Roboto',
        ),
        home: const MainScreen(),
      ),
    );
  }
}
