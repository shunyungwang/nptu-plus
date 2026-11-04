/// Read only student data access for the school's WebForms modules.
library;

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:html/dom.dart' show Element;
import 'package:html/parser.dart' as html_parser;

import '../../core/constants/app_constants.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/semester_table.dart';
import '../../domain/entities/student_profile.dart';
import '../parsers/student_profile_parser.dart';
import '../parsers/webforms_parsers.dart';
import 'student_data_api.dart';

// 既有頁面仍從這裡匯入 SemesterTable／SemesterOption。
export '../../domain/entities/semester_table.dart';

class WebFormsStudentApi implements StudentDataApi {
  WebFormsStudentApi(this._dio, {this.onSessionExpired});
  final Dio _dio;
  final void Function()? onSessionExpired;

  static const _coursesPath = '/Web/A05/A0515SPage.aspx';
  static const _gradesPath = '/Web/A08/A0809QPage.aspx';
  static const _attendancePath = '/Web/B01/B0105SPage.aspx';
  static const _profilePath = '/Web/A02/A0207SPage.aspx';

  Future<String> _get(String path) async {
    try {
      return (await _dio.get<String>(
            path,
            options: Options(responseType: ResponseType.plain),
          )).data ??
          '';
    } catch (error) {
      _rethrowFailure(error);
    }
  }

  Future<String> _post(String path, Map<String, String> fields) async {
    try {
      return (await _dio.post<String>(
            path,
            data: fields,
            options: Options(
              contentType: 'application/x-www-form-urlencoded',
              responseType: ResponseType.plain,
            ),
          )).data ??
          '';
    } catch (error) {
      _rethrowFailure(error);
    }
  }

  Never _rethrowFailure(Object error) {
    if (error is DioException && error.error is Failure) {
      if (error.error is SessionExpiredFailure) onSessionExpired?.call();
      throw error.error as Failure;
    }
    throw error;
  }

  @override
  Future<List<Map<String, String>>> announcements() async {
    final doc = html_parser.parse(await _get(AppConstants.mainPagePath));
    final table = doc.querySelector('#HOTNEWS_dgData');
    if (table == null) return const [];
    return table
        .querySelectorAll('tr')
        .skip(1)
        .map((row) {
          final cells = row.querySelectorAll('td');
          if (cells.length < 4) return <String, String>{};
          return <String, String>{
            'date': cells[0].text.trim(),
            'title': cells[1].text.trim(),
            'category': cells[2].text.trim(),
            'unit': cells[3].text.trim(),
          };
        })
        .where((row) => row['title']!.isNotEmpty)
        .toList();
  }

  @override
  Future<List<Map<String, String>>> courses() async {
    final doc = html_parser.parse(await _get(_coursesPath));
    final table = doc.querySelector('#A0515S1_dgData');
    if (table == null) return const [];
    return table
        .querySelectorAll('tr')
        .skip(1)
        .map((row) {
          final cells = row
              .querySelectorAll('td')
              .map((e) => e.text.trim())
              .toList();
          if (cells.length < 12) return <String, String>{};
          return <String, String>{
            'class': cells[0],
            'courseNo': cells[2],
            'code': cells[3],
            'name': cells[4],
            'type': cells[5],
            'credits': cells[8],
            'teacher': cells[9],
            'room': cells[10],
            'weekday': cells[11],
            'period': cells.length > 12 ? cells[12] : '',
          };
        })
        .where((r) => (r['name'] ?? '').isNotEmpty)
        .toList();
  }

  @override
  Future<StudentProfile> profile() async {
    final page = await _get(_profilePath);
    final parsed = parseStudentProfile(page);
    final imageSource = parsed.photoSource;
    Uint8List? photo;
    if (imageSource != null && imageSource.isNotEmpty) {
      final profileUri = Uri.parse(AppConstants.baseUrl).resolve(_profilePath);
      final photoUri = profileUri.resolve(imageSource);
      try {
        final response = await _dio.get<List<int>>(
          photoUri.toString(),
          options: Options(responseType: ResponseType.bytes),
        );
        final contentType =
            response.headers.value(Headers.contentTypeHeader) ?? '';
        if (response.data != null && contentType.startsWith('image/')) {
          photo = Uint8List.fromList(response.data!);
        }
      } on DioException catch (error) {
        if (error.error is SessionExpiredFailure) onSessionExpired?.call();
        // Keep the profile fields available when the optional photo is unavailable.
      }
    }
    return parsed.profile.withPhoto(photo);
  }

  @override
  Future<SemesterTable> grades({String? semester}) => _semesterTable(
    path: _gradesPath,
    selectName: 'A0809Q:ddlSYSE',
    eventTarget: r'A0809Q$ddlSYSE',
    tableId: 'A0809Q_dgData',
    semester: semester,
  );

  @override
  Future<SemesterTable> attendance({String? semester}) => _semesterTable(
    path: _attendancePath,
    selectName: 'B0105S:ddlSYSE',
    eventTarget: r'B0105S$ddlSYSE',
    tableId: 'B0105S_dgData',
    semester: semester,
  );

