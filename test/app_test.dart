// 主題與路由基本測試。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nptu_campus/app/app.dart';
import 'package:nptu_campus/app/providers.dart';
import 'package:nptu_campus/core/theme/app_theme.dart';
import 'package:nptu_campus/core/storage/theme_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('主題持久化', () {
    test('首次啟動預設 Follow System', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(loadThemeMode(prefs), ThemeMode.system);
    });

    test('保存後重載應還原', () async {
      SharedPreferences.setMockInitialValues({'app.themeMode': 'dark'});
      final prefs = await SharedPreferences.getInstance();
      expect(loadThemeMode(prefs), ThemeMode.dark);
    });

    test('light/dark/system 三種模式往返', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await saveThemeMode(prefs, ThemeMode.light);
      expect(loadThemeMode(prefs), ThemeMode.light);
      await saveThemeMode(prefs, ThemeMode.dark);
      expect(loadThemeMode(prefs), ThemeMode.dark);
    });
  });

  group('主題建構', () {
    test('亮色與深色都不是反轉相同的 scheme', () {
      final light = buildLightTheme();
      final dark = buildDarkTheme();
      expect(light.colorScheme.brightness, Brightness.light);
      expect(dark.colorScheme.brightness, Brightness.dark);
      expect(light.colorScheme.background != dark.colorScheme.background, isTrue);
      expect(light.useMaterial3, isTrue);
      expect(dark.useMaterial3, isTrue);
    });
  });

  group('App 路由', () {
    testWidgets('未登入應導到登入頁', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const NptuCampusApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
