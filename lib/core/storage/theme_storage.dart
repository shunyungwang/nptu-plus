/// 主題偏好持久化（SharedPreferences）。
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主題模式鍵值。
const String kThemeModeKey = 'app.themeMode';

/// 讀取已保存的主題模式；首次啟動（無紀錄）→ Follow System。
ThemeMode loadThemeMode(SharedPreferences prefs) {
  final raw = prefs.getString(kThemeModeKey);
  switch (raw) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

/// 保存主題模式。
Future<void> saveThemeMode(SharedPreferences prefs, ThemeMode mode) async {
  final raw = switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    _ => 'system',
  };
  await prefs.setString(kThemeModeKey, raw);
}
