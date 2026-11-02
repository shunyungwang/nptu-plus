/// Native form model and WebForms submit helpers for student leave requests.
library;

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:html/dom.dart' show Document, Element;
import 'package:html/parser.dart' as html_parser;

import '../../core/errors/failures.dart';
import '../parsers/webforms_parsers.dart';

const _leaveApplicationPath = '/Web/B01/B0155APage.aspx';

class LeaveOption {
  const LeaveOption(this.value, this.label);
  final String value;
  final String label;
}

class LeaveControl {
  const LeaveControl({
    required this.name,
    required this.label,
    required this.type,
    required this.value,
    required this.options,
    required this.required,
    required this.disabled,
    required this.checked,
  });

  final String name;
  final String label;
  final String type;
  final String value;
  final List<LeaveOption> options;
  final bool required;
  final bool disabled;
  final bool checked;
}

class LeaveAction {
  const LeaveAction({
    required this.label,
    required this.name,
    required this.value,
    this.eventTarget,
    this.eventArgument = '',
    this.imageButton = false,
  });

  final String label;
  final String name;
  final String value;
  final String? eventTarget;
  final String eventArgument;
  final bool imageButton;
}

class LeaveRecord {
  const LeaveRecord({required this.values, this.cancelAction});
  final List<String> values;
  final LeaveAction? cancelAction;
}

class LeavePageDefinition {
  const LeavePageDefinition({
    required this.hiddenFields,
    required this.controls,
    required this.actions,
    required this.records,
    required this.recordHeaders,
  });

  final Map<String, String> hiddenFields;
  final List<LeaveControl> controls;
  final List<LeaveAction> actions;
  final List<LeaveRecord> records;
  final List<String> recordHeaders;
}

class WebFormsLeaveApi {
  WebFormsLeaveApi(this._dio, {this.onSessionExpired});

  final Dio _dio;
  final void Function()? onSessionExpired;

  Future<LeavePageDefinition> load() async {
    final response = await _getPage();
    final doc = html_parser.parse(response);
    if (doc.body == null) throw PageParseFailure(cause: '請假頁面沒有內容');

    final hidden = extractHiddenFields(response);
    final controls = <LeaveControl>[];
    for (final control in doc.querySelectorAll('input,select,textarea')) {
      final type = (control.attributes['type'] ?? control.localName ?? 'text').toLowerCase();
      if (type == 'hidden' || type == 'submit' || type == 'button' || type == 'image' || type == 'reset') continue;
      final name = control.attributes['name'] ?? '';
      if (name.isEmpty || name.startsWith('CommonHeader:')) continue;
      final id = control.id;
      final labelFor = id.isEmpty ? null : doc.querySelector('label[for="$id"]')?.text.trim();
      final controlCell = _ancestor(control, 'td');
      final cells = controlCell?.parent?.querySelectorAll('td') ?? const <Element>[];
      final cellIndex = controlCell == null ? -1 : cells.indexOf(controlCell);
      final previousCellText = cellIndex > 0 ? cells[cellIndex - 1].text.trim() : '';
      var label = _knownLabel(name) ?? labelFor ?? previousCellText;
      if (label.isEmpty) label = control.attributes['aria-label'] ?? control.attributes['title'] ?? '';
      if (label.isEmpty) label = _friendlyName(name, id);
      label = label.replaceAll(RegExp(r'[:：*\s]+$'), '').trim();

      final options = control.localName == 'select'
          ? control.querySelectorAll('option').map((option) => LeaveOption(
                option.attributes['value'] ?? '', option.text.trim(),
              )).where((option) => option.label.isNotEmpty).toList()
          : const <LeaveOption>[];
      final required = control.attributes.containsKey('required') ||
          (control.attributes['class'] ?? '').split(RegExp(r'\s+')).contains('Need') ||
          (id.isNotEmpty && doc.querySelector('[controltovalidate="$id"]') != null) ||
          label.contains('*');
      final value = switch (control.localName) {
        'select' => control.querySelector('option[selected]')?.attributes['value'] ??
            control.querySelector('option')?.attributes['value'] ?? '',
        _ when type == 'checkbox' => control.attributes['value'] ?? 'on',
        _ => '',
      };
      controls.add(LeaveControl(
        name: name,
        label: label,
        type: type,
        value: value,
        options: options,
        required: required,
        disabled: control.attributes.containsKey('disabled') || control.attributes.containsKey('readonly'),
        checked: false,
      ));
    }

    final actions = _actions(doc.querySelectorAll('input[type="submit"],input[type="button"],input[type="image"],button,a'));
    final (headers, records) = _records(doc);
    if (controls.isEmpty) throw PageParseFailure(cause: '請假申請表單沒有可用欄位');
    return LeavePageDefinition(
      hiddenFields: hidden,
      controls: controls,
      actions: actions,
      records: records,
      recordHeaders: headers,
    );
  }

