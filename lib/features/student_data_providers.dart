/// Shared remote data providers used by the student feature screens.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../core/network/providers.dart';
import '../data/datasources/webforms_student_api.dart';
import '../data/datasources/webforms_leave_api.dart';

final studentDataApiProvider = Provider((ref) => WebFormsStudentApi(
  ref.watch(dioProvider),
  onSessionExpired: () => ref.read(authStatusProvider.notifier).sessionExpired(),
));
final leaveDataApiProvider = Provider((ref) => WebFormsLeaveApi(
  ref.watch(dioProvider),
  onSessionExpired: () => ref.read(authStatusProvider.notifier).sessionExpired(),
));

final announcementsProvider = FutureProvider((ref) =>
    ref.watch(studentDataApiProvider).announcements());
final coursesProvider = FutureProvider((ref) =>
    ref.watch(studentDataApiProvider).courses());
final profileProvider = FutureProvider((ref) =>
    ref.watch(studentDataApiProvider).profile());
final gradesProvider = FutureProvider.family<SemesterTable, String?>((ref, semester) =>
    ref.watch(studentDataApiProvider).grades(semester: semester));
final attendanceProvider = FutureProvider.family<SemesterTable, String?>((ref, semester) =>
    ref.watch(studentDataApiProvider).attendance(semester: semester));
final leavePageProvider = FutureProvider((ref) => ref.watch(leaveDataApiProvider).load());
