/// Student profile from the read-only A0207S module.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/datasources/webforms_student_api.dart';
import '../student_data_providers.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(profileProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('個人資料'),
        actions: [
          IconButton(
            onPressed: () => context.push(kRouteSettings),
            icon: const Icon(Icons.settings_outlined),
            tooltip: '設定',
          ),
          IconButton(
            onPressed: () => ref.invalidate(profileProvider),
            icon: const Icon(Icons.refresh),
            tooltip: '重新載入',
          ),
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: TextButton.icon(
            onPressed: () => ref.invalidate(profileProvider),
            icon: const Icon(Icons.refresh),
            label: Text('資料載入失敗，點擊重試：$error'),
          ),
        ),
        data: (profile) {
          final name = profile.valueFor(const ['姓名', '中文姓名']);
          final studentId = profile.valueFor(const ['學號', '學生學號']);
          final requestedLabels = <String>[
            '姓名', '中文姓名', '學號', '學生學號', '帳號', '出生日期', '電子信箱',
            '戶籍地址', '通訊地址', '學籍目前狀態', '聯絡人', '緊急聯絡人電話',
          ];
          final otherFields = profile.fields.where((field) {
            final label = field['label'] ?? '';
            return !requestedLabels.any(label.contains) &&
                !label.contains('身分證') && !label.contains('護照號碼');
          }).toList();
          if (profile.fields.isEmpty) {
            return const Center(child: Text('校務系統沒有回傳個人資料'));
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.l),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.l),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 42,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        backgroundImage: profile.photo == null
                            ? null
                            : MemoryImage(profile.photo!),
                        child: profile.photo == null
                            ? Text(name.isEmpty ? '學' : name.substring(0, 1))
                            : null,
                      ),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isEmpty ? '學生資料' : name,
                              style: theme.textTheme.titleLarge,
                            ),
                            if (studentId.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text('學號／帳號：$studentId'),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _ProfileSection(
                title: '學籍資料',
                fields: [
                  ('出生年月日', profile.valueFor(const ['出生日期'])),
                  ('學籍狀態', profile.valueFor(const ['學籍目前狀態', '學籍狀態'])),
                ],
              ),
              _ProfileSection(
                title: '聯絡資料',
                fields: [
                  ('電子信箱', profile.valueFor(const ['電子信箱', 'E-mail'])),
                  ('戶籍地址', profile.valueFor(const ['戶籍地址'])),
                  ('通訊地址', profile.valueFor(const ['通訊地址'])),
                ],
              ),
              _ProfileSection(
                title: '緊急聯絡人',
                fields: [
                  ('姓名', profile.valueFor(const ['聯絡人', '緊急聯絡人'])),
                  ('電話', profile.valueFor(const ['聯絡人電話', '緊急聯絡人電話'])),
                ],
              ),
              if (otherFields.isNotEmpty)
                _ProfileSection(
                  title: '其他資料',
                  fields: [
                    for (final field in otherFields)
                      (field['label'] ?? '', field['value'] ?? ''),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.title, required this.fields});

  final String title;
  final List<(String, String)> fields;

  @override
  Widget build(BuildContext context) {
    final visibleFields = fields
        .where((field) => field.$1.isNotEmpty && field.$2.trim().isNotEmpty)
        .toList();
    if (visibleFields.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.m),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.l, AppSpacing.m, AppSpacing.l, AppSpacing.xs,
              ),
              child: Text(title, style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final field in visibleFields)
              ListTile(
                title: Text(field.$1),
                subtitle: Text(field.$2),
                dense: true,
              ),
          ],
        ),
      ),
    );
  }
}
