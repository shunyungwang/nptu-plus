/// Today's timetable rendered as a period-by-period list.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../student_data_providers.dart';

const _days = <String>['一', '二', '三', '四', '五', '六', '日'];
const _slots = <({String code, String time})>[
  (code: 'M', time: '07:00\n07:50'),
  (code: '01', time: '08:00\n08:50'),
  (code: '02', time: '09:00\n09:50'),
  (code: '03', time: '10:10\n11:00'),
  (code: '04', time: '11:10\n12:00'),
  (code: 'N', time: '12:10\n13:00'),
  (code: '05', time: '13:30\n14:20'),
  (code: '06', time: '14:30\n15:20'),
  (code: '07', time: '15:40\n16:30'),
  (code: '08', time: '16:40\n17:30'),
  (code: '09', time: '17:35\n18:25'),
  (code: 'A', time: '18:30\n19:15'),
  (code: 'B', time: '19:20\n20:05'),
  (code: 'C', time: '20:10\n20:55'),
  (code: 'D', time: '21:00\n21:45'),
];

class TimetablePage extends ConsumerStatefulWidget {
  const TimetablePage({super.key});

  @override
  ConsumerState<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends ConsumerState<TimetablePage> {
  late int _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now().weekday;
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final data = ref.watch(coursesProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('課表'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(coursesProvider),
            icon: const Icon(Icons.refresh),
            tooltip: '重新載入課表',
          ),
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: TextButton.icon(
            onPressed: () => ref.invalidate(coursesProvider),
            icon: const Icon(Icons.refresh),
            label: Text('課表載入失敗，點擊重試：$error'),
          ),
        ),
        data: (courses) {
          final today = DateTime.now().weekday;
          final coursesBySlot = <String, List<Map<String, String>>>{};
          var selectedCourses = 0;
          for (final course in courses) {
            final weekdays = _parseWeekdays(course['weekday'] ?? '');
            final periods = _parsePeriods(course['period'] ?? '');
            for (final day in weekdays) {
              if (day == _selectedDay) {
                selectedCourses++;
                for (final slot in periods) {
                  (coursesBySlot[slot] ??= []).add(course);
                }
                break;
              }
            }
          }
          final dayName = _days[_selectedDay - 1];
          final occupiedSlots = _slots
              .where((slot) => coursesBySlot.containsKey(slot.code))
              .toList();

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.m),
            children: [
              Text('選擇星期', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.s),
              Row(
                children: List.generate(7, (index) {
                  final day = index + 1;
                  final selected = day == _selectedDay;
                  final isToday = day == today;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.5),
                      child: Material(
                        color: selected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _selectedDay = day),
                          child: SizedBox(
                            height: 48,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _days[index],
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: selected
                                        ? theme.colorScheme.onPrimary
                                        : theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isToday
                                        ? (selected
                                              ? theme.colorScheme.onPrimary
                                              : theme.colorScheme.primary)
                                        : Colors.transparent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: AppSpacing.l),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '星期$dayName 課程',
                      style: theme.textTheme.titleLarge,
                    ),
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
                      '$selectedCourses 門課',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s),
              if (occupiedSlots.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Center(
                      child: Text(
                        '這天沒有排定課程',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                )
              else
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Table(
                    columnWidths: const {
                      0: FixedColumnWidth(52),
                      1: FixedColumnWidth(78),
                      2: FlexColumnWidth(1),
                    },
                    border: TableBorder.all(
                      color: theme.colorScheme.outlineVariant,
                      width: 0.7,
                    ),
                    children: [
                      TableRow(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                        ),
                        children: [
                          _header('節次', theme),
                          _header('時間', theme),
                          _header('課程', theme),
                        ],
                      ),
                      for (final slot in occupiedSlots)
                        TableRow(
                          children: [
                            _slotLabel(slot.code, theme),
                            _slotLabel(slot.time, theme),
                            _courseCell(coursesBySlot[slot.code]!, theme),
                          ],
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _header(String value, ThemeData theme) => Padding(
    padding: const EdgeInsets.symmetric(
      vertical: AppSpacing.m,
      horizontal: AppSpacing.s,
    ),
    child: Center(
      child: Text(
        value,
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );

  Widget _slotLabel(String value, ThemeData theme) => Container(
    constraints: const BoxConstraints(minHeight: 64),
    alignment: Alignment.center,
    padding: const EdgeInsets.all(AppSpacing.s),
    child: Text(
      value,
      textAlign: TextAlign.center,
      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
    ),
  );

  Widget _courseCell(List<Map<String, String>> courses, ThemeData theme) =>
      Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.all(AppSpacing.s),
        child: courses.isEmpty
            ? Center(
                child: Text(
                  '空堂',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < courses.length; index++) ...[
                    if (index > 0) const Divider(height: AppSpacing.m),
                    Text(
                      courses[index]['name'] ?? '',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if ((courses[index]['class'] ?? '').isNotEmpty)
                      Text(
                        courses[index]['class']!,
                        style: theme.textTheme.bodySmall,
                      ),
                    if ((courses[index]['room'] ?? '').isNotEmpty)
                      Text(
                        courses[index]['room']!,
                        style: theme.textTheme.bodySmall,
                      ),
                    if ((courses[index]['teacher'] ?? '').isNotEmpty)
                      Text(
                        courses[index]['teacher']!,
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ],
              ),
      );
}

Set<int> _parseWeekdays(String value) =>
    RegExp(r'\d+')
        .allMatches(value)
        .map((match) => int.tryParse(match.group(0) ?? ''))
        .whereType<int>()
        .where((day) => day >= 1 && day <= 7)
        .toSet();

Set<String> _parsePeriods(String value) {
  final result = <String>{};
  final letters = RegExp(r'[MNABCD]')
      .allMatches(value.toUpperCase())
      .map((match) => match.group(0)!)
      .where((code) => _slots.any((slot) => slot.code == code));
  result.addAll(letters);
  for (final match in RegExp(r'\d{4}|\d{1,2}').allMatches(value)) {
    final token = match.group(0)!;
    if (token.length == 4) {
      final start = int.tryParse(token.substring(0, 2));
      final end = int.tryParse(token.substring(2));
      if (start == null || end == null || end < start || end - start > 6)
        continue;
      for (var period = start; period <= end; period++) {
        final code = period.toString().padLeft(2, '0');
        if (_slots.any((slot) => slot.code == code)) result.add(code);
      }
    } else {
      final period = int.tryParse(token);
      if (period != null) {
        final code = period.toString().padLeft(2, '0');
        if (_slots.any((slot) => slot.code == code)) result.add(code);
      }
    }
  }
  return result;
}
