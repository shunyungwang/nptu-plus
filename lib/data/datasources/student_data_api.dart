/// 學生資料來源的共同介面。
///
/// 唯一實作是 [WebFormsStudentApi]：ASP.NET WebForms 校務系統（HTML 解析）。
///
/// UI 只依賴這個介面，不直接接觸任何 HTTP 或 HTML。
library;

import '../../domain/entities/semester_table.dart';
import '../../domain/entities/student_profile.dart';

abstract interface class StudentDataApi {
  Future<List<Map<String, String>>> announcements();

  Future<List<Map<String, String>>> courses();

  Future<StudentProfile> profile();

  Future<SemesterTable> grades({String? semester});

  Future<SemesterTable> attendance({String? semester});
}
