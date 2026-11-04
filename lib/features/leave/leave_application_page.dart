/// Native leave request form and leave record cancellation screen.
///
/// 取消請假不再要求使用者自行重填日期與節次：
/// 校務系統的請假紀錄清單每一列都有自己的刪除 postback，
/// 直接重送該列的 `__doPostBack` 才是網站真正的取消方式。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/router.dart';
import '../../core/errors/failures.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_surfaces.dart';
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
          const SizedBox(width: AppSpacing.xs),
        ],
        bottom: const TabBar(
          tabs: [
            Tab(text: '新增請假', icon: Icon(Icons.post_add_outlined)),
            Tab(text: '請假紀錄', icon: Icon(Icons.history_edu_outlined)),
          ],
        ),
      ),
      body: const TabBarView(
        children: [_LeaveRequestTab(), _LeaveRecordsTab()],
      ),
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
      loading: () => const AppLoadingView(message: '正在載入請假表單'),
      error: (error, _) => AppErrorView(
        message: '請假表單載入失敗：$error',
        onRetry: () => ref.invalidate(leavePageProvider),
      ),
      data: (definition) {
        _prepareValues(definition);
        final checkboxes = definition.controls
            .where((field) => field.type == 'checkbox' && !field.disabled)
            .toList();
        final fields = definition.controls
            .where((field) => field.type != 'checkbox' && !field.disabled)
            .toList();
        final action = _requestAction(definition.actions);
        return Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: AppDimensions.pageInsets,
                  children: [
                    Text(
                      '請依校務系統規定填寫假別、時段與原因。送出前會再次確認。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.l),
                    for (final field in fields) _fieldWidget(context, field),
                    if (checkboxes.isNotEmpty) ...[
                      Text(
                        '請假節次',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.s,
                        runSpacing: AppSpacing.xs,
                        children: [
                          for (final field in checkboxes)
                            FilterChip(
                              label: Text(field.label),
                              selected: _checked[field.name] ?? field.checked,
                              onSelected: (value) =>
                                  setState(() => _checked[field.name] = value),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.m),
                    ],
                    for (final field in definition.controls.where(
                      (field) => field.type == 'file',
                    ))
                      _attachmentField(field),
                    if (action == null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.m),
                        child: Text(
                          '尚未辨識到校務系統的送出按鈕，請重新載入表單。',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.pagePadding,
                    AppSpacing.s,
                    AppDimensions.pagePadding,
                    AppSpacing.m,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: action == null || _submitting
                          ? null
                          : () => _submit(definition, action),
                      icon: _submitting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_outlined),
                      label: Text(_submitting ? '送出中…' : '送出請假申請'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _prepareValues(LeavePageDefinition definition) {
    for (final field in definition.controls) {
      if (field.type == 'checkbox') {
        _checked.putIfAbsent(field.name, () => field.checked);
      } else if (field.type != 'file' && field.type != 'select') {
        _textControllers.putIfAbsent(
          field.name,
          () => TextEditingController(text: field.value),
        );
        _values.putIfAbsent(field.name, () => field.value);
      } else if (field.type == 'select') {
        _values.putIfAbsent(field.name, () => field.value);
      }
    }
  }

  Widget _fieldWidget(BuildContext context, LeaveControl field) {
    final decoration = InputDecoration(
      labelText: '${field.label}${field.required ? ' *' : ''}',
    );
    if (field.type == 'select' && field.options.isNotEmpty) {
      final selected =
          field.options.any((option) => option.value == _values[field.name])
          ? _values[field.name]
          : field.options.first.value;
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.m),
        child: DropdownButtonFormField<String>(
          initialValue: selected,
          decoration: decoration,
          validator: field.required
              ? (value) =>
                    value == null || value.isEmpty ? '請選擇${field.label}' : null
              : null,
          items: field.options
              .map(
                (option) => DropdownMenuItem(
                  value: option.value,
                  child: Text(option.label, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _values[field.name] = value);
          },
        ),
      );
    }
    final isMultiline =
        field.type == 'textarea' ||
        field.name.toLowerCase().contains('reason') ||
        field.label.contains('原因') ||
        field.label.contains('事由');
    final isDate =
        field.name.toUpperCase().contains('DT') || field.label.contains('日期');
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.m),
      child: TextFormField(
        controller: _textControllers[field.name],
        decoration: decoration,
        readOnly: isDate || field.readOnly,
        onTap: isDate ? () => _pickDate(field.name) : null,
        textInputAction: isMultiline
            ? TextInputAction.newline
            : TextInputAction.next,
        keyboardType: field.type == 'email'
            ? TextInputType.emailAddress
            : field.type == 'number'
            ? TextInputType.number
            : TextInputType.text,
        minLines: isMultiline ? 3 : 1,
        maxLines: isMultiline ? 5 : 1,
        validator: field.required
            ? (value) => value == null || value.trim().isEmpty
                  ? '請填寫${field.label}'
                  : null
            : null,
        onChanged: (value) => _values[field.name] = value,
      ),
    );
  }

  Future<void> _pickDate(String fieldName) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate:
          DateTime.tryParse(
            (_textControllers[fieldName]?.text ?? '').replaceAll('/', '-'),
          ) ??
          now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (selected == null || !mounted) return;
    final formatted = DateFormat('yyyy/MM/dd').format(selected);
    _textControllers[fieldName]?.text = formatted;
    _values[fieldName] = formatted;
  }

  Widget _attachmentField(LeaveControl field) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.m),
    child: Row(
      children: [
        const Icon(Icons.attach_file, size: AppDimensions.iconMedium),
        const SizedBox(width: AppSpacing.s),
        Expanded(
          child: Text(
            _attachmentName ?? '${field.label}（選填）',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        TextButton(onPressed: _pickAttachment, child: const Text('選擇檔案')),
      ],
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

  Future<void> _submit(
    LeavePageDefinition definition,
    LeaveAction action,
  ) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認送出請假申請'),
        content: const Text('送出後會寫入校務系統，請確認假別、節次與原因正確。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('再檢查'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('確認送出'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _submitting = true);
    final fields = Map<String, String>.from(definition.hiddenFields);
    for (final field in definition.controls) {
      if (field.type == 'checkbox') {
        if (_checked[field.name] ?? field.checked) {
          fields[field.name] = field.value.isEmpty ? 'on' : field.value;
        }
      } else if (field.type != 'file' &&
          _values[field.name]?.isNotEmpty == true) {
        fields[field.name] = _values[field.name]!;
      }
    }
    try {
      final response = await ref
          .read(leaveDataApiProvider)
          .submit(
            fields: fields,
            action: action,
            attachment: _attachmentBytes,
            attachmentName: _attachmentName,
            attachmentMimeType: _attachmentMimeType,
            attachmentFieldName: definition.controls
                .where((field) => field.type == 'file')
                .firstOrNull
                ?.name,
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
      if (RegExp(
        r'新增|申請|送出|確定|add|apply|submit|save|insert|new',
        caseSensitive: false,
      ).hasMatch(
        '${action.label} ${action.name} ${action.eventTarget ?? ''}',
      )) {
        return action;
      }
    }
    return null;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _LeaveRecordsTab extends ConsumerStatefulWidget {
  const _LeaveRecordsTab();

  @override
  ConsumerState<_LeaveRecordsTab> createState() => _LeaveRecordsTabState();
}

class _LeaveRecordsTabState extends ConsumerState<_LeaveRecordsTab> {
  bool _cancelling = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final page = ref.watch(leavePageProvider);
    return page.when(
      loading: () => const AppLoadingView(message: '正在載入請假紀錄'),
      error: (error, _) => AppErrorView(
        message: '請假紀錄載入失敗：$error',
        onRetry: () => ref.invalidate(leavePageProvider),
      ),
      data: (definition) {
        if (definition.records.isEmpty) {
          return const AppEmptyView(
            icon: Icons.event_busy_outlined,
            title: '目前沒有請假紀錄',
            message: '送出請假申請後，紀錄會出現在這裡。',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(leavePageProvider),
          child: ListView(
            padding: AppDimensions.pageInsets,
            children: [
              AppSectionHeader(
                title: '已送出紀錄',
                caption: definition.cancellableRecords == 0
                    ? '${definition.records.length} 筆'
                    : '${definition.records.length} 筆 · ${definition.cancellableRecords} 筆可取消',
              ),
              for (final record in definition.records) ...[
                _LeaveRecordCard(
                  definition: definition,
                  record: record,
                  busy: _cancelling,
                  onCancel: () => _cancel(definition, record),
                ),
                const SizedBox(height: AppSpacing.m),
              ],
              if (definition.cancellableRecords == 0)
                Text(
                  '校務系統目前沒有提供這些紀錄的取消按鈕，請至校務系統網站處理。',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _cancel(
    LeavePageDefinition definition,
    LeaveRecord record,
  ) async {
    if (!definition.canCancel(record)) {
      _snack('此筆紀錄在校務系統沒有取消欄位，請重新載入後再試。');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消這筆請假？'),
        content: Text(
          '將向校務系統送出取消：${record.values.where((value) => value.isNotEmpty).take(3).join(' · ')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('返回'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('確認取消'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      final response = await ref
          .read(leaveDataApiProvider)
          .cancelRecord(definition: definition, record: record);
      final alerts = extractAlerts(response);
      final accepted =
          alerts.any((alert) => RegExp(r'成功|完成').hasMatch(alert)) ||
          !RegExp(r'錯誤|失敗|異常|不符').hasMatch(response);
      _snack(
        accepted
            ? '取消已送出，請確認紀錄狀態已更新。'
            : '校務系統未接受取消：${alerts.isEmpty ? '請稍後再試' : alerts.join('；')}',
      );
      ref.invalidate(leavePageProvider);
      ref.invalidate(attendanceProvider(null));
    } catch (error) {
      _snack(error is Failure ? error.message : '取消失敗，請稍後再試。');
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _LeaveRecordCard extends StatelessWidget {
  const _LeaveRecordCard({
    required this.definition,
    required this.record,
    required this.busy,
    required this.onCancel,
  });

  final LeavePageDefinition definition;
  final LeaveRecord record;
  final bool busy;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = <({String label, String value})>[];
    for (var index = 0; index < record.values.length; index++) {
      final value = record.values[index].trim();
      if (value.isEmpty) continue;
      final label =
          index < definition.recordHeaders.length &&
              definition.recordHeaders[index].trim().isNotEmpty
          ? definition.recordHeaders[index].trim()
          : '資料 ${index + 1}';
      entries.add((label: label, value: value));
    }
    if (entries.isEmpty) return const SizedBox.shrink();
    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.cardPadding,
        AppSpacing.s,
        AppDimensions.cardPadding,
        AppSpacing.s,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 76,
                    child: Text(entry.label, style: theme.textTheme.bodySmall),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: Text(entry.value, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
          if (definition.canCancel(record))
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: busy ? null : onCancel,
                icon: const Icon(
                  Icons.event_busy_outlined,
                  size: AppDimensions.iconSmall,
                ),
                label: const Text('取消這筆請假'),
              ),
            ),
        ],
      ),
    );
  }
}

String _responseMessage(String response, String successMessage) {
  final alerts = extractAlerts(response);
  if (alerts.any((alert) => RegExp(r'成功|完成').hasMatch(alert))) {
    return successMessage;
  }
  if (alerts.isNotEmpty || RegExp(r'錯誤|失敗|異常|不符').hasMatch(response)) {
    return '校務系統未接受操作，請檢查填寫內容後重試。';
  }
  return successMessage;
}
