/// Theme 總裝：Pure White / OLED Black 兩個 ThemeData 的唯一組裝點。
library;

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_components.dart';
import 'app_dimensions.dart';
import 'app_radius.dart';
import 'app_typography.dart';

ThemeData buildLightTheme() {
  final scheme = buildLightScheme();
  return _assemble(scheme, buildAppTextTheme(Brightness.light, scheme));
}

ThemeData buildDarkTheme() {
  final scheme = buildDarkScheme();
  return _assemble(scheme, buildAppTextTheme(Brightness.dark, scheme));
}

ThemeData _assemble(ColorScheme scheme, TextTheme text) {
  return ThemeData(
    useMaterial3: true,
    brightness: scheme.brightness,
    colorScheme: scheme,
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    splashFactory: InkSparkle.splashFactory,
    inputDecorationTheme: buildInputDecorationTheme(text),
    filledButtonTheme: FilledButtonThemeData(style: buildFilledButton(text)),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: buildOutlinedButton(text),
    ),
    textButtonTheme: TextButtonThemeData(style: buildTextButton(text)),
    cardTheme: buildCardTheme(scheme),
    chipTheme: buildChipTheme(scheme, text),
    dialogTheme: buildDialogTheme(scheme),
    bottomSheetTheme: buildBottomSheetTheme(scheme),
    navigationBarTheme: buildNavigationBarTheme(scheme, text),
    snackBarTheme: buildSnackBarTheme(scheme, text),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: AppDimensions.pagePadding,
      toolbarHeight: 60,
      titleTextStyle: text.titleLarge,
      iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.pagePadding,
        vertical: 2,
      ),
      iconColor: scheme.onSurfaceVariant,
      textColor: scheme.onSurface,
      minVerticalPadding: 10,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
      circularTrackColor: Colors.transparent,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        // 淡入位移：輕量、無模糊，適合高刷新率裝置。
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
      },
    ),
  );
}
