/// 個人資料頁：識別資訊 → 學籍 → 聯絡 → 更多，四層遞減的資訊層級。
///
/// 設計原則：
/// - 身份識別不放在卡片裡，直接以大字與留白建立焦點。
/// - 相關欄位合併在同一張卡內以分隔線排列，不為每個欄位各開卡片。
/// - 次要資料收合，控制頁面長度。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../domain/entities/student_profile.dart';
import '../student_data_providers.dart';

/// 一個標籤＋值的資料列。
typedef _ProfileRow = ({String label, String value});

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(profileProvider);
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
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: data.when(
        loading: () => const AppLoadingView(message: '正在載入個人資料'),
        error: (error, _) => AppErrorView(
          message: '$error',
          onRetry: () => ref.invalidate(profileProvider),
        ),
        data: (profile) {
          if (profile.isEmpty) {
            return const AppEmptyView(
              icon: Icons.badge_outlined,
              title: '校務系統沒有回傳個人資料',
            );
          }
          final academic = _academicRows(profile);
          final contact = _contactRows(profile);
          final extra = _extraRows(profile);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(profileProvider),
            child: ListView(
              padding: AppDimensions.pageInsets,
              children: [
                _IdentityBlock(profile: profile),
                if (academic.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.sectionGap),
                  const AppSectionHeader(title: '學籍資訊'),
                  _InfoSection(rows: academic),
                ],
                if (contact.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.sectionGap),
                  const AppSectionHeader(title: '聯絡資訊'),
                  _InfoSection(rows: contact),
                ],
                if (extra.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.sectionGap),
                  _ExtraSection(rows: extra),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 學籍相關欄位（只放校務系統實際有回傳且有辨識意義的資料）。
List<_ProfileRow> _academicRows(StudentProfile profile) => [
  if (profile.statusLabel.isNotEmpty)
    (label: '學籍狀態', value: profile.statusLabel),
  if (profile.studentTypeLabel.isNotEmpty)
    (label: '學生身分別', value: profile.studentTypeLabel),
  if (profile.admissionLabel.isNotEmpty)
    (label: '入學年月', value: profile.admissionLabel),
  if (profile.feeTypeLabel.isNotEmpty)
    (label: '費用別', value: profile.feeTypeLabel),
  if (profile.nationality.isNotEmpty) (label: '國籍', value: profile.nationality),
  if (profile.birthDateLabel.isNotEmpty)
    (label: '出生日期', value: profile.birthDateLabel),
];

/// 聯絡欄位：同一內容只出現一次（實測戶籍電話、通訊電話、行動電話常為同號）。
List<_ProfileRow> _contactRows(StudentProfile profile) {
  final rows = <_ProfileRow>[];
  void add(String label, String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    if (rows.any((row) => row.value == trimmed)) return;
    rows.add((label: label, value: trimmed));
  }

  add('電子信箱', profile.email);
  add('行動電話', profile.mobile);
  add('通訊電話', profile.currentPhone);
  add('戶籍電話', profile.registeredPhone);
  add('通訊地址', profile.currentAddress);
  add('戶籍地址', profile.registeredAddress);
  add('緊急聯絡人', profile.emergencyName);
  add('緊急聯絡電話', profile.emergencyPhone);
  add('緊急聯絡地址', profile.emergencyAddress);
  return rows;
}

/// 次要資料：預設收合，避免首屏過長。
List<_ProfileRow> _extraRows(StudentProfile profile) => [
  if (profile.englishName.isNotEmpty)
    (label: '英文姓名', value: profile.englishName),
  if (profile.genderLabel.isNotEmpty) (label: '性別', value: profile.genderLabel),
  if (profile.dormRoom.isNotEmpty) (label: '宿舍房號', value: profile.dormRoom),
  if (profile.admissionRef.isNotEmpty)
    (label: '入學文號', value: profile.admissionRef),
];

/// 個人識別區：頭像、姓名、學號、學籍狀態（無卡片）。
class _IdentityBlock extends StatelessWidget {
  const _IdentityBlock({required this.profile});

  final StudentProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = profile.displayName;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s, bottom: AppSpacing.xs),
      child: Row(
        children: [
          CircleAvatar(
            radius: AppDimensions.avatarLarge / 2,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            backgroundImage: profile.photo == null
                ? null
                : MemoryImage(profile.photo!),
            child: profile.photo == null
                ? Text(
                    name.isEmpty ? '?' : name.substring(0, 1),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.headlineSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (profile.studentId.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    profile.studentId,
                    style: theme.textTheme.bodySmall?.copyWith(
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
                if (profile.statusLabel.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.s),
                  _StatusChip(label: profile.statusLabel),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

/// 單一卡片內以分隔線分列。
class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.rows});

  final List<_ProfileRow> rows;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.cardPadding,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0) const Divider(height: 1),
            _InfoRow(row: rows[index]),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.row});

  final _ProfileRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.rowVertical),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(row.label, style: theme.textTheme.bodySmall),
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(child: Text(row.value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// 次要資料收合區。
class _ExtraSection extends StatelessWidget {
  const _ExtraSection({required this.rows});

  final List<_ProfileRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text('更多資料', style: theme.textTheme.titleSmall),
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.cardPadding,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppDimensions.cardPadding,
            0,
            AppDimensions.cardPadding,
            AppSpacing.s,
          ),
          children: [
            for (var index = 0; index < rows.length; index++) ...[
              if (index > 0) const Divider(height: 1),
              _InfoRow(row: rows[index]),
            ],
          ],
        ),
      ),
    );
  }
}
