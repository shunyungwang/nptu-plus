/// 色彩 Token：Pure White（Light）與 True OLED Black（Dark）雙主題。
///
/// 設計原則：
/// - Light Mode 頁面底色固定 `#FFFFFF`，層次靠細邊框、留白與字重建立。
/// - Dark Mode 頁面底色固定 `#000000`，Surface 使用 `#0A0A0A` / `#111111`，
///   不用整片深灰當背景。
/// - 兩者共用同一組語意角色，因此排版與元件不需要為主題各寫一套。
library;

import 'package:flutter/material.dart';

/// 屏東大學 CI 深綠（品牌種子色）。
const Color kNptuSeed = Color(0xFF1B7A43);

/// 深色模式種子略亮，維持可讀對比。
const Color kNptuSeedDark = Color(0xFF5FBF87);

/// 純白頁面底色。
const Color kLightSurface = Color(0xFFFFFFFF);

/// OLED 純黑頁面底色。
const Color kDarkSurface = Color(0xFF000000);

/// OLED 卡片底色。
const Color kDarkElevated = Color(0xFF0A0A0A);

/// OLED 較高層級容器（Dialog / BottomSheet）。
const Color kDarkElevatedHigh = Color(0xFF111111);

ColorScheme buildLightScheme() {
  final base = ColorScheme.fromSeed(
    seedColor: kNptuSeed,
    brightness: Brightness.light,
  );
  return base.copyWith(
    surface: kLightSurface,
    onSurface: const Color(0xFF111318),
    onSurfaceVariant: const Color(0xFF59616A),
    surfaceContainerLowest: kLightSurface,
    surfaceContainerLow: kLightSurface,
    surfaceContainer: kLightSurface,
    surfaceContainerHigh: kLightSurface,
    surfaceContainerHighest: const Color(0xFFF3F5F7),
    outlineVariant: const Color(0xFFE4E7EB),
    outline: const Color(0xFF98A0A8),
  );
}

ColorScheme buildDarkScheme() {
  final base = ColorScheme.fromSeed(
    seedColor: kNptuSeedDark,
    brightness: Brightness.dark,
  );
  return base.copyWith(
    surface: kDarkSurface,
    onSurface: const Color(0xFFF1F3F5),
    onSurfaceVariant: const Color(0xFF9AA2AA),
    surfaceContainerLowest: kDarkSurface,
    surfaceContainerLow: kDarkElevated,
    surfaceContainer: kDarkElevated,
    surfaceContainerHigh: kDarkElevatedHigh,
    surfaceContainerHighest: const Color(0xFF171717),
    outlineVariant: const Color(0xFF232323),
    outline: const Color(0xFF4A4F55),
  );
}

/// 語意色（亮／暗各自對應，避免深色模式對比不足）。
class AppSemanticColors {
  const AppSemanticColors._();

  static const Color successLight = Color(0xFF2E7D32);
  static const Color successDark = Color(0xFF81C784);
  static const Color warningLight = Color(0xFFB26A00);
  static const Color warningDark = Color(0xFFFFB74D);
  static const Color requiredLight = Color(0xFFC62828);
  static const Color requiredDark = Color(0xFFE57373);

  static Color success(Brightness b) =>
      b == Brightness.light ? successLight : successDark;
  static Color warning(Brightness b) =>
      b == Brightness.light ? warningLight : warningDark;
  static Color required(Brightness b) =>
      b == Brightness.light ? requiredLight : requiredDark;
}