  Future<String> submit({
    required Map<String, String> fields,
    required LeaveAction action,
    Uint8List? attachment,
    String? attachmentName,
    String? attachmentMimeType,
    String? attachmentFieldName,
  }) async {
    final payload = Map<String, String>.from(fields);
    _applyAction(payload, action);
    try {
      if (attachment != null && attachmentFieldName != null) {
        final form = FormData();
        payload.forEach((name, value) => form.fields.add(MapEntry(name, value)));
        form.files.add(MapEntry(
          attachmentFieldName,
          MultipartFile.fromBytes(attachment, filename: attachmentName ?? 'attachment'),
        ));
        final response = await _dio.post<String>(
          _leaveApplicationPath,
          data: form,
          options: Options(responseType: ResponseType.plain),
        );
        return response.data ?? '';
      }
      final response = await _dio.post<String>(
        _leaveApplicationPath,
        data: payload,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
        ),
      );
      return response.data ?? '';
    } on DioException catch (error) {
      if (error.error is Failure) {
        if (error.error is SessionExpiredFailure) onSessionExpired?.call();
        throw error.error as Failure;
      }
      rethrow;
    }
  }

  Future<String> _getPage() async {
    try {
      return (await _dio.get<String>(
        _leaveApplicationPath,
        options: Options(responseType: ResponseType.plain),
      )).data ?? '';
    } on DioException catch (error) {
      if (error.error is Failure) {
        if (error.error is SessionExpiredFailure) onSessionExpired?.call();
        throw error.error as Failure;
      }
      rethrow;
    }
  }

  static Element? _ancestor(Element element, String localName) {
    for (var parent = element.parent; parent != null; parent = parent.parent) {
      if (parent.localName == localName) return parent;
    }
    return null;
  }

  static String _friendlyName(String name, String id) {
    final raw = name.isNotEmpty ? name : id;
    return raw.split(RegExp(r'[:$]')).last.replaceAll(RegExp(r'_'), ' ');
  }

  static String? _knownLabel(String name) {
    if (name.endsWith(':ddlABSENCE')) return '選擇假別';
    if (name.endsWith(':txtEXCESE_DT')) return '請假日期';
    if (name.endsWith(':txtREASON')) return '請假原因';
    if (name.endsWith(':fuFILE')) return '附檔';
    return null;
  }

  static List<LeaveAction> _actions(Iterable<Element> elements) {
    final actions = <LeaveAction>[];
    final postBack = RegExp(r"""__doPostBack\(['"]([^'"]+)['"]\s*,\s*['"]([^'"]*)['"]\)""");
    for (final element in elements) {
      final type = (element.attributes['type'] ?? element.localName ?? '').toLowerCase();
      final name = element.attributes['name'] ?? '';
      final value = element.attributes['value'] ?? '';
      final label = element.text.trim().isNotEmpty
          ? element.text.trim()
          : value.isNotEmpty
              ? value
              : element.attributes['alt'] ?? element.attributes['title'] ?? element.text.trim();
      final href = element.attributes['href'] ?? '';
      final match = postBack.firstMatch('$href ${element.attributes['onclick'] ?? ''}');
      final eventTarget = match?.group(1);
      final eventArgument = match?.group(2) ?? '';
      final isFormButton = type == 'submit' || type == 'image' ||
          eventTarget != null || RegExp(r'新增|送出|查詢|取消|刪除|修改|存檔|申請|撤回|確定')
              .hasMatch('$label ${element.id} $name');
      if (!isFormButton) continue;
      actions.add(LeaveAction(
        label: label.isEmpty ? _friendlyName(name, element.id) : label,
        name: name,
        value: value,
        eventTarget: eventTarget,
        eventArgument: eventArgument,
        imageButton: type == 'image',
      ));
    }
    return actions;
  }

  static (List<String>, List<LeaveRecord>) _records(Document doc) {
    for (final table in doc.querySelectorAll('table[id*="dgData"],table.DgTable')) {
      final headerRow = table.querySelector('tr');
      final headers = headerRow?.children
              .where((cell) => cell.localName == 'th' || cell.localName == 'td')
              .map((cell) => cell.text.trim()).toList() ?? const <String>[];
      final normalizedHeaders = headers.map((value) => value.replaceAll(RegExp(r'\s+'), '')).toList();
      final relevantHeader = normalizedHeaders.length >= 3 &&
          normalizedHeaders.any((header) => header.contains('假別') || header.contains('請假')) &&
          normalizedHeaders.any((header) => header.contains('日期') || header.contains('節次')) &&
          normalizedHeaders.any((header) => header.contains('狀態') || header.contains('單號'));
      if (!relevantHeader) continue;

      final rows = <LeaveRecord>[];
      for (final row in table.querySelectorAll('tr').skip(1)) {
        if (_ancestor(row, 'table') != table) continue;
        final cells = row.children.where((cell) => cell.localName == 'td').toList();
        if (cells.isEmpty) continue;
        final values = cells.map((cell) => cell.text.trim()).toList();
        if (values.every((value) => value.isEmpty)) continue;
        final rowActions = _actions(row.querySelectorAll('input[type="submit"],input[type="button"],input[type="image"],button,a'));
        final cancel = rowActions.where((action) => RegExp(
          r'取消|刪除|撤回|cancel|delete|withdraw', caseSensitive: false,
        ).hasMatch('${action.label} ${action.name} ${action.eventTarget ?? ''}')).firstOrNull;
        rows.add(LeaveRecord(values: values, cancelAction: cancel));
      }
      return (headers, rows);
    }
    return (const <String>[], const <LeaveRecord>[]);
  }

  static void _applyAction(Map<String, String> fields, LeaveAction action) {
    if (action.eventTarget != null) {
      fields['__EVENTTARGET'] = action.eventTarget!;
      fields['__EVENTARGUMENT'] = action.eventArgument;
      return;
    }
    if (action.imageButton && action.name.isNotEmpty) {
      fields['${action.name}.x'] = '0';
      fields['${action.name}.y'] = '0';
    } else if (action.name.isNotEmpty) {
      fields[action.name] = action.value;
    }
  }
}
