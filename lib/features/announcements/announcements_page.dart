/// School announcements from Main.aspx.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../student_data_providers.dart';

class AnnouncementsPage extends ConsumerWidget {
  const AnnouncementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(announcementsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('公告'), actions: [
        IconButton(onPressed: () => ref.invalidate(announcementsProvider), icon: const Icon(Icons.refresh), tooltip: '重新載入'),
      ]),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _StateMessage(text: '公告載入失敗：$e', onRetry: () => ref.invalidate(announcementsProvider)),
        data: (items) => items.isEmpty
            ? const _StateMessage(text: '目前沒有公告')
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.l),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s),
                itemBuilder: (context, i) {
                  final a = items[i];
                  return Card(child: ListTile(
                    title: Text(a['title'] ?? ''),
                    subtitle: Text('${a['date']} · ${a['unit']} · ${a['category']}'),
                    isThreeLine: true,
                    leading: const Icon(Icons.campaign_outlined),
                  ));
                },
              ),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({required this.text, this.onRetry});
  final String text;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(text, textAlign: TextAlign.center),
      if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('重試')),
    ]),
  ));
}
