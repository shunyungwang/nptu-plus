/// Typography Token：字體階層與行高。
///
/// 只用平台預設字型（Samsung One / Noto Sans TC），靠字重、字級與行高
/// 建立層級；所有頁面共用同一組 TextTheme，不自行宣告 TextStyle。
library;

import 'package:flutter/material.dart';

TextTheme buildAppTextTheme(Brightness brightness, ColorScheme scheme) {
  final base = Typography.material2021().englishLike.merge(
    Typography.material2021().black,
  );
  return base
      .copyWith(
        // 頁面主標題（極少使用，僅大型強調數字）。
        displaySmall: base.displaySmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
          color: scheme.onSurface,
        ),
        // 頁面標題。
        headlineSmall: base.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: scheme.onSurface,
        ),
        headlineMedium: base.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: scheme.onSurface,
        ),
        // 卡片／區塊標題。
        titleLarge: base.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: scheme.onSurface,
        ),
        titleMedium: base.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        titleSmall: base.titleSmall?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        // 內文。
        bodyLarge: base.bodyLarge?.copyWith(
          fontSize: 15,
          height: 1.45,
          color: scheme.onSurface,
        ),
        bodyMedium: base.bodyMedium?.copyWith(
          fontSize: 14,
          height: 1.45,
          color: scheme.onSurface,
        ),
        bodySmall: base.bodySmall?.copyWith(
          fontSize: 12.5,
          height: 1.35,
          color: scheme.onSurfaceVariant,
        ),
        labelLarge: base.labelLarge?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: base.labelMedium?.copyWith(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      )
      .apply(displayColor: scheme.onSurface, bodyColor: scheme.onSurface);
}
