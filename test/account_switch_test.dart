// 帳號切換的資料隔離測試：A 登出後不得留下任何 A 的資料，
// 且 A 帳號晚到的請求不能覆蓋 B 帳號畫面。
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nptu_campus/app/providers.dart';
import 'package:nptu_campus/core/network/providers.dart';
import 'package:nptu_campus/data/datasources/student_data_api.dart';
import 'package:nptu_campus/domain/entities/auth_session.dart';
import 'package:nptu_campus/domain/entities/semester_table.dart';
import 'package:nptu_campus/domain/entities/student_profile.dart';
import 'package:nptu_campus/features/student_data_providers.dart';

import 'support/fake_auth.dart';

/// 每個帳號一個實例，回傳該帳號自己的資料；可選擇卡住以模擬慢速請求。
class _AccountApi implements StudentDataApi {
  _AccountApi(this.label, {this.gate});

  final String label;
  final Completer<void>? gate;

  @override
  Future<List<Map<String, String>>> announcements() async {
    if (gate != null) await gate!.future;
    return [
      {'title': '公告-$label', 'date': '2026/11/04', 'unit': label},
    ];
  }

  @override
  Future<List<Map<String, String>>> courses() async {
    if (gate != null) await gate!.future;
    return [
      {'name': '課程-$label', 'weekday': '3', 'period': '05'},
    ];
  }

  @override
  Future<StudentProfile> profile() async =>
      throw UnimplementedError('本測試不需要個資');

  @override
  Future<SemesterTable> grades({String? semester}) async =>
      throw UnimplementedError('本測試不需要成績');

  @override
  Future<SemesterTable> attendance({String? semester}) async =>
      throw UnimplementedError('本測試不需要出缺勤');
}

/// 用 `when`（頁面實際渲染方式）取得目前狀態的標籤。
String _labelOf(AsyncValue<List<Map<String, String>>> value) => value.when(
  data: (items) => items.first['title'] ?? '',
  loading: () => 'loading',
  error: (_, _) => 'error',
);

void main() {
  late ProviderContainer container;
  late FakeAuthRepository auth;
  final gates = <String, Completer<void>>{};

  setUp(() {
    auth = FakeAuthRepository();
    gates.clear();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        // 依目前帳號建立 API，等同伺服器端「每個帳號各自的資料」。
        studentDataApiProvider.overrideWith((ref) {
          final account = ref.watch(currentAccountProvider);
          if (account == null) {
            return _AccountApi('未登入');
          }
          return _AccountApi(account, gate: gates[account]);
        }),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> signIn(String account) => container
      .read(authStatusProvider.notifier)
      .signIn(
        account: account,
        password: 'pw',
        captcha: '1234',
        preparation: const LoginPreparation(hiddenFields: {}, captchaBytes: []),
      );

  test('登入後 Provider 使用該帳號並記錄世代', () async {
    await signIn('A');
    expect(container.read(currentAccountProvider), 'A');
    expect(container.read(sessionGenerationProvider), 1);

    final announcements = await container.read(announcementsProvider.future);
    expect(announcements.first['title'], '公告-A');
  });

  test('登出會清掉帳號、遞增世代並作廢資料快取', () async {
    await signIn('A');
    expect(
      (await container.read(announcementsProvider.future)).first['title'],
      '公告-A',
    );

    await container.read(authStatusProvider.notifier).signOut();

    expect(container.read(authStatusProvider), AuthStatus.loggedOut);
    expect(container.read(currentAccountProvider), isNull);
    expect(container.read(sessionGenerationProvider), 2);

    // 關鍵：畫面讀到的狀態已不是 A 的資料（loading 或錯誤，不會是 公告-A）。
    expect(_labelOf(container.read(announcementsProvider)), isNot('公告-A'));
  });

  test('A → B：畫面只會看到 B 的資料', () async {
    await signIn('A');
    expect(
      (await container.read(coursesProvider.future)).first['name'],
      '課程-A',
    );

    await signIn('B');
    expect(container.read(currentAccountProvider), 'B');
    expect(container.read(sessionGenerationProvider), 2);
    expect(
      (await container.read(coursesProvider.future)).first['name'],
      '課程-B',
    );
  });

  test('A 的慢速回應不能覆蓋 B 的資料', () async {
    final gateA = gates['A'] = Completer<void>();
    await signIn('A');

    // A 的請求卡住（尚未回傳）；保留這個 future 代表「舊世代的請求」。
    final pendingA = container.read(announcementsProvider.future);
    unawaited(pendingA.then((_) {}, onError: (_) {}));

    // 使用者登出並改用 B 登入。
    await container.read(authStatusProvider.notifier).signOut();
    await signIn('B');
    expect(
      (await container.read(announcementsProvider.future)).first['title'],
      '公告-B',
    );

    // A 的請求這時才回來。
    gateA.complete();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    // 舊請求完成後，目前 Provider 狀態仍必須是 B。
    expect(_labelOf(container.read(announcementsProvider)), '公告-B');
    expect(
      (await container.read(announcementsProvider.future)).first['title'],
      '公告-B',
    );
  });

  test('B 重新整理只會拿到 B 的資料，再切回 A 也是新的 A 資料', () async {
    await signIn('A');
    expect(
      (await container.read(coursesProvider.future)).first['name'],
      '課程-A',
    );

    await signIn('B');
    container.invalidate(coursesProvider);
    expect(
      (await container.read(coursesProvider.future)).first['name'],
      '課程-B',
    );

    await signIn('A');
    expect(container.read(sessionGenerationProvider), 3);
    expect(
      (await container.read(coursesProvider.future)).first['name'],
      '課程-A',
    );
  });
}
