/// Theme 總裝：亮色與深色的 ThemeData 單一組裝點。
///
/// Material 3 + 統一色彩/字體/圓角/元件 Token，兩種模式完全對應。
library;

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_components.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// 亮色主題。
ThemeData buildLightTheme() {
  final scheme = buildLightScheme();
  final text = buildAppTextTheme(Brightness.light, scheme);
  return _assemble(scheme, text);
}

/// 深色主題。
ThemeData buildDarkTheme() {
  final scheme = buildDarkScheme();
  final text = buildAppTextTheme(Brightness.dark, scheme);
  return _assemble(scheme, text);
}

ThemeData _assemble(ColorScheme scheme, TextTheme text) {
  final scaffoldBg = scheme.surface;
  return ThemeData(
    useMaterial3: true,
    brightness: scheme.brightness,
    colorScheme: scheme,
    textTheme: text,
    scaffoldBackgroundColor: scaffoldBg,
    splashFactory: InkSparkle.splashFactory,
    // ----元件 ----
    inputDecorationTheme: buildInputDecorationTheme(text),
    filledButtonTheme: FilledButtonThemeData(style: buildFilledButton(text)),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: buildOutlinedButton(text),
    ),
    cardTheme: buildCardTheme(scheme),
    dialogTheme: buildDialogTheme(scheme),
    navigationBarTheme: buildNavigationBarTheme(scheme),
    bottomSheetTheme: buildBottomSheetTheme(scheme),
    appBarTheme: AppBarTheme(
      backgroundColor: scaffoldBg,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.6),
      thickness: 1,
      space: 1,
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        // 流暢且輕量的轉場（保持 120fps 友善：避免模糊/陰影重效果）。
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
      },
    ),
  );
}
