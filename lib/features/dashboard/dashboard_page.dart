/// 首頁摘要：顯示目前課程與最新公告。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/theme/app_spacing.dart';
import '../student_data_providers.dart';


class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final courses = ref.watch(coursesProvider);
    final announcements = ref.watch(announcementsProvider);
    final profile = ref.watch(profileProvider);
    final weekday = DateTime.now().weekday;
    return Scaffold(
      appBar: AppBar(
        title: const Text('首頁'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: '個人資料',
            onPressed: () => context.push(kRouteProfile),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '設定',
            onPressed: () => context.push(kRouteSettings),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(coursesProvider);
          ref.invalidate(announcementsProvider);
          ref.invalidate(profileProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.l),
          children: [
            // ---- 學生資訊卡 ----
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('歡迎回來', style: theme.textTheme.labelMedium),
                    profile.when(
                      loading: () => Text('同學', style: theme.textTheme.headlineMedium),
                      error: (_, _) => Text('同學', style: theme.textTheme.headlineMedium),
                      data: (student) => Text(
                        student.valueFor(const ['姓名', '中文姓名']).isEmpty
                            ? '同學'
                            : student.valueFor(const ['姓名', '中文姓名']),
                        style: theme.textTheme.headlineMedium,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text('資料來自校務系統', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
            const _SectionHeader(title: '本日課程'),
            courses.when(
              loading: () => const _EmptyHint(icon: Icons.sync, text: '正在載入課程…'),
              error: (_, _) => const _EmptyHint(icon: Icons.error_outline, text: '課程載入失敗，請下拉重試'),
              data: (items) {
                final today = items.where((course) =>
                    RegExp(r'\d+').allMatches(course['weekday'] ?? '').any(
                      (match) => int.tryParse(match.group(0) ?? '') == weekday,
                    )).toList();
                if (today.isEmpty) {
                  return const _EmptyHint(
                    icon: Icons.event_busy_outlined,
                    text: '今天沒有課程',
                  );
                }
                return Column(
                  children: [
                    for (final course in today)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.event_available_outlined),
                          title: Text(course['name'] ?? ''),
                          subtitle: Text(
                            '${course['period']} · ${course['room']} · ${course['teacher']}',
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const _SectionHeader(title: '最新公告'),
            announcements.when(
              loading: () => const _EmptyHint(icon: Icons.sync, text: '正在載入公告…'),
              error: (_, _) => const _EmptyHint(icon: Icons.error_outline, text: '公告載入失敗，請下拉重試'),
              data: (items) => items.isEmpty
                  ? const _EmptyHint(icon: Icons.campaign_outlined, text: '目前沒有公告')
                  : Card(child: ListTile(
                      leading: const Icon(Icons.campaign_outlined),
                      title: Text(items.first['title'] ?? ''),
                      subtitle: Text('${items.first['date']} · ${items.first['unit']}'),
                    )),
            ),
            const _SectionHeader(title: '常用功能'),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: AppSpacing.m,
              mainAxisSpacing: AppSpacing.m,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _Shortcut(
                  icon: Icons.class_outlined,
                  label: '選課查詢',
                  onTap: () => context.push(kRouteCourseSelection),
                ),
                _Shortcut(
                  icon: Icons.history_edu_outlined,
                  label: '出缺勤',
                  onTap: () => context.push(kRouteAttendance),
                ),
                _Shortcut(
                  icon: Icons.badge_outlined,
                  label: '個人資料',
                  onTap: () => context.push(kRouteProfile),
                ),
                _Shortcut(
                  icon: Icons.tune,
                  label: '設定',
                  onTap: () => context.push(kRouteSettings),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.s,
      AppSpacing.xl,
      AppSpacing.s,
      AppSpacing.s,
    ),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: SizedBox(
        height: 88,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: theme.colorScheme.outline),
              const SizedBox(width: AppSpacing.s),
              Text(text, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
      width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: AppSpacing.xs),
            Text(label, style: theme.textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}
