/// Native leave request form and leave record cancellation screen.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/router.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/datasources/webforms_leave_api.dart';
import '../../data/parsers/webforms_parsers.dart' show extractAlerts;
import '../student_data_providers.dart';

const _filePicker = MethodChannel('tw.edu.nptu.nptu_campus/file_picker');

class LeaveApplicationPage extends ConsumerWidget {
  const LeaveApplicationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('請假'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: '返回',
          onPressed: () => context.go(kRouteMore),
        ),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(leavePageProvider),
            icon: const Icon(Icons.refresh),
            tooltip: '重新載入',
          ),
        ],
        bottom: const TabBar(tabs: [
          Tab(text: '新增請假', icon: Icon(Icons.post_add_outlined)),
          Tab(text: '請假紀錄', icon: Icon(Icons.history_edu_outlined)),
        ]),
      ),
      body: const TabBarView(children: [
        _LeaveRequestTab(),
        _LeaveRecordsTab(),
      ]),
    ),
  );
}

class _LeaveRequestTab extends ConsumerStatefulWidget {
  const _LeaveRequestTab();

  @override
  ConsumerState<_LeaveRequestTab> createState() => _LeaveRequestTabState();
}

class _LeaveRequestTabState extends ConsumerState<_LeaveRequestTab> {
  final _formKey = GlobalKey<FormState>();
  final _textControllers = <String, TextEditingController>{};
  final _values = <String, String>{};
  final _checked = <String, bool>{};
  Uint8List? _attachmentBytes;
  String? _attachmentName;
  String? _attachmentMimeType;
  bool _submitting = false;

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(leavePageProvider);
    return page.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _LoadError(
        message: '請假表單載入失敗：$error',
        onRetry: () => ref.invalidate(leavePageProvider),
      ),
      data: (definition) {
        _prepareValues(definition);
        final checkboxes = definition.controls.where((field) => field.type == 'checkbox' && !field.disabled).toList();
        final fields = definition.controls.where((field) => field.type != 'checkbox' && !field.disabled).toList();
        final action = _requestAction(definition.actions);
        return Form(
          key: _formKey,
          child: Column(children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.l),
                children: [
                  Card(child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.m),
                    child: Text('請依校務系統規定填寫假別、時段與原因。送出前會再次確認。',
                      style: Theme.of(context).textTheme.bodyMedium),
                  )),
                  for (final field in fields) _fieldWidget(context, field),
                  if (checkboxes.isNotEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(AppSpacing.l, AppSpacing.s, AppSpacing.l, 0),
                              child: Text('請假節次', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                            ),
                            for (final field in checkboxes)
                              CheckboxListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                                dense: true,
                                title: Text(field.label),
                                value: _checked[field.name] ?? field.checked,
                                onChanged: (value) => setState(() => _checked[field.name] = value ?? false),
                              ),
                          ],
                        ),
                      ),
                    ),
                  for (final field in definition.controls.where((field) => field.type == 'file'))
                    _attachmentField(field),
                  if (action == null)
                    const Card(child: ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('尚未辨識到校務系統的送出按鈕'),
                      subtitle: Text('請重新載入表單，或稍後更新 App。'),
                    )),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.l, AppSpacing.s, AppSpacing.l, AppSpacing.m),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: action == null || _submitting ? null : () => _submit(definition, action),
                    icon: _submitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send_outlined),
                    label: Text(_submitting ? '送出中…' : '送出請假申請'),
                  ),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }

  void _prepareValues(LeavePageDefinition definition) {
    for (final field in definition.controls) {
      if (field.type == 'checkbox') {
        _checked.putIfAbsent(field.name, () => field.checked);
      } else if (field.type != 'file' && field.type != 'select') {
        _textControllers.putIfAbsent(field.name, () => TextEditingController(text: field.value));
        _values.putIfAbsent(field.name, () => field.value);
      } else if (field.type == 'select') {
        _values.putIfAbsent(field.name, () => field.value);
      }
    }
  }

  Widget _fieldWidget(BuildContext context, LeaveControl field) {
    final decoration = InputDecoration(
      labelText: '${field.label}${field.required ? ' *' : ''}',
      border: const OutlineInputBorder(),
    );
    if (field.type == 'select' && field.options.isNotEmpty) {
      final selected = field.options.any((option) => option.value == _values[field.name])
          ? _values[field.name]
          : field.options.first.value;
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.m),
        child: DropdownButtonFormField<String>(
          value: selected,
          decoration: decoration,
          validator: field.required ? (value) => value == null || value.isEmpty ? '請選擇${field.label}' : null : null,
          items: field.options.map((option) => DropdownMenuItem(
            value: option.value,
            child: Text(option.label, overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: (value) {
            if (value != null) _values[field.name] = value;
          },
        ),
      );
    }
    final isMultiline = field.type == 'textarea' || field.name.toLowerCase().contains('reason') ||
        field.label.contains('原因') || field.label.contains('事由');
    final isDate = field.name.endsWith(':txtEXCESE_DT') || field.label.contains('日期');
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.m),
      child: TextFormField(
        controller: _textControllers[field.name],
        decoration: decoration,
        readOnly: isDate,
        onTap: isDate ? () => _pickDate(field.name) : null,
        textInputAction: isMultiline ? TextInputAction.newline : TextInputAction.next,
        keyboardType: field.type == 'email'
            ? TextInputType.emailAddress
            : field.type == 'number'
                ? TextInputType.number
                : TextInputType.text,
        minLines: isMultiline ? 3 : 1,
        maxLines: isMultiline ? 5 : 1,
        validator: field.required
            ? (value) => value == null || value.trim().isEmpty ? '請填寫${field.label}' : null
            : null,
        onChanged: (value) => _values[field.name] = value,
      ),
    );
  }

  Future<void> _pickDate(String fieldName) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse((_textControllers[fieldName]?.text ?? '').replaceAll('/', '-')) ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (selected == null || !mounted) return;
    final formatted = DateFormat('yyyy/MM/dd').format(selected);
    _textControllers[fieldName]?.text = formatted;
    _values[fieldName] = formatted;
  }

  Widget _attachmentField(LeaveControl field) => Card(
    child: ListTile(
      leading: const Icon(Icons.attach_file),
      title: Text(field.label),
      subtitle: Text(_attachmentName ?? '選擇證明文件（選填）'),
      trailing: TextButton(
        onPressed: _pickAttachment,
        child: const Text('選擇檔案'),
      ),
    ),
  );

  Future<void> _pickAttachment() async {
    try {
      final files = await _filePicker.invokeListMethod<Object?>('pickFile', {
        'acceptTypes': const <String>['*/*'],
        'multiple': false,
      });
      if (files == null || files.isEmpty) return;
      final first = files.first;
      if (first is! Map) return;
      final bytes = first['bytes'];
      if (bytes is! Uint8List) return;
      setState(() {
        _attachmentBytes = bytes;
        _attachmentName = first['name']?.toString() ?? 'attachment';
        _attachmentMimeType = first['mimeType']?.toString();
      });
    } on PlatformException catch (error) {
      if (mounted) _showMessage('無法選取檔案：${error.message ?? '請稍後重試'}');
    }
  }

  Future<void> _submit(LeavePageDefinition definition, LeaveAction action) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認送出請假申請'),
        content: const Text('送出後會寫入校務系統，請確認假別、節次與原因正確。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('再檢查')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('確認送出')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _submitting = true);
    final fields = Map<String, String>.from(definition.hiddenFields);
    for (final field in definition.controls) {
      if (field.type == 'checkbox') {
        if (_checked[field.name] ?? field.checked) fields[field.name] = field.value.isEmpty ? 'on' : field.value;
      } else if (field.type != 'file' && _values[field.name]?.isNotEmpty == true) {
        fields[field.name] = _values[field.name]!;
      }
    }
    try {
      final response = await ref.read(leaveDataApiProvider).submit(
        fields: fields,
        action: action,
        attachment: _attachmentBytes,
        attachmentName: _attachmentName,
        attachmentMimeType: _attachmentMimeType,
        attachmentFieldName: definition.controls.where((field) => field.type == 'file').firstOrNull?.name,
      );
      final message = _responseMessage(response, '請假申請已送出，請查看紀錄確認狀態。');
      if (mounted) {
        _showMessage(message);
        ref.invalidate(leavePageProvider);
      }
    } catch (error) {
      if (mounted) _showMessage('送出失敗：$error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  LeaveAction? _requestAction(List<LeaveAction> actions) {
    for (final action in actions) {
      if (RegExp(r'新增|申請|送出|確定|add|apply|submit|save|insert|new', caseSensitive: false)
          .hasMatch('${action.label} ${action.name} ${action.eventTarget ?? ''}')) {
        return action;
      }
    }
    return null;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _LeaveRecordsTab extends ConsumerWidget {
  const _LeaveRecordsTab();

  Widget _buildLeaveRecord(LeavePageDefinition definition, LeaveRecord record) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var fieldIndex = 0; fieldIndex < record.values.length; fieldIndex++)
          if (record.values[fieldIndex].isNotEmpty)
            ListTile(
              dense: true,
              title: Text(fieldIndex < definition.recordHeaders.length
                  ? definition.recordHeaders[fieldIndex]
                  : '資料'),
              subtitle: Text(record.values[fieldIndex]),
            ),
      ]),
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(leavePageProvider);
    return page.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _LoadError(
        message: '請假紀錄載入失敗：$error',
        onRetry: () => ref.invalidate(leavePageProvider),
      ),
      data: (definition) {
        return Column(children: [
          if (definition.records.isNotEmpty)
            Expanded(child: ListView(
              padding: const EdgeInsets.all(AppSpacing.l),
              children: [
                Card(child: ListTile(
                  leading: const Icon(Icons.event_busy_outlined),
                  title: const Text('取消已送出的請假'),
                  subtitle: const Text('輸入原申請日期並選取節次'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _manualCancel(context, ref, definition),
                )),
                for (var index = 0; index < definition.records.length; index++) ...[
                  if (index > 0) const SizedBox(height: AppSpacing.s),
                  _buildLeaveRecord(definition, definition.records[index]),
                ],
              ],
            )),
          if (definition.records.isEmpty)
            Expanded(child: _AttendanceLeaveHistory(
              showHeader: true,
              leavePage: definition,
            )),
        ]);
      },
    );
  }

}

