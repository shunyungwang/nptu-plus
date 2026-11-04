/// 主題模式 Provider（Light / Dark / Follow System）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart' show sharedPreferencesProvider;
import '../storage/theme_storage.dart';

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => loadThemeMode(ref.read(sharedPreferencesProvider));

  void setMode(ThemeMode mode) {
    state = mode;
    saveThemeMode(ref.read(sharedPreferencesProvider), mode);
  }
}
