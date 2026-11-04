// 版面驗收用截圖：以 Light / Dark 兩主題渲染主要頁面。
//
// 產生方式：flutter test --update-goldens test/screenshots_test.dart
// 輸出：docs/screenshots/<page>_<light|dark>.png
//
// 這個 harness 同時是 overflow 檢查：任何 RenderFlex overflow 都會讓測試失敗。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nptu_campus/app/providers.dart';
import 'package:nptu_campus/core/network/providers.dart';
import 'package:nptu_campus/core/theme/app_dimensions.dart';
import 'package:nptu_campus/core/theme/app_theme.dart';
import 'package:nptu_campus/data/parsers/student_profile_parser.dart';
import 'package:nptu_campus/domain/entities/semester_table.dart';
import 'package:nptu_campus/features/announcements/announcements_page.dart';
import 'package:nptu_campus/features/auth/login_page.dart';
import 'package:nptu_campus/features/dashboard/dashboard_page.dart';
import 'package:nptu_campus/features/grades/grades_page.dart';
import 'package:nptu_campus/features/profile/profile_page.dart';
import 'package:nptu_campus/features/settings/settings_page.dart';
import 'package:nptu_campus/features/student_data_providers.dart';
import 'package:nptu_campus/features/timetable/timetable_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_auth.dart';

const _fontPath = r'C:\Windows\Fonts\kaiu.ttf';
const _screenshotDir = '../docs/screenshots';

late SharedPreferences _prefs;

final _today = DateTime.now().weekday;

final _profile = parseStudentProfile(
  File('test/fixtures/a0207s_profile.html').readAsStringSync(),
).profile;

final _courses = <Map<String, String>>[
  {
    'name': '專題討論（一）',
    'teacher': '陳志明',
    'room': '資訊館 302',
    'weekday': '$_today',
    'period': '05',
    'credits': '1',
    'class': '資工三甲',
  },
  {
    'name': '作業系統與實作',
    'teacher': '林美惠',
    'room': '資訊館 205',
    'weekday': '$_today',
    'period': '0607',
    'credits': '3',
    'class': '資工三甲',
  },
  {
    'name': '資料庫系統專題研究與實務應用',
    'teacher': '王建民',
    'room': '共同教學大樓 B1 電腦教室',
    'weekday': '${_today % 7 + 1}',
    'period': '02',
    'credits': '3',
    'class': '資工三甲',
  },
];

final _announcements = <Map<String, String>>[
  {
    'date': '2026/11/02',
    'title': '114 學年度第 1 學期期中教學意見調查開始填寫',
    'category': '教務',
    'unit': '教務處課務組',
  },
  {
    'date': '2026/10/30',
    'title': '圖書館自動化系統維護公告（11/5 22:00 至 11/6 06:00 暫停服務）',
    'category': '系統',
    'unit': '圖書資訊處',
  },
  {
    'date': '2026/10/28',
    'title': '學生宿舍 114 學年度第 2 學期續住申請',
    'category': '學務',
    'unit': '學務處生活輔導組',
  },
];

final _grades = SemesterTable(
  semesters: const [
    SemesterOption('1141', '114 學年度 第 1 學期'),
    SemesterOption('1132', '113 學年度 第 2 學期'),
  ],
  selected: '1141',
  headers: const ['科目名稱', '學分', '成績'],
  rows: const [
    ['專題討論（一）', '1', '90'],
    ['作業系統與實作', '3', '86'],
    ['資料庫系統', '3', '91'],
    ['計算機網路', '3', '78'],
    ['演算法', '3', '84'],
    ['通識：台灣社會變遷', '2', '88'],
  ],
);

ThemeData _themeFor(bool dark) {
  final base = dark ? buildDarkTheme() : buildLightTheme();
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'ShotFont'),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'ShotFont'),
  );
}

Widget _app(Widget page, {required bool dark}) => ProviderScope(
  overrides: [
    sharedPreferencesProvider.overrideWithValue(_prefs),
    authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
    profileProvider.overrideWith((ref) async => _profile),
    coursesProvider.overrideWith((ref) async => _courses),
    announcementsProvider.overrideWith((ref) async => _announcements),
    gradesProvider.overrideWith((ref, semester) async => _grades),
  ],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _themeFor(dark),
    home: page,
  ),
);

Future<void> _registerFont(String family, String path) async {
  if (!File(path).existsSync()) return;
  final bytes = File(path).readAsBytesSync();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

/// Flutter 測試環境預設字型不含 CJK，因此把系統中文字型也註冊成預設字族；
/// 否則截圖上的中文會變成方框。MaterialIcons 同樣需要手動載入。
Future<void> _loadFont() async {
  await _registerFont('ShotFont', _fontPath);
  await _registerFont('Roboto', _fontPath);
  final iconFont = _findMaterialIcons();
  if (iconFont != null) await _registerFont('MaterialIcons', iconFont);
}

/// 從 Flutter SDK 快取找出 MaterialIcons 字型檔。
String? _findMaterialIcons() {
  var dir = File(Platform.resolvedExecutable).parent;
  for (var depth = 0; depth < 8; depth++) {
    final candidate = File(
      '${dir.path}/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (candidate.existsSync()) return candidate.path;
    if (dir.parent.path == dir.path) break;
    dir = dir.parent;
  }
  return null;
}

Future<void> _capture(
  WidgetTester tester,
  String name,
  Widget page, {
  required bool dark,
}) async {
  await tester.pumpWidget(_app(page, dark: dark));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('$_screenshotDir/${name}_${dark ? 'dark' : 'light'}.png'),
  );
}

void main() {
  setUpAll(() async {
    await _loadFont();
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
    Directory(_screenshotDir).createSync(recursive: true);
  });

  for (final dark in [false, true]) {
    final label = dark ? 'dark' : 'light';

    testWidgets('$_screenshotDir 主要頁面（$label）', (tester) async {
      tester.view.physicalSize = const Size(824, 1830);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      expect(
        tester.view.physicalSize.width / tester.view.devicePixelRatio,
        closeTo(412, 0.1),
      );

      await _capture(tester, 'login', const LoginPage(), dark: dark);
      await _capture(tester, 'dashboard', const DashboardPage(), dark: dark);
      await _capture(tester, 'timetable', const TimetablePage(), dark: dark);
      await _capture(tester, 'grades', const GradesPage(), dark: dark);
      await _capture(
        tester,
        'announcements',
        const AnnouncementsPage(),
        dark: dark,
      );
      await _capture(tester, 'profile', const ProfilePage(), dark: dark);
      await _capture(tester, 'settings', const SettingsPage(), dark: dark);
    });
  }

  testWidgets('大字體（1.3x）不溢位', (tester) async {
    tester.view.physicalSize = const Size(824, 1830);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(_app(const DashboardPage(), dark: false));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('窄螢幕（320dp）不溢位', (tester) async {
    tester.view.physicalSize = const Size(320 * 2, 640 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(const TimetablePage(), dark: true));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(AppDimensions.pagePadding, 20);
  });
}