class _AttendanceLeaveHistory extends ConsumerWidget {
  const _AttendanceLeaveHistory({required this.showHeader, required this.leavePage});
  final bool showHeader;
  final LeavePageDefinition leavePage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendance = ref.watch(attendanceProvider(null));
    return attendance.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _LoadError(
        message: '請假紀錄載入失敗：$error',
        onRetry: () => ref.invalidate(attendanceProvider(null)),
      ),
      data: (result) {
        final leaveRows = result.rows.where((row) => row.any((value) =>
            value.contains('事假') || value.contains('病假') || value.contains('公假') ||
            value.contains('生理假') || value.contains('心理健康假') || value.contains('喪假'))).toList();
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.l),
          children: [
            if (showHeader)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s),
                child: Text('本學期請假紀錄', style: Theme.of(context).textTheme.titleMedium),
              ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.event_busy_outlined),
                title: const Text('取消已送出的請假'),
                subtitle: const Text('輸入原申請日期並選取節次'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _manualCancel(context, ref, leavePage),
              ),
            ),
            if (leaveRows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Center(child: Text('此學期沒有請假紀錄')),
              ),
            for (final row in leaveRows)
              _AttendanceLeaveRecord(
                headers: result.headers,
                row: row,
                leavePage: leavePage,
                onCancel: () => _manualCancel(context, ref, leavePage),
              ),
          ],
        );
      },
    );
  }
}

