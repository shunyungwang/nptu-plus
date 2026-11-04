/// 選課查詢：課程資訊以層級化文字呈現，不使用卡片堆疊。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_surfaces.dart';
import '../student_data_providers.dart';

class CourseSelectionPage extends ConsumerWidget {
  const CourseSelectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(coursesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('選課查詢'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(coursesProvider),
            icon: const Icon(Icons.refresh),
            tooltip: '重新載入',
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: data.when(
        loading: () => const AppLoadingView(message: '正在載入課程'),
        error: (error, _) => AppErrorView(
          message: '$error',
          onRetry: () => ref.invalidate(coursesProvider),
        ),
        data: (items) => items.isEmpty
            ? const AppEmptyView(icon: Icons.class_outlined, title: '這學期沒有已選課程')
            : ListView(
                padding: AppDimensions.pageInsets,
                children: [
                  AppSectionHeader(
                    title: '本學期課程',
                    caption: '${items.length} 門',
                  ),
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Column(
                      children: [
                        for (var index = 0; index < items.length; index++) ...[
                          if (index > 0) const Divider(height: 1),
                          _CourseEntry(course: items[index]),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _CourseEntry extends StatelessWidget {
  const _CourseEntry({required this.course});

  final Map<String, String> course;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final schedule = [
      _weekdayLabel(course['weekday'] ?? ''),
      (course['period'] ?? '').trim(),
    ].where((value) => value.isNotEmpty).join(' ');
    final meta = [
      schedule,
      course['room'],
      course['teacher'],
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');
    final credits = (course['credits'] ?? '').trim();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.cardPadding,
        vertical: AppDimensions.rowVertical,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                const SizedBox(height: 3),
                Text(meta, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          if (credits.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.m),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(credits, style: theme.textTheme.titleMedium),
                Text('學分', style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String _weekdayLabel(String raw) {
  final day = int.tryParse(RegExp(r'\d').firstMatch(raw)?.group(0) ?? '');
  if (day == null || day < 1 || day > 7) return '';
  return '週${const ['一', '二', '三', '四', '五', '六', '日'][day - 1]}';
}
