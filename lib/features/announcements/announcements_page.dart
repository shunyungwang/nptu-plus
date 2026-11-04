/// 公告：以日期為視覺錨點的可掃讀列表，點擊進入閱讀頁。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_surfaces.dart';
import '../student_data_providers.dart';

class AnnouncementsPage extends ConsumerWidget {
  const AnnouncementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(announcementsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('公告'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(announcementsProvider),
            icon: const Icon(Icons.refresh),
            tooltip: '重新載入',
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: data.when(
        loading: () => const AppLoadingView(message: '正在載入公告'),
        error: (error, _) => AppErrorView(
          message: '$error',
          onRetry: () => ref.invalidate(announcementsProvider),
        ),
        data: (items) => items.isEmpty
            ? const AppEmptyView(icon: Icons.campaign_outlined, title: '目前沒有公告')
            : ListView.separated(
                padding: AppDimensions.pageInsets,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 2),
                itemBuilder: (context, index) =>
                    _AnnouncementTile(item: items[index]),
              ),
      ),
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  const _AnnouncementTile({required this.item});

  final Map<String, String> item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = _splitDate(item['date'] ?? '');
    final meta = [
      item['unit'],
      item['category'],
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AnnouncementDetailPage(item: item),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppDimensions.rowVertical,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 48,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(date.$1, style: theme.textTheme.bodySmall),
                  Text(
                    date.$2,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'] ?? '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(meta, style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Icon(
              Icons.chevron_right,
              size: AppDimensions.iconSmall,
              color: theme.colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}

/// 公告閱讀頁：大字標題 + 中繼資訊 + 內文說明。
class AnnouncementDetailPage extends StatelessWidget {
  const AnnouncementDetailPage({super.key, required this.item});

  final Map<String, String> item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = [
      item['date'],
      item['unit'],
      item['category'],
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');
    return Scaffold(
      appBar: AppBar(title: const Text('公告')),
      body: ListView(
        padding: AppDimensions.pageInsets,
        children: [
          Text(item['title'] ?? '', style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.s),
          Text(meta, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.l),
          const Divider(),
          const SizedBox(height: AppSpacing.l),
          Text(
            '此公告由校務系統首頁同步，僅提供標題與發布資訊。完整內容與附件請至校務系統查看。',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// `2026/10/30` → (`10 月`, `30`)；無法解析時保留原文。
(String, String) _splitDate(String raw) {
  final parts = RegExp(r'\d+')
      .allMatches(raw.trim())
      .map((match) => match.group(0)!)
      .toList();
  if (parts.length >= 3) {
    return ('${int.tryParse(parts[parts.length - 2]) ?? 0} 月', parts.last);
  }
  if (parts.length == 2) {
    return ('${int.tryParse(parts.first) ?? 0} 月', parts.last);
  }
  return ('', raw);
}
