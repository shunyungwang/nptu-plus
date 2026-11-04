/// 「更多」：分組的功能入口。
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_surfaces.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('更多')),
      body: ListView(
        padding: AppDimensions.pageInsets,
        children: [
          const AppSectionHeader(title: '課務'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                _Entry(
                  icon: Icons.class_outlined,
                  title: '選課查詢',
                  subtitle: '本學期已選課程',
                  route: kRouteCourseSelection,
                ),
                const Divider(height: 1),
                _Entry(
                  icon: Icons.event_available_outlined,
                  title: '出缺勤',
                  subtitle: '曠課與請假紀錄',
                  route: kRouteAttendance,
                ),
                const Divider(height: 1),
                _Entry(
                  icon: Icons.event_busy_outlined,
                  title: '請假申請',
                  subtitle: '新增與取消請假',
                  route: kRouteLeaveApplication,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.sectionGap),
          const AppSectionHeader(title: '個人'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                _Entry(
                  icon: Icons.badge_outlined,
                  title: '個人資料',
                  subtitle: '學籍與聯絡資訊',
                  route: kRouteProfile,
                ),
                const Divider(height: 1),
                _Entry(
                  icon: Icons.tune,
                  title: '設定',
                  subtitle: '外觀、帳號與版本',
                  route: kRouteSettings,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.cardPadding,
      ),
      leading: Icon(icon, size: AppDimensions.iconMedium),
      title: Text(title, style: theme.textTheme.bodyMedium),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      trailing: Icon(
        Icons.chevron_right,
        size: AppDimensions.iconSmall,
        color: theme.colorScheme.outline,
      ),
      onTap: () => context.push(route),
    );
  }
}
