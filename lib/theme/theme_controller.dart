import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  static final ThemeController instance = ThemeController._internal();
  ThemeController._internal();

  static const _key = 'theme_mode';

  ThemeMode _mode = ThemeMode.dark; // padrão inicial antes do initialize()

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  /// Deve ser chamado em main() antes de runApp().
  /// Padrão para novos usuários (sem preferência salva): dark mode.
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    // null = primeiro acesso → dark mode por padrão
    _mode = saved == 'light' ? ThemeMode.light : ThemeMode.dark;
  }

  Future<void> toggle() async {
    _mode = isDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, isDark ? 'dark' : 'light');
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode == ThemeMode.dark ? 'dark' : 'light');
  }
}
