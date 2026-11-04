// 請假取消流程測試（依 2026-11 在 webap 實測的 B0155A 行為）：
// - 欄位名稱是 `B0155A:` 前綴、日期欄拼成 `txtEXCESE_DT`、節次是 CheckBoxList。
// - 請假紀錄表 `B0155A_dgData` 的「刪除」欄是一個 checkbox，
//   取消＝勾選該列 + 送出表格下方的 image 按鈕 `B0155A:ibtDeleteUp`。
// - 同頁的「取消」(ibtCancelUp) 只是離開畫面，不是刪除。
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nptu_campus/core/errors/failures.dart';
import 'package:nptu_campus/data/datasources/webforms_leave_api.dart';

/// 攔截請求，不實際連線。
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.page);

  final String page;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      page,
      200,
      headers: {
        Headers.contentTypeHeader: ['text/html; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late String fixture;
  late _RecordingAdapter adapter;
  late WebFormsLeaveApi api;

  void usePage(String page) {
    adapter = _RecordingAdapter(page);
    api = WebFormsLeaveApi(
      Dio(BaseOptions(baseUrl: 'https://webap.nptu.edu.tw'))
        ..httpClientAdapter = adapter,
    );
  }

  setUp(() {
    fixture = File('test/fixtures/b0155a_leave.html').readAsStringSync();
    usePage(fixture);
  });

  test('實際頁面欄位都能辨識，頁面預填的日期會保留', () async {
    final definition = await api.load();

    final labels = definition.controls.map((control) => control.label).toList();
    expect(definition.controls, isNotEmpty);
    expect(labels, containsAll(<String>['假別', '請假日期', '請假原因', '附檔']));

    final date = definition.controls.firstWhere(
      (control) => control.shortName == 'txtEXCESE_DT',
    );
    expect(date.label, '請假日期');
    expect(date.value, '2026/11/05', reason: '頁面預填的日期需保留');
    expect(date.disabled, isFalse);

    final absence = definition.controls.firstWhere(
      (control) => control.shortName == 'ddlABSENCE',
    );
    expect(absence.options.map((option) => option.value), contains('C'));

    final lessons = definition.controls
        .where((control) => control.shortName == 'cblLESSON_ID')
        .toList();
    expect(lessons, hasLength(4));
    expect(lessons.map((control) => control.label), containsAll(['M', '01']));
    expect(lessons.first.value, '78', reason: '合併節次的值需原樣保留');
  });

  test('節次時間表不會被誤認為紀錄，且兩筆紀錄都可取消', () async {
    final definition = await api.load();

    expect(definition.recordHeaders.first, '刪除');
    expect(definition.records, hasLength(2));
    expect(definition.records.first.values[1], '2026/11/05');
    expect(definition.records.last.values[5], '已核准');
    expect(definition.cancellableRecords, 2);

    // 真正的刪除鈕是 ibtDeleteUp，不是 ibtCancelUp。
    expect(definition.deleteAction?.name, 'B0155A:ibtDeleteUp');
  });

  test('取消紀錄會送出該列 checkbox 與 ibtDeleteUp.x / .y（已對真伺服器驗證）', () async {
    final definition = await api.load();

    await api.cancelRecord(
      definition: definition,
      record: definition.records.first,
    );

    final posted = adapter.requests.last;
    expect(posted.method, 'POST');
    expect(posted.path, '/Web/B01/B0155APage.aspx');
    final body = posted.data as Map;
    expect(body['B0155A:dgData:_ctl2:chkDel'], 'on');
    expect(body['B0155A:ibtDeleteUp.x'], '0');
    expect(body['B0155A:ibtDeleteUp.y'], '0');
    expect(body['__VIEWSTATE'], 'VS-LEAVE');
    expect(body['__EVENTVALIDATION'], 'EV-LEAVE');
    expect(body['__EVENTTARGET'], isEmpty);
    expect(body.containsKey('B0155A:ibtSaveUp.x'), isFalse);
  });

  test('第二列會勾選自己的 checkbox', () async {
    final definition = await api.load();

    await api.cancelRecord(
      definition: definition,
      record: definition.records.last,
    );

    final body = adapter.requests.last.data as Map;
    expect(body['B0155A:dgData:_ctl3:chkDel'], 'on');
    expect(body.containsKey('B0155A:dgData:_ctl2:chkDel'), isFalse);
  });

  test('仍有系統使用逐列 __doPostBack 取消鈕時也能處理', () async {
    usePage('''
<html><body><form method="post" action="./B0155APage.aspx">
<input type="hidden" name="__VIEWSTATE" value="VS" />
<select name="B0155A:ddlABSENCE"><option value="B">B.事假</option></select>
<table class="DgTable" id="B0155A_dgData">
<tr><th>請假日期</th><th>假別</th><th>功能</th></tr>
<tr><td>2026/10/30</td><td>病假</td>
<td><a href="javascript:__doPostBack('B0155A\$dgData\$ctl02\$ibtDeleteUp','')">取消</a></td></tr>
</table></form></body></html>
''');

    final definition = await api.load();
    expect(definition.cancellableRecords, 1);

    await api.cancelRecord(
      definition: definition,
      record: definition.records.first,
    );

    final body = adapter.requests.last.data as Map;
    expect(body['__EVENTTARGET'], r'B0155A$dgData$ctl02$ibtDeleteUp');
    expect(body['__EVENTARGUMENT'], '');
  });

  test('沒有取消欄位的紀錄會給出明確錯誤', () async {
    final definition = await api.load();

    await expectLater(
      api.cancelRecord(
        definition: definition,
        record: const LeaveRecord(values: <String>['病假']),
      ),
      throwsA(isA<DataParseFailure>()),
    );
  });
}
