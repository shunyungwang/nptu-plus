/// GoRouter 路由設定。
///
/// 底部導航使用 [StatefulShellRoute]（各分頁保留狀態、切換零重建），
/// 「更多」類頁面為獨立路由。
library;

import 'package:go_router/go_router.dart';

import '../features/announcements/announcements_page.dart';
import '../features/attendance/attendance_page.dart';
import '../features/auth/login_page.dart';
import '../features/course_selection/course_selection_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/grades/grades_page.dart';
import '../features/leave/leave_application_page.dart';
import '../features/more/more_page.dart';
import '../features/profile/profile_page.dart';
import '../features/settings/settings_page.dart';
import '../features/shell/main_shell.dart';
import '../features/timetable/timetable_page.dart';

const String kRouteLogin = '/login';
const String kRouteDashboard = '/dashboard';
const String kRouteTimetable = '/timetable';
const String kRouteGrades = '/grades';
const String kRouteAnnouncements = '/announcements';
const String kRouteMore = '/more';
const String kRouteCourseSelection = '/course-selection';
const String kRouteAttendance = '/attendance';
const String kRouteLeaveApplication = '/leave-application';
const String kRouteProfile = '/profile';
const String kRouteSettings = '/settings';

/// 建立路由（登入狀態 getter 用於 redirect）。
GoRouter buildRouter({required bool Function() isLoggedIn}) {
  return GoRouter(
    initialLocation: kRouteDashboard,
    redirect: (context, state) {
      final logged = isLoggedIn();
      final isLogin = state.uri.path == kRouteLogin;
      if (!logged && !isLogin) return kRouteLogin;
      if (logged && isLogin) return kRouteDashboard;
      return null;
    },
    routes: [
      GoRoute(
        path: kRouteLogin,
        builder: (context, state) => const LoginPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: kRouteDashboard,
                builder: (_, _) => const DashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: kRouteTimetable,
                builder: (_, _) => const TimetablePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: kRouteGrades,
                builder: (_, _) => const GradesPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: kRouteAnnouncements,
                builder: (_, _) => const AnnouncementsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: kRouteMore, builder: (_, _) => const MorePage()),
            ],
          ),
        ],
      ),
      GoRoute(
        path: kRouteCourseSelection,
        builder: (_, _) => const CourseSelectionPage(),
      ),
      GoRoute(
        path: kRouteAttendance,
        builder: (_, _) => const AttendancePage(),
      ),
      GoRoute(
        path: kRouteLeaveApplication,
        builder: (_, _) => const LeaveApplicationPage(),
      ),
      GoRoute(path: kRouteProfile, builder: (_, _) => const ProfilePage()),
      GoRoute(path: kRouteSettings, builder: (_, _) => const SettingsPage()),
    ],
  );
}
