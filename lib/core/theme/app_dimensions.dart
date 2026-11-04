/// Layout Dimension Token：全站唯一的版面尺寸來源。
///
/// 頁面不得再自行寫 `EdgeInsets.all(16)` 或 `height: 88`；
/// 一律引用這裡的語意化名稱，確保每頁邊距、間距、元件高度完全一致。
library;

import 'package:flutter/material.dart';

abstract final class AppDimensions {
  // ---- 頁面 ----
  /// 頁面左右邊距（全站統一）。
  static const double pagePadding = 20;

  /// 頁面底部留白（避開手勢區／導覽列）。
  static const double pageBottomPadding = 40;

  /// 頁面內容起點（AppBar 下方）。
  static const double pageTopPadding = 8;

  /// 標準頁面內距。
  static const EdgeInsets pageInsets = EdgeInsets.fromLTRB(
    pagePadding,
    pageTopPadding,
    pagePadding,
    pageBottomPadding,
  );

  /// 只有左右邊距（內容自行處理垂直間距時使用）。
  static const EdgeInsets pageHorizontal = EdgeInsets.symmetric(
    horizontal: pagePadding,
  );

  // ---- 區塊與間距 ----
  /// 兩個 Section 之間。
  static const double sectionGap = 28;

  /// Section 標題與其內容之間。
  static const double sectionHeaderGap = 10;

  /// 同一個 Section 內相鄰項目。
  static const double itemGap = 10;

  /// 小間距（同一列的文字與數值）。
  static const double tightGap = 4;

  // ---- 卡片 ----
  static const double cardRadius = 16;
  static const double cardPadding = 16;
  static const double cardBorderWidth = 1;

  // ---- 元件尺寸 ----
  /// 主要按鈕高度。
  static const double buttonHeight = 52;

  /// 輸入框高度。
  static const double inputHeight = 52;

  /// 最小觸控目標。
  static const double minTouchTarget = 48;

  /// 底部導覽列高度。
  static const double navBarHeight = 72;

  /// 頭像尺寸。
  static const double avatarSmall = 40;
  static const double avatarLarge = 64;

  /// Icon 尺寸。
  static const double iconSmall = 18;
  static const double iconMedium = 22;
  static const double iconLarge = 28;

  /// 清單列的垂直內距。
  static const double rowVertical = 14;
}
