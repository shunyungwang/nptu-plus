/// 課表：以「時間軸」為主體的易讀版面。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_surfaces.dart';
import '../student_data_providers.dart';

const _days = <String>['一', '二', '三', '四', '五', '六', '日'];

const _slots = <({String code, String start, String end})>[
  (code: 'M', start: '07:00', end: '07:50'),
  (code: '01', start: '08:00', end: '08:50'),
  (code: '02', start: '09:00', end: '09:50'),
  (code: '03', start: '10:10', end: '11:00'),
  (code: '04', start: '11:10', end: '12:00'),
  (code: 'N', start: '12:10', end: '13:00'),
  (code: '05', start: '13:30', end: '14:20'),
  (code: '06', start: '14:30', end: '15:20'),
  (code: '07', start: '15:40', end: '16:30'),
  (code: '08', start: '16:40', end: '17:30'),
  (code: '09', start: '17:35', end: '18:25'),
  (code: 'A', start: '18:30', end: '19:15'),
  (code: 'B', start: '19:20', end: '20:05'),
  (code: 'C', start: '20:10', end: '20:55'),
  (code: 'D', start: '21:00', end: '21:45'),
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
    final theme = Theme.of(context);
    final data = ref.watch(coursesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('課表'),
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
        loading: () => const AppLoadingView(message: '正在載入課表'),
        error: (error, _) => AppErrorView(
          message: '$error',
          onRetry: () => ref.invalidate(coursesProvider),
        ),
        data: (courses) {
          final bySlot = <String, List<Map<String, String>>>{};
          var count = 0;
          for (final course in courses) {
            final weekdays = _parseWeekdays(course['weekday'] ?? '');
            if (!weekdays.contains(_selectedDay)) continue;
            count++;
            for (final slot in _parsePeriods(course['period'] ?? '')) {
              (bySlot[slot] ??= []).add(course);
            }
          }
          final occupied = _slots
              .where((slot) => bySlot.containsKey(slot.code))
              .toList();
          final today = DateTime.now().weekday;

          return ListView(
            padding: AppDimensions.pageInsets,
            children: [
              _DayPicker(
                selectedDay: _selectedDay,
                today: today,
                onSelect: (day) => setState(() => _selectedDay = day),
              ),
              const SizedBox(height: AppDimensions.sectionGap),
              AppSectionHeader(
                title: '星期${_days[_selectedDay - 1]}',
                caption: count == 0 ? null : '$count 門課',
              ),
              if (occupied.isEmpty)
                const AppCard(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: AppEmptyView(
                    icon: Icons.event_available_outlined,
                    title: '這天沒有排定課程',
                  ),
                )
              else
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Column(
                    children: [
                      for (var index = 0; index < occupied.length; index++) ...[
                        if (index > 0) const Divider(height: 1),
                        _SlotRow(
                          slot: occupied[index],
                          courses: bySlot[occupied[index].code]!,
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: AppDimensions.sectionGap),
              Center(
                child: Text(
                  '課程資料來自校務系統，實際異動以學校公告為準',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 星期選擇：單列 7 格，今天以圓點標記。
class _DayPicker extends StatelessWidget {
  const _DayPicker({
    required this.selectedDay,
    required this.today,
    required this.onSelect,
  });

  final int selectedDay;
  final int today;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        for (var index = 0; index < 7; index++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index == 6 ? 0 : 6),
              child: Semantics(
                selected: index + 1 == selectedDay,
                button: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onSelect(index + 1),
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: index + 1 == selectedDay
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _days[index],
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: index + 1 == selectedDay
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: index + 1 == today
                                ? (index + 1 == selectedDay
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
          ),
      ],
    );
  }
}

/// 一節課：左側時間，右側課程；多門課以分隔線區隔。
class _SlotRow extends StatelessWidget {
  const _SlotRow({required this.slot, required this.courses});

  final ({String code, String start, String end}) slot;
  final List<Map<String, String>> courses;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.cardPadding,
        vertical: AppDimensions.rowVertical,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _periodLabel(slot.code),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${slot.start}\n${slot.end}',
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < courses.length; index++) ...[
                  if (index > 0) const SizedBox(height: AppSpacing.s),
                  Text(
                    courses[index]['name'] ?? '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                          courses[index]['room'],
                          courses[index]['teacher'],
                          courses[index]['class'],
                        ]
                        .whereType<String>()
                        .where((value) => value.isNotEmpty)
                        .join(' · '),
                    style: theme.textTheme.bodySmall,
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

String _periodLabel(String code) {
  final asNumber = int.tryParse(code);
  return asNumber == null ? '第 $code 節' : '第 $asNumber 節';
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
  for (final match in RegExp(r'[MNABCD]').allMatches(value.toUpperCase())) {
    final code = match.group(0)!;
    if (_slots.any((slot) => slot.code == code)) result.add(code);
  }
  for (final match in RegExp(r'\d{4}|\d{1,2}').allMatches(value)) {
    final token = match.group(0)!;
    if (token.length == 4) {
      final start = int.tryParse(token.substring(0, 2));
      final end = int.tryParse(token.substring(2));
      if (start == null || end == null || end < start || end - start > 6) {
        continue;
      }
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
