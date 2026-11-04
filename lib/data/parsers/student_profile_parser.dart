/// A0207S 個人資料頁解析器（以表單控制項 `name` 取值）。
///
/// ## 為什麼不用 `td` 兩兩配對
/// A0207S 是巢狀表格 + 唯讀/編輯兩份表單的頁面。實測（真實頁面）以
/// 「每列 td 兩兩配對」的舊作法，會得到 **91 組** label/value（正確約 23 組），
/// 並出現 label 與 value 互換、區段標題（`<戶籍資料>`）被當成資料、
/// 同一份資料重複三次等情況。
///
/// WebForms 控制項的 `name`（去掉命名容器 `A0207A:` 後的尾段）在頁面改版時
/// 比表格位置穩定得多，因此改為以 name 取值。
///
/// ## 敏感欄位
/// `txtIDNO`（身分證）、`txtPASSPORT_NO`（護照）、`txtRESIDENCE_NO`（居留證）、
/// `txtUNIFY_NO`（統一證號）**刻意不讀取**，模型也沒有對應欄位。
library;

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../../domain/entities/student_profile.dart';

/// 解析結果：資料本體 + 頭像 URL（尚未解析成絕對網址）。
class ParsedStudentProfile {
  const ParsedStudentProfile({required this.profile, this.photoSource});

  final StudentProfile profile;
  final String? photoSource;
}

/// 從 A0207S 頁面 HTML 取出結構化個人資料。
ParsedStudentProfile parseStudentProfile(String html) {
  final doc = html_parser.parse(html);

  // 同名控制項會在頁面出現多次（唯讀與編輯表單），值相同。
  // 以「尾段 name」為 key，保留第一個非空值，避免後面的空值蓋掉實際資料。
  final values = <String, String>{};
  for (final control in doc.querySelectorAll('input,select,textarea')) {
    final name = control.attributes['name'] ?? '';
    if (name.isEmpty) continue;
    final key = name.split(':').last;
    if (key.isEmpty || values.containsKey(key)) continue;
    final value = switch (control.localName) {
      'select' => _selectedLabel(control),
      'textarea' => control.text.trim(),
      _ => (control.attributes['value'] ?? '').trim(),
    };
    if (value.isNotEmpty) values[key] = value;
  }

  String read(String key) => values[key] ?? '';

  final profile = StudentProfile(
    name: read('txtSTD_CNAME'),
    englishName: read('txtSTD_ENAME'),
    studentId: read('txtSTUDENT_ID'),
    gender: read('ddlSEX_M'),
    status: read('ddlNOW_M'),
    studentType: read('ddlSTDTP_M'),
    feeType: read('ddlFEE_NOW_M'),
    admissionDate: read('txtVRF_DT'),
    admissionRef: read('txtVRF_NO'),
    birthDate: read('txtBIRTH_DT'),
    nationality: read('ddlNATIONALITY_M'),
    email: read('txtEMAIL'),
    registeredZip: read('txtREG_ZIP'),
    registeredAddress: read('txtREG_ADDR'),
    registeredPhone: read('txtREG_TEL'),
    currentZip: read('txtNOW_ZIP'),
    currentAddress: read('txtNOW_ADDR'),
    currentPhone: read('txtNOW_TEL'),
    mobile: read('txtMOBILE_TEL'),
    emergencyName: read('txtURGENT_MAN'),
    emergencyPhone: read('txtURGENT_TEL').isEmpty
        ? read('txtURGENT_MOBILE')
        : read('txtURGENT_TEL'),
    emergencyAddress: read('txtURGENT_ADDR'),
    dormRoom: read('txtROOM'),
  );

  return ParsedStudentProfile(
    profile: profile,
    photoSource: doc.querySelector('#A0207A_imgSTD_PIC')?.attributes['src'],
  );
}

/// 取 `<select>` 目前選項的文字。
///
/// 實測：A0207S 的每個 select 都恰好有一個 `selected` option；
/// 仍保留「第一個非空選項」的後備，避免標記方式改變時整欄消失。
String _selectedLabel(Element select) {
  final options = select.querySelectorAll('option');
  final marked = select.querySelector('option[selected]');
  if (marked != null) {
    final text = marked.text.trim();
    if (text.isNotEmpty) return text;
  }
  for (final option in options) {
    final text = option.text.trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}
