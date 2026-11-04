/// Common Component Token：按鈕、輸入框、卡片、導航的統一樣式。
///
/// 頁面只能透過這些主題與 [AppCard] 取得樣式，不得自行寫死顏色或高度。
library;

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimensions.dart';
import 'app_radius.dart';
import 'app_spacing.dart';

const OutlineInputBorder _inputBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
  borderSide: BorderSide.none,
);

InputDecorationTheme buildInputDecorationTheme(TextTheme textTheme) =>
    InputDecorationTheme(
      filled: true,
      isDense: true,
      constraints: const BoxConstraints(minHeight: AppDimensions.inputHeight),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: AppSpacing.m,
      ),
      border: _inputBorder,
      enabledBorder: _inputBorder,
      focusedBorder: _inputBorder.copyWith(
        borderSide: const BorderSide(width: 1.6),
      ),
      errorBorder: _inputBorder.copyWith(
        borderSide: BorderSide(color: AppSemanticColors.required(Brightness.light)),
      ),
      hintStyle: textTheme.bodyMedium,
      helperStyle: textTheme.bodySmall,
      errorStyle: textTheme.bodySmall,
    );

ButtonStyle buildFilledButton(TextTheme textTheme) => FilledButton.styleFrom(
  minimumSize: const Size(0, AppDimensions.buttonHeight),
  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
  ),
  textStyle: textTheme.labelLarge,
);

ButtonStyle buildOutlinedButton(TextTheme textTheme) =>
    OutlinedButton.styleFrom(
      minimumSize: const Size(0, AppDimensions.buttonHeight),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
      ),
      textStyle: textTheme.labelLarge,
      side: const BorderSide(width: 1),
    );

/// 文字按鈕（次要操作）：統一高度與內距，避免各頁大小不一。
ButtonStyle buildTextButton(TextTheme textTheme) => TextButton.styleFrom(
  minimumSize: const Size(0, AppDimensions.minTouchTarget),
  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
  textStyle: textTheme.labelLarge,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
  ),
);

/// 卡片樣式：細邊框、無陰影、統一圓角，兩種主題共用。
CardThemeData buildCardTheme(ColorScheme scheme) => CardThemeData(
  elevation: 0,
  color: scheme.surfaceContainerLow,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
    side: BorderSide(
      color: scheme.outlineVariant,
      width: AppDimensions.cardBorderWidth,
    ),
  ),
  margin: EdgeInsets.zero,
  clipBehavior: Clip.antiAlias,
);

DialogThemeData buildDialogTheme(ColorScheme scheme) => DialogThemeData(
  backgroundColor: scheme.surfaceContainerHigh,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.lg),
  ),
);

NavigationBarThemeData buildNavigationBarTheme(
  ColorScheme scheme,
  TextTheme textTheme,
) => NavigationBarThemeData(
  height: AppDimensions.navBarHeight,
  backgroundColor: scheme.surface,
  indicatorColor: scheme.secondaryContainer,
  elevation: 0,
  surfaceTintColor: Colors.transparent,
  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
  labelTextStyle: WidgetStateProperty.resolveWith(
    (states) => textTheme.labelMedium?.copyWith(
      color: states.contains(WidgetState.selected)
          ? scheme.onSurface
          : scheme.onSurfaceVariant,
    ),
  ),
);

BottomSheetThemeData buildBottomSheetTheme(ColorScheme scheme) =>
    BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      showDragHandle: true,
    );

ChipThemeData buildChipTheme(ColorScheme scheme, TextTheme textTheme) =>
    ChipThemeData(
      backgroundColor: scheme.surfaceContainerHighest,
      side: BorderSide.none,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: 2,
      ),
      labelStyle: textTheme.labelMedium,
      labelPadding: EdgeInsets.zero,
    );

SnackBarThemeData buildSnackBarTheme(ColorScheme scheme, TextTheme textTheme) =>
    SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.onInverseSurface,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
      ),
      insetPadding: const EdgeInsets.all(AppSpacing.l),
    );
