// 個人資料頁的渲染與去重測試（資料來自去識別化 fixture）。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nptu_campus/core/theme/app_theme.dart';
import 'package:nptu_campus/data/parsers/student_profile_parser.dart';
import 'package:nptu_campus/features/profile/profile_page.dart';
import 'package:nptu_campus/features/student_data_providers.dart';

void main() {
  late final profile = parseStudentProfile(
    File('test/fixtures/a0207s_profile.html').readAsStringSync(),
  ).profile;

  Future<void> pumpProfile(WidgetTester tester) async {
    // 直式手機比例的長畫面，讓三個區塊都能被建構（ListView 為延遲建構）。
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileProvider.overrideWith((ref) async => profile)],
        child: MaterialApp(theme: buildLightTheme(), home: const ProfilePage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('顯示三個資訊區塊與個人識別', (tester) async {
    await pumpProfile(tester);

    expect(find.text('王小明'), findsOneWidget);
    expect(find.text('AAA115012'), findsOneWidget);
    expect(find.text('學籍資訊'), findsOneWidget);
    expect(find.text('聯絡資訊'), findsOneWidget);
    expect(find.text('更多資料'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('學籍代碼與民國日期已轉成可讀文字', (tester) async {
    await pumpProfile(tester);

    expect(find.text('在學'), findsWidgets);
    expect(find.text('一般生'), findsOneWidget);
    expect(find.text('115/09'), findsOneWidget);
    expect(find.text('93/02/26'), findsOneWidget);
  });

  testWidgets('相同的手機與地址只出現一次', (tester) async {
    await pumpProfile(tester);

    // fixture 中行動電話、通訊電話、戶籍電話同號；三個地址也相同。
    expect(find.text('0912345678'), findsOneWidget);
    expect(find.text('屏東縣屏東市測試路1號'), findsOneWidget);
  });
}
