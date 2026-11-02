/// Attendance and leave history from B0105S.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../student_data_providers.dart';

class AttendancePage extends ConsumerStatefulWidget {
  const AttendancePage({super.key});

  @override
  ConsumerState<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends ConsumerState<AttendancePage> {
  String? _semester;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = ref.watch(attendanceProvider(_semester));

    return Scaffold(
      appBar: AppBar(
        title: const Text('出缺勤'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(attendanceProvider(_semester)),
            icon: const Icon(Icons.refresh),
            tooltip: '重新載入',
          ),
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Card(
            margin: const EdgeInsets.all(AppSpacing.l),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 36,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: AppSpacing.m),
                  const Text('出缺勤資料載入失敗'),
                  const SizedBox(height: AppSpacing.s),
                  FilledButton.icon(
                    onPressed: () =>
                        ref.invalidate(attendanceProvider(_semester)),
                    icon: const Icon(Icons.refresh),
                    label: const Text('重新載入'),
                  ),
                ],
              ),
            ),
          ),
        ),
        data: (result) {
          final selectedSemester = _semester ?? result.selected;
          final attendanceGroups = _groupAttendanceRows(
            result.headers,
            result.rows,
          );
          return Column(
            children: [
              if (result.semesters.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.l,
                    AppSpacing.s,
                    AppSpacing.l,
                    0,
                  ),
                  child: DropdownButtonFormField<String>(
                    value:
                        result.semesters.any((s) => s.value == selectedSemester)
                        ? selectedSemester
                        : result.semesters.first.value,
                    decoration: const InputDecoration(
                      labelText: '學期',
                      prefixIcon: Icon(Icons.calendar_month_outlined),
                    ),
                    items: result.semesters
                        .map(
                          (semester) => DropdownMenuItem(
                            value: semester.value,
                            child: Text(semester.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _semester = value),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.l,
                  AppSpacing.m,
                  AppSpacing.l,
                  AppSpacing.s,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('紀錄明細', style: theme.textTheme.titleMedium),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.m,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        '${result.rows.length} 筆',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: result.rows.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.event_available_outlined,
                                size: 48,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(height: AppSpacing.m),
                              Text(
                                '這個學期沒有缺曠或請假紀錄',
                                style: theme.textTheme.bodyLarge,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.l,
                          AppSpacing.s,
                          AppSpacing.l,
                          AppSpacing.xl,
                        ),
                        itemCount: attendanceGroups.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.s),
                        itemBuilder: (context, index) {
                          final group = attendanceGroups[index];
                          return _AttendanceDayGroup(
                            title: group.date,
                            headers: result.headers,
                            records: group.rows,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DatedAttendanceRows {
  const _DatedAttendanceRows(this.date, this.rows);
  final String date;
  final List<List<String>> rows;
}

List<_DatedAttendanceRows> _groupAttendanceRows(
  List<String> headers,
  List<List<String>> rows,
) {
  final groups = <String, List<List<String>>>{};
  final dateIndices = <int>[
    for (var index = 0; index < headers.length; index++)
      if (RegExp(r'日期|出缺勤日|發生日').hasMatch(headers[index])) index,
  ];
  final yearIndex = headers.indexWhere(
    (header) => RegExp(r'^(日期?年|年份|年)$').hasMatch(header.trim()),
  );
  final monthIndex = headers.indexWhere(
    (header) => RegExp(r'^(日期?月|月份|月)$').hasMatch(header.trim()),
  );
  final dayIndex = headers.indexWhere(
    (header) => RegExp(r'^(日期?日|日)$').hasMatch(header.trim()),
  );

  for (final row in rows) {
    String? date;
    for (final index in dateIndices) {
      if (index >= row.length || row[index].trim().isEmpty) continue;
      final rawDate = row[index].trim();
      date = _extractAttendanceDate(rawDate) ?? rawDate;
      break;
    }

    if (date == null &&
        yearIndex >= 0 &&
        monthIndex >= 0 &&
        dayIndex >= 0 &&
        yearIndex < row.length &&
        monthIndex < row.length &&
        dayIndex < row.length) {
      final year = row[yearIndex].trim();
      final month = row[monthIndex].trim();
      final day = row[dayIndex].trim();
      if (year.isNotEmpty && month.isNotEmpty && day.isNotEmpty) {
        date = '$year/$month/$day';
      }
    }

    // B0105S's live table places the date in its first data column even when
    // the response omits the header cells. Do not scan unrelated cells.
    if (date == null && dateIndices.isEmpty && row.isNotEmpty) {
      final firstColumn = row.first.trim();
      if (firstColumn.isNotEmpty) {
        date = _extractAttendanceDate(firstColumn) ?? firstColumn;
      }
    }

    final groupName = date ?? '未標示日期';
    (groups[groupName] ??= []).add(row);
  }
  return groups.entries
      .map((entry) => _DatedAttendanceRows(entry.key, entry.value))
      .toList();
}

String? _extractAttendanceDate(String value) {
  final normalized = value.replaceAll(RegExp(r'\s+'), '');
  final separated = RegExp(
    r'(?<!\d)(\d{2,4})\s*[./-]\s*(\d{1,2})\s*[./-]\s*(\d{1,2})(?!\d)',
  ).firstMatch(normalized);
  if (separated != null) {
    return '${separated.group(1)}/${separated.group(2)!.padLeft(2, '0')}/${separated.group(3)!.padLeft(2, '0')}';
  }

  final chinese = RegExp(r'(?<!\d)(\d{2,4})年(\d{1,2})月(\d{1,2})日?')
      .firstMatch(normalized);
  if (chinese != null) {
    return '${chinese.group(1)}/${chinese.group(2)!.padLeft(2, '0')}/${chinese.group(3)!.padLeft(2, '0')}';
  }

  final compact = RegExp(r'(?<!\d)(\d{7,8})(?!\d)').firstMatch(normalized);
  if (compact != null) {
    final digits = compact.group(1)!;
    final yearLength = digits.length == 7 ? 3 : 4;
    final year = digits.substring(0, yearLength);
    final month = digits.substring(yearLength, yearLength + 2);
    final day = digits.substring(yearLength + 2);
    final monthNumber = int.tryParse(month) ?? 0;
    final dayNumber = int.tryParse(day) ?? 0;
    if (monthNumber >= 1 &&
        monthNumber <= 12 &&
        dayNumber >= 1 &&
        dayNumber <= 31) {
      return '$year/$month/$day';
    }
  }
  return null;
}

class _AttendanceDayGroup extends StatelessWidget {
  const _AttendanceDayGroup({
    required this.title,
    required this.headers,
    required this.records,
  });

  final String title;
  final List<String> headers;
  final List<List<String>> records;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.m,
          0,
          AppSpacing.m,
          AppSpacing.m,
        ),
        leading: Icon(
          Icons.calendar_today_outlined,
          color: theme.colorScheme.primary,
          size: 20,
        ),
        title: Text(title, style: theme.textTheme.titleSmall),
        subtitle: Text('${records.length} 筆紀錄'),
        children: [
          for (var index = 0; index < records.length; index++) ...[
            if (index > 0) const SizedBox(height: AppSpacing.s),
            _AttendanceRecordCard(headers: headers, values: records[index]),
          ],
        ],
      ),
    );
  }
}

class _AttendanceRecordCard extends StatelessWidget {
  const _AttendanceRecordCard({required this.headers, required this.values});

  final List<String> headers;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = <({String label, String value})>[];
    for (var index = 0; index < values.length; index++) {
      final value = values[index].trim();
      if (value.isEmpty) continue;
      final label = index < headers.length && headers[index].trim().isNotEmpty
          ? headers[index].trim()
          : '資料${index + 1}';
      entries.add((label: label, value: value));
    }

    if (entries.isEmpty) return const SizedBox.shrink();

    final dateIndex = entries.indexWhere(
      (entry) => RegExp(r'日期|出缺勤日|發生日').hasMatch(entry.label),
    );
    final periodIndices = <int>{
      for (var index = 0; index < entries.length; index++)
        if (RegExp(r'節次|節數|課節').hasMatch(entries[index].label)) index,
    };
    var titleIndex = entries.indexWhere(
      (entry) =>
          entry.label.contains('假別') ||
          entry.label.contains('類別') ||
          entry.label.contains('項目'),
    );
    if (titleIndex < 0) {
      titleIndex = entries.indexWhere((entry) {
        final index = entries.indexOf(entry);
        return index != dateIndex && !periodIndices.contains(index);
      });
    }
    final primary = entries[titleIndex >= 0 ? titleIndex : 0];
    final tagIndex = entries.indexWhere(
      (entry) => entry.label.contains('狀態') || entry.label.contains('假別'),
    );
    final tag = tagIndex >= 0 && tagIndex != titleIndex
        ? entries[tagIndex]
        : null;
    final details = <({String label, String value})>[];
    for (var index = 0; index < entries.length; index++) {
      if (index == titleIndex ||
          index == tagIndex ||
          index == dateIndex ||
          periodIndices.contains(index)) {
        continue;
      }
      details.add(entries[index]);
    }
    final periodEntries = [for (final index in periodIndices) entries[index]];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.event_note_outlined,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(primary.value, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        primary.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (tag != null)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        tag.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (periodEntries.isNotEmpty || details.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.s),
                child: Divider(height: 1),
              ),
              for (final entry in periodEntries) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(
                    entry.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: _periodTokens(entry.value)
                      .map(
                        (period) => Chip(
                          label: Text(period),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s,
                          ),
                          backgroundColor: theme.colorScheme.secondaryContainer,
                          labelStyle: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              for (final entry in details)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 76,
                        child: Text(
                          entry.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

List<String> _periodTokens(String value) {
  final tokens = value
      .split(RegExp(r'[,，、;；\s]+'))
      .map((token) => token.trim())
      .where((token) => token.isNotEmpty)
      .toList();
  return tokens.isEmpty ? [value] : tokens;
}
