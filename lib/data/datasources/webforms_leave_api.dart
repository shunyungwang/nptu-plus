/// Native form model and WebForms submit helpers for student leave requests.
///
/// 校務系統（B0155A）是標準 ASP.NET WebForms（2026-11 實測）：
/// - 欄位 `name` 以 `B0155A:` 為前綴，例如 `B0155A:txtEXCESE_DT`（校方拼法）。
/// - 節次是 CheckBoxList：`B0155A:cblLESSON_ID:0..14`，值為 `1..12` 與 `78/45/89` 等合併節次。
/// - 請假紀錄是 GridView `B0155A_dgData`，第一欄是「刪除」，
///   每一列的刪除鈕是自己的 postback（link 或 image 按鈕）。
/// 因此取消請假的正確做法是「送出該列的 postback」，而不是自行拼日期與節次。
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
    this.readOnly = false,
  });

  final String name;
  final String label;
  final String type;
  final String value;
  final List<LeaveOption> options;
  final bool required;
  final bool disabled;
  final bool checked;

  /// 校務系統把日期欄位設為 `readonly`（改用日期選擇器），仍可填寫。
  final bool readOnly;

  /// 控制項名稱去掉頁面前綴與清單索引（例如 `txtEXCESE_DT`、`cblLESSON_ID`）。
  String get shortName {
    final parts = name
        .split(RegExp(r'[:$]'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length > 1 && int.tryParse(parts.last) != null) {
      parts.removeLast();
    }
    return parts.isEmpty ? name : parts.last;
  }
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

  /// 是否為取消／刪除類操作（逐列取消鈕用）。
  bool get isCancel => RegExp(
    r'取消|刪除|撤回|cancel|delete|withdraw',
    caseSensitive: false,
  ).hasMatch('$label $name ${eventTarget ?? ''}');

  /// 是否為真正刪除資料的按鈕（頁面層級的「刪除」）。
  ///
  /// 注意同頁還有「取消」(ibtCancelUp，只是離開畫面)，不能混為一談。
  bool get isDelete => RegExp(
    r'刪除|delete|ibtDel',
    caseSensitive: false,
  ).hasMatch('$label $name ${eventTarget ?? ''}');
}

/// 紀錄列上用來選取該筆資料的欄位（例如 `B0155A:dgData:_ctl2:chkDel`）。
class LeaveSelection {
  const LeaveSelection({required this.name, required this.value});

  final String name;
  final String value;
}

class LeaveRecord {
  const LeaveRecord({required this.values, this.cancelAction, this.selection});
  final List<String> values;

  /// 該列自己的取消 postback（GridView 每列一個刪除鈕時）；沒有則為 null。
  final LeaveAction? cancelAction;

  /// 該列的選取 checkbox（勾選後按頁面的「刪除」）。
  final LeaveSelection? selection;
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

  /// 表單上的取消／刪除操作（非逐列）。
  List<LeaveAction> get cancelActions =>
      actions.where((action) => action.isCancel).toList();

  /// 真正刪除資料的按鈕（B0155A 是表格下方的 image 按鈕 `ibtDeleteUp`）。
  LeaveAction? get deleteAction =>
      actions.where((action) => action.isDelete).firstOrNull;

  /// 這筆紀錄能否在 App 內取消。
  bool canCancel(LeaveRecord record) =>
      record.cancelAction != null ||
      (record.selection != null && deleteAction != null);

