import 'package:flutter/material.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  void toggleTheme() {
    if (_themeMode == ThemeMode.system) {
      _themeMode = WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    } else {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    }

    notifyListeners();
  }

  ThemeData lightTheme(ColorScheme? dynamicLight) {
    return ThemeData(
      colorScheme: dynamicLight ??
          ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.light,
          ),
      useMaterial3: true,
    );
  }

  ThemeData darkTheme(ColorScheme? dynamicDark) {
    return ThemeData(
      colorScheme: dynamicDark ??
          ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
      useMaterial3: true,
    );
  }

  ThemeData get themeData {
    if (_themeMode == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark
          ? darkTheme(null)
          : lightTheme(null);
    }
    return _themeMode == ThemeMode.light ? lightTheme(null) : darkTheme(null);
  }
}