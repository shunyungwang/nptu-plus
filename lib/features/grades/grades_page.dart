/// 成績：科目／學分／分數三層對齊的清單，避免卡匣式列表。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../domain/entities/semester_table.dart';
import '../student_data_providers.dart';

class GradesPage extends ConsumerStatefulWidget {
  const GradesPage({super.key});

  @override
  ConsumerState<GradesPage> createState() => _GradesPageState();
}

class _GradesPageState extends ConsumerState<GradesPage> {
  String? _semester;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(gradesProvider(_semester));
    return Scaffold(
      appBar: AppBar(
        title: const Text('成績'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(gradesProvider(_semester)),
            icon: const Icon(Icons.refresh),
            tooltip: '重新載入',
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: data.when(
        loading: () => const AppLoadingView(message: '正在載入成績'),
        error: (error, _) => AppErrorView(
          message: '$error',
          onRetry: () => ref.invalidate(gradesProvider(_semester)),
        ),
        data: (result) => _GradesBody(
          result: result,
          semester: _semester ?? result.selected,
          onSemesterChanged: (value) => setState(() => _semester = value),
        ),
      ),
    );
  }
}

class _GradesBody extends StatelessWidget {
  const _GradesBody({
    required this.result,
    required this.semester,
    required this.onSemesterChanged,
  });

  final SemesterTable result;
  final String semester;
  final ValueChanged<String?> onSemesterChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final columns = _gradeColumns(result.headers);
    return ListView(
      padding: AppDimensions.pageInsets,
      children: [
        if (result.semesters.isNotEmpty)
          _SemesterSelector(
            semesters: result.semesters,
            value: semester,
            onChanged: onSemesterChanged,
          ),
        if (result.semesters.isNotEmpty)
          const SizedBox(height: AppDimensions.sectionGap),
        AppSectionHeader(
          title: '科目成績',
          caption: result.rows.isEmpty ? null : '${result.rows.length} 筆',
        ),
        if (result.rows.isEmpty)
          const AppCard(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: AppEmptyView(icon: Icons.grade_outlined, title: '此學期尚無確定成績'),
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                for (var index = 0; index < result.rows.length; index++) ...[
                  if (index > 0) const Divider(height: 1),
                  _GradeRow(cells: result.rows[index], columns: columns),
                ],
              ],
            ),
          ),
        const SizedBox(height: AppDimensions.sectionGap),
        Center(child: Text('成績以校務系統公告為準', style: theme.textTheme.bodySmall)),
      ],
    );
  }
}

class _SemesterSelector extends StatelessWidget {
  const _SemesterSelector({
    required this.semesters,
    required this.value,
    required this.onChanged,
  });

  final List<SemesterOption> semesters;
  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasValue = semesters.any((option) => option.value == value);
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.cardPadding,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Text('學期', style: theme.textTheme.bodySmall),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: hasValue ? value : semesters.first.value,
                isExpanded: true,
                borderRadius: BorderRadius.circular(12),
                style: theme.textTheme.bodyMedium,
                items: [
                  for (final option in semesters)
                    DropdownMenuItem(
                      value: option.value,
                      child: Text(
                        option.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 一筆成績：科目名稱（主）、學分（次）、分數（右，強調）。
class _GradeRow extends StatelessWidget {
  const _GradeRow({required this.cells, required this.columns});

  final List<String> cells;
  final ({int name, int credit, int score}) columns;

  String _cell(int index) {
    if (index < 0 || index >= cells.length) return '';
    return cells[index].trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = _cell(columns.name).isNotEmpty
        ? _cell(columns.name)
        : (cells.isNotEmpty ? cells.first.trim() : '');
    final credit = _cell(columns.credit);
    final score = _cell(columns.score);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.cardPadding,
        vertical: AppDimensions.rowVertical,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (credit.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('$credit 學分', style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          Text(
            score.isEmpty ? '—' : score,
            style: theme.textTheme.titleMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// 依表頭找出科目、學分、成績欄位；找不到時退回第一個欄位。
({int name, int credit, int score}) _gradeColumns(List<String> headers) {
  int find(List<String> keys) =>
      headers.indexWhere((header) => keys.any((key) => header.contains(key)));
  return (
    name: find(['科目', '課程', '名稱']),
    credit: find(['學分']),
    score: find(['成績', '等第', '分數']),
  );
}