  /// 可在 App 內取消的紀錄數。
  int get cancellableRecords => records.where(canCancel).length;
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
      final type = (control.attributes['type'] ?? control.localName ?? 'text')
          .toLowerCase();
      if (type == 'hidden' ||
          type == 'submit' ||
          type == 'button' ||
          type == 'image' ||
          type == 'reset') {
        continue;
      }
      final name = control.attributes['name'] ?? '';
      if (name.isEmpty || name.startsWith('CommonHeader:')) continue;
      final id = control.id;
      final labelFor = id.isEmpty
          ? null
          : doc.querySelector('label[for="$id"]')?.text.trim();
      final controlCell = _ancestor(control, 'td');
      final cells =
          controlCell?.parent?.querySelectorAll('td') ?? const <Element>[];
      final cellIndex = controlCell == null ? -1 : cells.indexOf(controlCell);
      final previousCellText = cellIndex > 0
          ? cells[cellIndex - 1].text.trim()
          : '';
      // CheckBoxList（例如節次 `cblLESSON_ID:0`）的標籤在它自己的表格儲存格內。
      final ownCellText = controlCell?.text.trim() ?? '';
      var label = _knownLabel(name) ?? labelFor ?? previousCellText;
      if (type == 'checkbox' &&
          ownCellText.isNotEmpty &&
          ownCellText.length <= 8) {
        label = ownCellText;
      }
      if (label.isEmpty) {
        label =
            control.attributes['aria-label'] ??
            control.attributes['title'] ??
            '';
      }
      if (label.isEmpty) label = _friendlyName(name, id);
      label = label.replaceAll(RegExp(r'[:：*\s]+$'), '').trim();

