import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppAccent {
  zinc('Zinc', Color(0xFF18181B)),
  blue('Blue', Color(0xFF2563EB)),
  violet('Violet', Color(0xFF7C3AED)),
  green('Green', Color(0xFF16A34A)),
  orange('Orange', Color(0xFFEA580C)),
  rose('Rose', Color(0xFFE11D48));

  const AppAccent(this.label, this.swatch);

  final String label;
  final Color swatch;

  FThemeData get light => switch (this) {
        AppAccent.zinc => FThemes.zinc.light,
        AppAccent.blue => FThemes.blue.light,
        AppAccent.violet => FThemes.violet.light,
        AppAccent.green => FThemes.green.light,
        AppAccent.orange => FThemes.orange.light,
        AppAccent.rose => FThemes.rose.light,
      };

  FThemeData get dark => switch (this) {
        AppAccent.zinc => FThemes.zinc.dark,
        AppAccent.blue => FThemes.blue.dark,
        AppAccent.violet => FThemes.violet.dark,
        AppAccent.green => FThemes.green.dark,
        AppAccent.orange => FThemes.orange.dark,
        AppAccent.rose => FThemes.rose.dark,
      };
}

class ThemeService extends ChangeNotifier {
  ThemeService._();
  static final ThemeService instance = ThemeService._();

  static const _modeKey = 'settings.theme_mode';
  static const _accentKey = 'settings.theme_accent';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  AppAccent _accent = AppAccent.zinc;
  AppAccent get accent => _accent;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _mode = switch (prefs.getString(_modeKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    final accentName = prefs.getString(_accentKey);
    _accent = AppAccent.values.firstWhere((a) => a.name == accentName, orElse: () => AppAccent.zinc);
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode.name);
  }

  Future<void> setAccent(AppAccent accent) async {
    if (_accent == accent) return;
    _accent = accent;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accentKey, accent.name);
  }
}
