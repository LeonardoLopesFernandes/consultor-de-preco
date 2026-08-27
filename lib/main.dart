import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/theme_provider.dart';
import 'screens/splash_screen.dart';
import 'utils/constants.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    final lightTheme = ThemeData(
      useMaterial3: false,
      primaryColor: const Color(0xFFED0030),
      colorScheme: ColorScheme.fromSwatch().copyWith(
        primary: const Color(0xFFED0030),
        secondary: const Color(0xFFED0030),
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      cardColor: const Color(0xFFFFFFFF),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFED0030),
        foregroundColor: Colors.white,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Color(0xFF333333)),
      ),
    );

    final darkTheme = ThemeData(
      useMaterial3: false,
      primaryColor: const Color(0xFFED0030),
      colorScheme: ColorScheme.fromSwatch(brightness: Brightness.dark).copyWith(
        primary: const Color(0xFFED0030),
        secondary: const Color(0xFFED0030),
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      cardColor: const Color(0xFF1E1E1E),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
      ),
    );

    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeProvider.themeMode,
      home: const SplashScreen(),
    );
  }
}
