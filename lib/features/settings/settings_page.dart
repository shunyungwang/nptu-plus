/// 設定頁：主題模式（Light / Dark / Follow System）、登出、版本資訊。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/theme/app_spacing.dart';

/// 主題選項的展示用清單。
const List<(ThemeMode, String, IconData)> kThemeOptions = [
  (ThemeMode.light, '淺色模式', Icons.light_mode_outlined),
  (ThemeMode.dark, '深色模式', Icons.dark_mode_outlined),
  (ThemeMode.system, '跟隨系統', Icons.nights_stay_outlined),
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
      final serverConfirmed = await ref.read(authStatusProvider.notifier).signOut();
      warning = !serverConfirmed;
    } catch (_) {
      // Local credentials are cleared in the repository's finally block.
      warning = true;
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
    if (!mounted) return;
    if (warning) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('此裝置已登出；校務系統未確認伺服器端登出。')),
      );
    }
    GoRouter.of(context).go(kRouteLogin);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mode = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          Text('外觀', style: theme.textTheme.titleMedium),
          RadioGroup<ThemeMode>(
            groupValue: mode,
            onChanged: (value) => ref
                .read(themeModeProvider.notifier)
                .setMode(value ?? ThemeMode.system),
            child: Column(
              children: [
                for (final (m, label, icon) in kThemeOptions)
                  RadioListTile<ThemeMode>(
                    value: m,
                    title: Text(label),
                    secondary: Icon(icon),
                  ),
              ],
            ),
          ),
          const Divider(height: AppSpacing.xl),
          Text('帳號', style: theme.textTheme.titleMedium),
          ListTile(
            leading: _signingOut
                ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.logout),
            title: Text(_signingOut ? '正在登出…' : '登出'),
            subtitle: const Text('登出此裝置並結束校務系統工作階段'),
            onTap: _signingOut ? null : _signOut,
          ),
          const Divider(height: AppSpacing.xl),
          const AboutListTile(
            icon: Icon(Icons.info_outline),
            applicationName: 'NPTU 校務系統',
            applicationVersion: '1.0.0+1',
            aboutBoxChildren: [Text('國立屏東大學專屬校務系統 Android App')],
          ),
        ],
      ),
    );
  }
}
