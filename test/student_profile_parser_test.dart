// A0207S 個人資料解析器測試（fixture 為虛構資料，結構取自真實頁面）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nptu_campus/data/parsers/student_profile_parser.dart';

void main() {
  group('A0207S 個人資料解析', () {
    late String html;

    setUpAll(() {
      html = File('test/fixtures/a0207s_profile.html').readAsStringSync();
    });

    test('以控制項 name 取出結構化欄位', () {
      final profile = parseStudentProfile(html).profile;

      expect(profile.studentId, 'AAA115012');
      expect(profile.name, '王小明');
      expect(profile.englishName, 'WANG,XIAO-MING');
      expect(profile.email, 'test.student@example.com');
      expect(profile.mobile, '0912345678');
      expect(profile.currentAddress, '屏東縣屏東市測試路1號');
      expect(profile.emergencyName, '王大明');
      expect(profile.emergencyPhone, '0987654321');
      expect(profile.dormRoom, '無住宿');
      expect(profile.isEmpty, isFalse);
    });

    test('代碼與民國日期轉成可讀文字', () {
      final profile = parseStudentProfile(html).profile;

      expect(profile.statusLabel, '在學');
      expect(profile.studentTypeLabel, '一般生');
      expect(profile.feeTypeLabel, '自費');
      expect(profile.genderLabel, '男');
      expect(profile.admissionLabel, '115/09');
      expect(profile.birthDateLabel, '93/02/26');
    });

    test('巢狀表頭與重複控制項不會產生錯位資料', () {
      final profile = parseStudentProfile(html).profile;

      // 舊作法會把 CSS 文字與 <戶籍資料> 這類區段標題當成欄位；
      // 現在所有值都必須是乾淨的資料，不含標籤或樣式殘留。
      final values = <String>[
        profile.name,
        profile.studentId,
        profile.email,
        profile.status,
        profile.currentAddress,
        profile.emergencyName,
      ];
      for (final value in values) {
        expect(value.contains('<'), isFalse);
        expect(value.contains('{'), isFalse);
        expect(value.contains('：'), isFalse);
      }
      expect(profile.email, isNot(profile.name));
    });

    test('身分證與護照號碼不會進入模型', () {
      final profile = parseStudentProfile(html).profile;

      // 模型沒有這些欄位（編譯期保證）；再確認公開欄位沒有殘留測試用識別碼。
      final values = <String>[
        profile.name,
        profile.studentId,
        profile.englishName,
        profile.email,
        profile.nationality,
        profile.admissionRef,
      ];
      expect(values.any((value) => value.contains('A123456789')), isFalse);
      expect(values.any((value) => value.contains('999999999')), isFalse);
    });

    test('頭像來源取自 A0207A_imgSTD_PIC', () {
      expect(parseStudentProfile(html).photoSource, 'A0207S4Page.aspx?temp=1');
    });

    test('沒有資料的頁面視為空', () {
      expect(
        parseStudentProfile('<html><body></body></html>').profile.isEmpty,
        isTrue,
      );
      expect(
        parseStudentProfile('<html><body></body></html>').photoSource,
        isNull,
      );
    });
  });
}
