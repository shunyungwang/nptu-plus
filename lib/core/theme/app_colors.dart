/// 色彩 Token：整個 App 的顏色由此單一檔案管理。
///
/// 設計原則：
/// - 以屏大校徽的深綠作為品牌種子色。
/// - 淺色與深色分別以 [ColorScheme.fromSeed] 生成，不直接反轉顏色。
/// - 進一步的語意色（成功/警告等）放 [AppSemanticColors]。
library;

import 'package:flutter/material.dart';

/// Material 3 種子色。
/// 屏東大學 CI 為深綠色系，取近似的穩定種子。
const Color kNptuSeed = Color(0xFF1B7A43);

/// 針對不同亮度的種子微調（深色模式種子略亮，避免對比不足）。
const Color kNptuSeedDark = Color(0xFF57A973);

/// 生成亮色 ColorScheme。
ColorScheme buildLightScheme() =>
    ColorScheme.fromSeed(seedColor: kNptuSeed, brightness: Brightness.light);

/// 生成深色 ColorScheme。
ColorScheme buildDarkScheme() =>
    ColorScheme.fromSeed(seedColor: kNptuSeedDark, brightness: Brightness.dark);

/// 語意色（各自於亮/暗模式下使用不同值）。
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
