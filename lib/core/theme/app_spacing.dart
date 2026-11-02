/// Spacing Token：統一留白尺度。
///
/// 命名即數值，避免魔法數字散落 UI code。
library;

abstract final class AppSpacing {
  /// 4 px（微小間距：icon 與文字）。
  static const double xs = 4;

  /// 8 px（小間距：表單欄位內部）。
  static const double s = 8;

  /// 12 px（中間距：清單項目之間）。
  static const double m = 12;

  /// 16 px（標準間距：卡片 padding、區塊間）。
  static const double l = 16;

  /// 24 px（區段間距、頁面水平 padding）。
  static const double xl = 24;

  /// 32 px（大區塊分隔）。
  static const double xxl = 32;
}

abstract final class AppTouch {
  /// Material 最小觸控目標。
  static const double minTarget = 48;
}
