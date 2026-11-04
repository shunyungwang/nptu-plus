/// Shared remote data providers used by the student feature screens.
///
/// 資料來源只有一個：校務系統 webap（WebForms / HTML 解析）。
///
/// 每個資料 Provider 都 `watch` [sessionGenerationProvider] 與
/// [currentAccountProvider]：
/// - 換帳號時世代 +1 → 舊快取立刻作廢，不會把 A 的課表／成績留在畫面上。
/// - 舊帳號晚到的回應只會寫回已被丟棄的舊 Provider 實例，無法覆蓋新帳號資料。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../core/network/providers.dart';
import '../data/datasources/student_data_api.dart';
import '../data/datasources/webforms_leave_api.dart';
import '../data/datasources/webforms_student_api.dart';

/// 學生資料 API（每個登入世代一個實例）。
final studentDataApiProvider = Provider<StudentDataApi>((ref) {
  _watchSession(ref);
  return WebFormsStudentApi(
    ref.watch(dioProvider),
    onSessionExpired: () =>
        ref.read(authStatusProvider.notifier).sessionExpired(),
  );
});

/// 請假 API（表單解析與送出）。
final leaveDataApiProvider = Provider<WebFormsLeaveApi>((ref) {
  _watchSession(ref);
  return WebFormsLeaveApi(
    ref.watch(dioProvider),
    onSessionExpired: () =>
        ref.read(authStatusProvider.notifier).sessionExpired(),
  );
});

final announcementsProvider = FutureProvider((ref) {
  _watchSession(ref);
  return ref.watch(studentDataApiProvider).announcements();
});

final coursesProvider = FutureProvider((ref) {
  _watchSession(ref);
  return ref.watch(studentDataApiProvider).courses();
});

final profileProvider = FutureProvider((ref) {
  _watchSession(ref);
  return ref.watch(studentDataApiProvider).profile();
});

final gradesProvider = FutureProvider.family((ref, String? semester) {
  _watchSession(ref);
  return ref.watch(studentDataApiProvider).grades(semester: semester);
});

final attendanceProvider = FutureProvider.family((ref, String? semester) {
  _watchSession(ref);
  return ref.watch(studentDataApiProvider).attendance(semester: semester);
});

final leavePageProvider = FutureProvider((ref) {
  _watchSession(ref);
  return ref.watch(leaveDataApiProvider).load();
});

/// 帳號相關快取的唯一失效條件：Session 世代或登入帳號改變。
void _watchSession(Ref ref) {
  ref.watch(sessionGenerationProvider);
  ref.watch(currentAccountProvider);
}