      final options = control.localName == 'select'
          ? control
                .querySelectorAll('option')
                .map(
                  (option) => LeaveOption(
                    option.attributes['value'] ?? '',
                    option.text.trim(),
                  ),
                )
                .where((option) => option.label.isNotEmpty)
                .toList()
          : const <LeaveOption>[];
      final required =
          control.attributes.containsKey('required') ||
          (control.attributes['class'] ?? '')
              .split(RegExp(r'\s+'))
              .contains('Need') ||
          (id.isNotEmpty &&
              doc.querySelector('[controltovalidate="$id"]') != null) ||
          label.contains('*');
      final value = switch (control.localName) {
        'select' =>
          control.querySelector('option[selected]')?.attributes['value'] ??
              control.querySelector('option')?.attributes['value'] ??
              '',
        _ when type == 'checkbox' => control.attributes['value'] ?? 'on',
        _ => control.attributes['value'] ?? '',
      };
      controls.add(
        LeaveControl(
          name: name,
          label: label,
          type: type,
          value: value,
          options: options,
          required: required,
          disabled: control.attributes.containsKey('disabled'),
          readOnly: control.attributes.containsKey('readonly'),
          checked: false,
        ),
      );
    }

    final actions = _actions(
      doc.querySelectorAll(
        'input[type="submit"],input[type="button"],input[type="image"],button,a',
      ),
    );
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

  /// 取消一筆「有取消按鈕」的請假紀錄：直接重送該列的 postback。
  Future<String> cancelRecord({
    required LeavePageDefinition definition,
    required LeaveRecord record,
  }) async {
    final fields = Map<String, String>.from(definition.hiddenFields);

    // 情況一：每一列都有自己的取消 postback。
    final rowAction = record.cancelAction;
    if (rowAction != null) {
      return submit(fields: fields, action: rowAction);
    }

    // 情況二（B0155A 實際行為）：勾選該列的 chkDel，再按表格下方的「刪除」。
    final deleteAction = definition.deleteAction;
    final selection = record.selection;
    if (deleteAction != null && selection != null) {
      fields[selection.name] = selection.value;
      return submit(fields: fields, action: deleteAction);
    }

    throw DataParseFailure(detail: '此筆請假紀錄沒有可用的取消欄位，請重新載入後再試。');
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
        payload.forEach(
          (name, value) => form.fields.add(MapEntry(name, value)),
        );
        form.files.add(
          MapEntry(
            attachmentFieldName,
            MultipartFile.fromBytes(
              attachment,
              filename: attachmentName ?? 'attachment',
            ),
          ),
        );
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
          )).data ??
          '';
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

  /// 以控制項名稱的語意片段辨識欄位，不假設完整名稱或拼法。
  static String? _knownLabel(String name) {
    final upper = name.toUpperCase();
    if (upper.contains('ABSENCE') || upper.contains('LEAVEKIND')) return '假別';
    if (upper.contains('EXCE') && upper.contains('DT')) return '請假日期';
    if (upper.contains('REASON') || upper.contains('MEMO')) return '請假原因';
    if (upper.contains('FU_FILE') || upper.contains('FILEUPLOAD')) return '附檔';
    if (upper.contains('COURSE') || upper.contains('SUBJ')) return '課程';
    return null;
  }

  static List<LeaveAction> _actions(Iterable<Element> elements) {
    final actions = <LeaveAction>[];
    final postBack = RegExp(
      r"""__doPostBack\(['"]([^'"]+)['"]\s*,\s*['"]([^'"]*)['"]\)""",
    );
    for (final element in elements) {
      final type = (element.attributes['type'] ?? element.localName ?? '')
          .toLowerCase();
      final name = element.attributes['name'] ?? '';
      final value = element.attributes['value'] ?? '';
      final text = element.text.trim();
      final label = text.isNotEmpty
          ? text
          : value.isNotEmpty
          ? value
          : element.attributes['alt'] ?? element.attributes['title'] ?? '';
      final href = element.attributes['href'] ?? '';
      final match = postBack.firstMatch(
        '$href ${element.attributes['onclick'] ?? ''}',
      );
      final eventTarget = match?.group(1);
      final eventArgument = match?.group(2) ?? '';
      final isFormButton =
          type == 'submit' ||
          type == 'image' ||
          eventTarget != null ||
          RegExp(
            r'新增|送出|查詢|取消|刪除|修改|存檔|申請|撤回|確定|delete|cancel',
            caseSensitive: false,
          ).hasMatch('$label ${element.id} $name');
      if (!isFormButton) continue;
      actions.add(
        LeaveAction(
          label: label.isEmpty ? _friendlyName(name, element.id) : label,
          name: name,
          value: value,
          eventTarget: eventTarget,
          eventArgument: eventArgument,
          imageButton: type == 'image',
        ),
      );
    }
    return actions;
  }

  static (List<String>, List<LeaveRecord>) _records(Document doc) {
    for (final table in doc.querySelectorAll(
      'table[id*="dgData"],table.DgTable',
    )) {
      final headerRow = table.querySelector('tr');
      final headers =
          headerRow?.children
              .where((cell) => cell.localName == 'th' || cell.localName == 'td')
              .map((cell) => cell.text.trim())
              .toList() ??
          const <String>[];
      final normalizedHeaders = headers
          .map((value) => value.replaceAll(RegExp(r'\s+'), ''))
          .toList();
      // 只要求「假別/請假」與「日期/節次/時間」其中之一，
      // 不再要求狀態或單號欄位（各學年度欄位略有差異）。
      final looksLikeLeaveGrid =
          normalizedHeaders.length >= 2 &&
          normalizedHeaders.any(
            (header) =>
                header.contains('假別') ||
                header.contains('請假') ||
                header.contains('假單'),
          ) &&
          normalizedHeaders.any(
            (header) =>
                header.contains('日期') ||
                header.contains('節次') ||
                header.contains('時間') ||
                header.contains('起'),
          );
      if (!looksLikeLeaveGrid) continue;

      final rows = <LeaveRecord>[];
      for (final row in table.querySelectorAll('tr').skip(1)) {
        if (_ancestor(row, 'table') != table) continue;
        final cells = row.children
            .where((cell) => cell.localName == 'td')
            .toList();
        if (cells.isEmpty) continue;
        final values = cells.map((cell) => cell.text.trim()).toList();
        if (values.every((value) => value.isEmpty)) continue;
        final rowActions = _actions(
          row.querySelectorAll(
            'input[type="submit"],input[type="button"],input[type="image"],button,a',
          ),
        );
        final cancel = rowActions
            .where((action) => action.isCancel)
            .firstOrNull;
        final selectionInput = row.querySelector(
          'input[type="checkbox"][name]',
        );
        final selectionName = selectionInput?.attributes['name'] ?? '';
        rows.add(
          LeaveRecord(
            values: values,
            cancelAction: cancel,
            selection: selectionName.isEmpty
                ? null
                : LeaveSelection(
                    name: selectionName,
                    value: selectionInput?.attributes['value'] ?? 'on',
                  ),
          ),
        );
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
