/// Common Component Token：按鈕、輸入框、卡片、導航的統一樣式。
///
/// 這裡只定義「可重複使用的元件主題」，頁面不得自寫樣式難以維護的內聯值。
library;

import 'package:flutter/material.dart';

import 'app_radius.dart';
import 'app_spacing.dart';

/// 輸入框統一樣式（登入、查詢表單共用）。
InputDecorationTheme buildInputDecorationTheme(TextTheme textTheme) =>
    InputDecorationTheme(
      filled: true,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(width: 2),
      ),
      helperStyle: textTheme.bodySmall,
      errorStyle: textTheme.bodySmall,
    );

/// 主按鈕樣式。
ButtonStyle buildFilledButton(TextTheme textTheme) => FilledButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: 14),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.sm),
  ),
  textStyle: textTheme.labelLarge,
);

/// 次按鈕樣式。
ButtonStyle buildOutlinedButton(TextTheme textTheme) =>
    OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      textStyle: textTheme.labelLarge,
    );

/// 卡片樣式 — 低 elevation、細邊框、統一圓角。
CardThemeData buildCardTheme(ColorScheme scheme) => CardThemeData(
  elevation: 0,
  color: scheme.surfaceContainerLow,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
    side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
  ),
  margin: EdgeInsets.zero,
  clipBehavior: Clip.antiAlias,
);

/// Dialog 樣式。
DialogThemeData buildDialogTheme(ColorScheme scheme) => DialogThemeData(
  backgroundColor: scheme.surfaceContainerHigh,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.dialog),
  ),
);

/// NavigationBar 樣式（底部導航）。
NavigationBarThemeData buildNavigationBarTheme(ColorScheme scheme) =>
    NavigationBarThemeData(
      height: 72,
      backgroundColor: scheme.surfaceContainer,
      indicatorColor: scheme.secondaryContainer,
      elevation: 0,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    );

/// BottomSheet 樣式。
BottomSheetThemeData buildBottomSheetTheme(ColorScheme scheme) =>
    BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      showDragHandle: true,
    );
