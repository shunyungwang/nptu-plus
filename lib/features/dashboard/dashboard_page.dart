/// 首頁：以「今天要用到的資訊」為優先的資訊層級。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/period_format.dart';
import '../../core/widgets/app_surfaces.dart';
import '../student_data_providers.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final courses = ref.watch(coursesProvider);
    final announcements = ref.watch(announcementsProvider);
    final profile = ref.watch(profileProvider);
    final now = DateTime.now();
    final weekday = now.weekday;

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
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(coursesProvider);
          ref.invalidate(announcementsProvider);
          ref.invalidate(profileProvider);
        },
        child: ListView(
          padding: AppDimensions.pageInsets,
          children: [
            // ---- 招呼與日期（純文字，不用卡片） ----
            profile.maybeWhen(
              data: (student) =>
                  Text(_greeting(now), style: theme.textTheme.bodySmall),
              orElse: () =>
                  Text(_greeting(now), style: theme.textTheme.bodySmall),
            ),
            const SizedBox(height: AppDimensions.tightGap),
            profile.maybeWhen(
              data: (student) => Text(
                student.name.isEmpty ? '同學' : student.name,
                style: theme.textTheme.headlineSmall,
              ),
              orElse: () => Text('同學', style: theme.textTheme.headlineSmall),
            ),
            const SizedBox(height: AppDimensions.tightGap),
            Text(_dateLabel(now), style: theme.textTheme.bodySmall),

            const SizedBox(height: AppDimensions.sectionGap),
            AppSectionHeader(
              title: '今日課程',
              actionLabel: '課表',
              onAction: () => context.go(kRouteTimetable),
            ),
            courses.when(
              loading: () => const AppCard(
                child: SizedBox(
                  height: 64,
                  child: AppLoadingView(message: '正在載入課程'),
                ),
              ),
              error: (_, _) => AppCard(
                child: _InlineMessage(
                  text: '課程載入失敗，請下拉重新整理。',
                  onRetry: () => ref.invalidate(coursesProvider),
                ),
              ),
              data: (items) {
                final today = items
                    .where(
                      (course) => RegExp(r'\d+')
                          .allMatches(course['weekday'] ?? '')
                          .any(
                            (match) =>
                                int.tryParse(match.group(0) ?? '') == weekday,
                          ),
                    )
                    .toList();
                if (today.isEmpty) {
                  return const AppCard(child: _InlineMessage(text: '今天沒有排定課程'));
                }
                today.sort(
                  (a, b) => (a['period'] ?? '').compareTo(b['period'] ?? ''),
                );
                return AppCard(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Column(
                    children: [
                      for (var index = 0; index < today.length; index++) ...[
                        if (index > 0) const Divider(height: 1),
                        _CourseRow(course: today[index]),
                      ],
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: AppDimensions.sectionGap),
            AppSectionHeader(
              title: '最新公告',
              actionLabel: '查看全部',
              onAction: () => context.go(kRouteAnnouncements),
            ),
            announcements.when(
              loading: () => const AppCard(
                child: SizedBox(
                  height: 64,
                  child: AppLoadingView(message: '正在載入公告'),
                ),
              ),
              error: (_, _) => AppCard(
                child: _InlineMessage(
                  text: '公告載入失敗。',
                  onRetry: () => ref.invalidate(announcementsProvider),
                ),
              ),
              data: (items) => items.isEmpty
                  ? const AppCard(child: _InlineMessage(text: '目前沒有公告'))
                  : AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            items.first['title'] ?? '',
                            style: theme.textTheme.titleSmall,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppDimensions.tightGap),
                          Text(
                            [items.first['date'], items.first['unit']]
                                .whereType<String>()
                                .where((v) => v.isNotEmpty)
                                .join(' · '),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
            ),

            const SizedBox(height: AppDimensions.sectionGap),
            const AppSectionHeader(title: '常用功能'),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  _QuickAction(
                    icon: Icons.event_available_outlined,
                    label: '出缺勤',
                    onTap: () => context.push(kRouteAttendance),
                  ),
                  _QuickAction(
                    icon: Icons.class_outlined,
                    label: '選課',
                    onTap: () => context.push(kRouteCourseSelection),
                  ),
                  _QuickAction(
                    icon: Icons.event_busy_outlined,
                    label: '請假',
                    onTap: () => context.push(kRouteLeaveApplication),
                  ),
                  _QuickAction(
                    icon: Icons.badge_outlined,
                    label: '個人',
                    onTap: () => context.push(kRouteProfile),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _greeting(DateTime now) {
  if (now.hour < 12) return '早安';
  if (now.hour < 18) return '午安';
  return '晚安';
}

String _dateLabel(DateTime now) {
  const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
  return '${now.month} 月 ${now.day} 日 · 星期${weekdays[now.weekday - 1]}';
}

class _CourseRow extends StatelessWidget {
  const _CourseRow({required this.course});

  final Map<String, String> course;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final period = (course['period'] ?? '').trim();
    final details = [
      course['room'],
      course['teacher'],
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.cardPadding,
        vertical: AppDimensions.rowVertical - 2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: Text(
              formatPeriodRange(period),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course['name'] ?? '',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    details,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
      child: Row(
        children: [
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('重試')),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
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
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
          child: Column(
            children: [
              Icon(
                icon,
                size: AppDimensions.iconMedium,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(label, style: theme.textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}
