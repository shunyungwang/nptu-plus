/// 設定：分組式清單，一組一張卡，不為每個項目各開一張卡。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/widgets/app_surfaces.dart';

const List<(ThemeMode, String, IconData)> kThemeOptions = [
  (ThemeMode.light, '淺色（Pure White）', Icons.light_mode_outlined),
  (ThemeMode.dark, '深色（OLED Black）', Icons.dark_mode_outlined),
  (ThemeMode.system, '跟隨系統', Icons.brightness_auto_outlined),
];

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    var warning = false;
    try {
      final serverConfirmed = await ref
          .read(authStatusProvider.notifier)
          .signOut();
      warning = !serverConfirmed;
    } catch (_) {
      warning = true;
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
    if (!mounted) return;
    if (warning) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('此裝置已登出；校務系統未確認伺服器端登出。')));
    }
    GoRouter.of(context).go(kRouteLogin);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mode = ref.watch(themeModeProvider);
    final account = ref.watch(currentAccountProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: AppDimensions.pageInsets,
        children: [
          const AppSectionHeader(title: '外觀'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: RadioGroup<ThemeMode>(
              groupValue: mode,
              onChanged: (value) => ref
                  .read(themeModeProvider.notifier)
                  .setMode(value ?? ThemeMode.system),
              child: Column(
                children: [
                  for (
                    var index = 0;
                    index < kThemeOptions.length;
                    index++
                  ) ...[
                    if (index > 0) const Divider(height: 1),
                    RadioListTile<ThemeMode>(
                      value: kThemeOptions[index].$1,
                      title: Text(
                        kThemeOptions[index].$2,
                        style: theme.textTheme.bodyMedium,
                      ),
                      secondary: Icon(
                        kThemeOptions[index].$3,
                        size: AppDimensions.iconMedium,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.cardPadding,
                      ),
                      dense: true,
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: AppDimensions.sectionGap),
          const AppSectionHeader(title: '帳號'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.cardPadding,
                  ),
                  title: Text('目前帳號', style: theme.textTheme.bodyMedium),
                  subtitle: Text(
                    account ?? '未登入',
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: const Icon(
                    Icons.badge_outlined,
                    size: AppDimensions.iconMedium,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.cardPadding,
                  ),
                  onTap: _signingOut ? null : _signOut,
                  leading: _signingOut
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.logout,
                          size: AppDimensions.iconMedium,
                          color: theme.colorScheme.error,
                        ),
                  title: Text(
                    _signingOut ? '正在登出…' : '登出',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppDimensions.sectionGap),
          const AppSectionHeader(title: '關於'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.cardPadding,
                  ),
                  title: Text('版本', style: theme.textTheme.bodyMedium),
                  trailing: Text('1.0.0+1', style: theme.textTheme.bodySmall),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.cardPadding,
                  ),
                  title: Text('資料來源', style: theme.textTheme.bodyMedium),
                  subtitle: Text(
                    '國立屏東大學校務系統',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