Future<void> _manualCancel(
  BuildContext context,
  WidgetRef ref,
  LeavePageDefinition definition,
) async {
  final dateControl = definition.controls.where((field) => field.name.endsWith(':txtEXCESE_DT')).firstOrNull;
  final category = definition.controls.where((field) => field.name.endsWith(':ddlABSENCE')).firstOrNull;
  final periods = definition.controls.where((field) => field.type == 'checkbox').toList();
  final deleteAction = definition.actions.where((action) =>
      action.name.endsWith(':ibtDeleteUp') || action.label.contains('刪除')).firstOrNull;
  if (dateControl == null || category == null || periods.isEmpty || deleteAction == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('無法辨識校務系統的取消欄位，請重新載入後再試。')),
    );
    return;
  }

  DateTime? chosenDate;
  String? chosenCategory = category.options.isEmpty ? null : category.options.first.value;
  final chosenPeriods = <String>{};
  final selection = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('取消已送出的請假'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('請選擇原申請日期、假別與節次。按下確認後會向校務系統送出取消。'),
              const SizedBox(height: AppSpacing.m),
              if (chosenDate == null)
                OutlinedButton.icon(
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: now,
                      firstDate: DateTime(now.year - 5),
                      lastDate: DateTime(now.year + 1),
                    );
                    if (picked != null) setDialogState(() => chosenDate = picked);
                  },
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: const Text('選擇請假日期'),
                )
              else
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('請假日期'),
                  subtitle: Text(DateFormat('yyyy/MM/dd').format(chosenDate!)),
                  trailing: IconButton(
                    onPressed: () => setDialogState(() => chosenDate = null),
                    icon: const Icon(Icons.edit_calendar_outlined),
                  ),
                ),
              const SizedBox(height: AppSpacing.s),
              DropdownButtonFormField<String>(
                value: chosenCategory,
                decoration: const InputDecoration(labelText: '假別'),
                items: category.options.map((option) => DropdownMenuItem(
                  value: option.value,
                  child: Text(option.label),
                )).toList(),
                onChanged: (value) => setDialogState(() => chosenCategory = value),
              ),
              const SizedBox(height: AppSpacing.m),
              Text('請假節次', style: Theme.of(context).textTheme.titleSmall),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final period in periods)
                    FilterChip(
                      label: Text(period.label),
                      selected: chosenPeriods.contains(period.label),
                      onSelected: (selected) => setDialogState(() {
                        if (selected) {
                          chosenPeriods.add(period.label);
                        } else {
                          chosenPeriods.remove(period.label);
                        }
                      }),
                    ),
                ],
              ),
            ],
          )),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('返回')),
          FilledButton(
            onPressed: chosenDate == null || chosenPeriods.isEmpty || chosenCategory == null
                ? null
                : () => Navigator.pop(dialogContext, true),
            child: const Text('確認取消'),
          ),
        ],
      ),
    ),
  );
  if (selection != true || chosenDate == null || chosenCategory == null || !context.mounted) return;

  final fields = Map<String, String>.from(definition.hiddenFields)
    ..[dateControl.name] = DateFormat('yyyy/MM/dd').format(chosenDate!)
    ..[category.name] = chosenCategory!;
  for (final period in periods) {
    if (chosenPeriods.contains(period.label)) fields[period.name] = period.value;
  }
  try {
    final response = await ref.read(leaveDataApiProvider).submit(fields: fields, action: deleteAction);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_responseMessage(response, '校務系統已回應，請重新載入紀錄確認取消狀態。')),
    ));
    ref.invalidate(leavePageProvider);
    ref.invalidate(attendanceProvider(null));
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('校務系統未接受取消操作，請確認日期與節次後重試。')),
      );
    }
  }
}

