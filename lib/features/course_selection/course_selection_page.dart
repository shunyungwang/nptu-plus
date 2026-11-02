/// Read only list of courses already selected in the current term.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../student_data_providers.dart';

class CourseSelectionPage extends ConsumerWidget {
  const CourseSelectionPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(coursesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('選課查詢'), actions: [
        IconButton(onPressed: () => ref.invalidate(coursesProvider), icon: const Icon(Icons.refresh)),
      ]),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: TextButton.icon(
          onPressed: () => ref.invalidate(coursesProvider), icon: const Icon(Icons.refresh), label: Text('課程載入失敗，點擊重試：$e'))),
        data: (items) => items.isEmpty
            ? const Center(child: Text('這學期沒有已選課程'))
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.l), itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s),
                itemBuilder: (context, i) {
                  final c = items[i];
                  return Card(child: ListTile(
                    leading: CircleAvatar(child: Text(c['credits'] ?? '')),
                    title: Text(c['name'] ?? ''),
                    subtitle: Text('${c['code']} · ${c['type']} · ${c['teacher']}\n${c['weekday']} ${c['period']} · ${c['room']}'),
                    isThreeLine: true,
                  ));
                },
              ),
      ),
    );
  }
}
