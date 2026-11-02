/// Typography Token：字體排版階層。
///
/// 使用平台預設字型（Samsung One / Noto Sans TC），僅調整權重與行高，
/// 避免外掛字型增加 APK 大小。所有樣式保留 M3 階層名。
library;

import 'package:flutter/material.dart';

/// 依亮度生成 TextTheme（亮/暗分別套用對應主色）。
TextTheme buildAppTextTheme(Brightness brightness, ColorScheme scheme) {
  final base = Typography.material2021().englishLike.merge(
    Typography.material2021().black,
  );
  return base
      .copyWith(
        // 標題都以 medium/semibold 呈現高層級，正文 regular 保持可讀。
        displayLarge: base.displayLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
          color: scheme.onSurface,
        ),
        headlineMedium: base.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        titleLarge: base.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        titleMedium: base.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        bodyLarge: base.bodyLarge?.copyWith(color: scheme.onSurface),
        bodyMedium: base.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      )
      .apply(displayColor: scheme.onSurface, bodyColor: scheme.onSurface);
}
