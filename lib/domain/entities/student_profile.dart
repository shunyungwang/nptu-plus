/// 學生個人資料（來源：A0207S 唯讀頁）— 強型別模型。
///
/// 設計原則：
/// - 只保留「實際存在且對使用者有意義」的欄位，不建立校務系統沒有的資料。
/// - 身分證字號、護照號碼、居留證號碼、統一證號 **不進入模型**，
///   在解析層就不讀取，避免任何 UI 或快取意外持有敏感識別碼。
/// - 原始值保留校務系統代碼（如 `1.在學`），由 getter 轉成可讀文字，
///   讓 UI 不需要自己處理字串格式。
library;

import 'dart:typed_data';

class StudentProfile {
  const StudentProfile({
    this.name = '',
    this.englishName = '',
    this.studentId = '',
    this.gender = '',
    this.status = '',
    this.studentType = '',
    this.feeType = '',
    this.admissionDate = '',
    this.admissionRef = '',
    this.birthDate = '',
    this.nationality = '',
    this.email = '',
    this.registeredZip = '',
    this.registeredAddress = '',
    this.registeredPhone = '',
    this.currentZip = '',
    this.currentAddress = '',
    this.currentPhone = '',
    this.mobile = '',
    this.emergencyName = '',
    this.emergencyPhone = '',
    this.emergencyAddress = '',
    this.dormRoom = '',
    this.photo,
  });

  /// 中文姓名（A0207A:txtSTD_CNAME）。
  final String name;

  /// 英文姓名（A0207A:txtSTD_ENAME）。
  final String englishName;

  /// 學號（A0207A:txtSTUDENT_ID）。
  final String studentId;

  /// 性別原始值，例如 `1.男`。
  final String gender;

  /// 學籍目前狀態原始值，例如 `1.在學`。
  final String status;

  /// 學生身分別原始值，例如 `01.一般生`。
  final String studentType;

  /// 費用別原始值，例如 `2.自費`。
  final String feeType;

  /// 核准入學日期（民國），例如 `1150901`。
  final String admissionDate;

  /// 入學文號（長文字）。
  final String admissionRef;

  /// 出生日期（民國），例如 `930226`。
  final String birthDate;

  final String nationality;

  final String email;

  final String registeredZip;
  final String registeredAddress;
  final String registeredPhone;

  final String currentZip;
  final String currentAddress;
  final String currentPhone;
  final String mobile;

  final String emergencyName;
  final String emergencyPhone;
  final String emergencyAddress;

  final String dormRoom;

  /// 大頭照 bytes（A0207A_imgSTD_PIC）；校務系統未提供時為 null。
  final Uint8List? photo;

  /// 是否完全沒有可用資料（用來區分「載入成功但沒資料」與正常狀態）。
  bool get isEmpty =>
      name.isEmpty &&
      studentId.isEmpty &&
      email.isEmpty &&
      status.isEmpty &&
      mobile.isEmpty &&
      currentAddress.isEmpty;

  String get displayName => name.isEmpty ? '未提供姓名' : name;

  /// 去掉校務系統的代碼前綴：`1.在學` → `在學`、`01.一般生` → `一般生`。
  String get statusLabel => _withoutCode(status);
  String get studentTypeLabel => _withoutCode(studentType);
  String get feeTypeLabel => _withoutCode(feeType);
  String get genderLabel => _withoutCode(gender);

  /// `1150901` → `115/09`。
  String get admissionLabel => _rocYearMonth(admissionDate);

  /// `930226` → `93/02/26`；`1000226` → `100/02/26`。
  String get birthDateLabel => _rocDate(birthDate);

  /// 回傳帶入頭像的新物件（模型本身不可變）。
  StudentProfile withPhoto(Uint8List? photo) => StudentProfile(
    name: name,
    englishName: englishName,
    studentId: studentId,
    gender: gender,
    status: status,
    studentType: studentType,
    feeType: feeType,
    admissionDate: admissionDate,
    admissionRef: admissionRef,
    birthDate: birthDate,
    nationality: nationality,
    email: email,
    registeredZip: registeredZip,
    registeredAddress: registeredAddress,
    registeredPhone: registeredPhone,
    currentZip: currentZip,
    currentAddress: currentAddress,
    currentPhone: currentPhone,
    mobile: mobile,
    emergencyName: emergencyName,
    emergencyPhone: emergencyPhone,
    emergencyAddress: emergencyAddress,
    dormRoom: dormRoom,
    photo: photo ?? this.photo,
  );
}

/// 去除 `1.` / `01.` / `A.` 這類代碼前綴。
String _withoutCode(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  return trimmed.replaceFirst(RegExp(r'^[0-9A-Za-z]{1,2}\.\s*'), '');
}

/// 民國 `YYYMMDD` → `YYY/MM`。
String _rocYearMonth(String value) {
  final digits = value.trim();
  if (!RegExp(r'^\d{7}$').hasMatch(digits)) return digits;
  return '${digits.substring(0, 3)}/${digits.substring(3, 5)}';
}

/// 民國日期 → `YY/MM/DD` 或 `YYY/MM/DD`。
String _rocDate(String value) {
  final digits = value.trim();
  if (!RegExp(r'^\d{6}$').hasMatch(digits) &&
      !RegExp(r'^\d{7}$').hasMatch(digits)) {
    return digits;
  }
  final yearLength = digits.length - 4;
  return '${digits.substring(0, yearLength)}/'
      '${digits.substring(yearLength, yearLength + 2)}/'
      '${digits.substring(yearLength + 2)}';
}