  Future<SemesterTable> _semesterTable({
    required String path,
    required String selectName,
    required String eventTarget,
    required String tableId,
    String? semester,
  }) async {
    var page = await _get(path);
    var doc = html_parser.parse(page);
    final select = doc.querySelector('select[name="$selectName"]');
    if (select == null) throw PageParseFailure(cause: '找不到學期選單：$selectName');
    final options = select
        .querySelectorAll('option')
        .map((o) => SemesterOption(o.attributes['value'] ?? '', o.text.trim()))
        .where((o) => o.value.isNotEmpty)
        .toList();
    var selected =
        semester ??
        select.querySelector('option[selected]')?.attributes['value'] ??
        (options.isEmpty ? '' : options.first.value);
    if (selected.isNotEmpty) {
      if (semester != null &&
          semester.isNotEmpty &&
          !options.any((o) => o.value == semester)) {
        throw DataParseFailure(detail: '所選學期不存在');
      }
      final hidden = extractHiddenFields(page);
      hidden.addAll({
        '__EVENTTARGET': eventTarget,
        '__EVENTARGUMENT': '',
        selectName: selected,
      });
      page = await _post(path, hidden);
      doc = html_parser.parse(page);
    }
    final table =
        doc.querySelector('#$tableId') ??
        doc.querySelector('table.DgTable') ??
        doc.querySelector(r'table[id$="dgData"]');
    final tableRows = table?.querySelectorAll('tr') ?? const [];
    var headerIndex = 0;
    if (tableId == 'B0105S_dgData' && tableRows.isNotEmpty) {
      // The live B0105S table uses an explicit 「日期」 header. Prefer that
      // exact column-header row so title/summary rows cannot shift row cells.
      for (var index = 0; index < tableRows.length; index++) {
        final labels = tableRows[index]
            .querySelectorAll('th,td')
            .map((cell) => cell.text.trim().replaceAll(RegExp(r'\s+'), ''));
        if (labels.any((label) => label == '日期')) {
          headerIndex = index;
          break;
        }
      }
      var bestScore = 0;
      if (!tableRows[headerIndex]
          .querySelectorAll('th,td')
          .any((cell) => cell.text.trim() == '日期')) {
        for (var index = 0; index < tableRows.length; index++) {
          final cells = tableRows[index].querySelectorAll('th,td');
          final labels = cells
              .map((cell) => cell.text.trim().replaceAll(RegExp(r'\s+'), ''))
              .toList();
          final score = labels
              .where(
                (label) =>
                    RegExp(r'日期|出缺勤日|發生日|^(年|月份?|日|節次|節數|假別|類別|事由|狀態)$')
                        .hasMatch(label),
              )
              .length;
          if (score > bestScore) {
            bestScore = score;
            headerIndex = index;
          }
        }
      }
      if (bestScore == 0 &&
          !tableRows[headerIndex]
              .querySelectorAll('th,td')
              .any((cell) => cell.text.trim() == '日期')) {
        // Some B0105S responses omit their header row. The live site places
        // 日期 in column 0, so retain every row and label that column explicitly.
        headerIndex = -1;
      }
    }
    var headers = tableRows.isEmpty || headerIndex < 0
        ? const <String>[]
        : tableRows[headerIndex]
              .querySelectorAll('th,td')
              .map(_tableCellValue)
              .toList();
    if (tableId == 'B0105S_dgData' && headers.isEmpty && tableRows.isNotEmpty) {
      final firstRowCellCount = tableRows.first
          .querySelectorAll('th,td')
          .length;
      headers = [
        '日期',
        ...List<String>.filled(
          (firstRowCellCount - 1).clamp(0, 100).toInt(),
          '',
        ),
      ];
    }
    final rows = tableRows
        .skip(headerIndex + 1)
        .map(
          (row) => row.querySelectorAll('th,td').map(_tableCellValue).toList(),
        )
        .toList();
    return SemesterTable(
      semesters: options,
      selected: selected,
      rows: rows,
      headers: headers,
    );
  }
}

/// B0105S renders dates and periods as WebForms controls inside table cells.
/// Element.text omits input values and concatenates all select options, so read
/// the active control value before falling back to ordinary cell text.
String _tableCellValue(Element cell) {
  final select = cell.querySelector('select');
  if (select != null) {
    final option =
        select.querySelector('option[selected]') ??
        select.querySelector('option');
    if (option != null) {
      final label = option.text.trim();
      return label.isNotEmpty
          ? label
          : option.attributes['value']?.trim() ?? '';
    }
  }

  final inputs = cell.querySelectorAll('input[type="text"],input[type="date"]');
  final inputValues = inputs
      .map((input) => input.attributes['value']?.trim() ?? '')
      .where((value) => value.isNotEmpty)
      .toList();
  if (inputValues.isNotEmpty) return inputValues.join(' / ');

  final textarea = cell.querySelector('textarea');
  if (textarea != null && textarea.text.trim().isNotEmpty) {
    return textarea.text.trim();
  }

  return cell.text.trim().replaceAll(RegExp(r'\s+'), ' ');
}