String _responseMessage(String response, String successMessage) {
  final alerts = extractAlerts(response);
  if (alerts.any((alert) => RegExp(r'成功|完成').hasMatch(alert))) return successMessage;
  if (alerts.isNotEmpty || RegExp(r'錯誤|失敗|異常|不符').hasMatch(response)) {
    return '校務系統未接受操作，請檢查填寫內容後重試。';
  }
  return successMessage;
}

class _AttendanceLeaveRecord extends StatelessWidget {
  const _AttendanceLeaveRecord({
    required this.headers,
    required this.row,
    required this.leavePage,
    required this.onCancel,
  });

  final List<String> headers;
  final List<String> row;
  final LeavePageDefinition leavePage;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final fields = <Widget>[];
    for (var index = 0; index < row.length; index++) {
      if (row[index].trim().isEmpty) continue;
      fields.add(ListTile(
        dense: true,
        title: Text(index < headers.length && headers[index].trim().isNotEmpty ? headers[index] : '請假資料'),
        subtitle: Text(row[index]),
      ));
    }
    return Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ...fields,
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.m, 0, AppSpacing.m, AppSpacing.m),
          child: Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.event_busy_outlined),
              label: const Text('取消這筆請假'),
            ),
          ),
        ),
      ]),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.m),
        FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('重試')),
      ]),
    ),
  );
}
