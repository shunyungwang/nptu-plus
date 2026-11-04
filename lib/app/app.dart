/// App 根 Widget 與 Router Provider：Material 3 + Light/Dark/System 主題。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/theme_provider.dart';
import 'providers.dart';
import 'router.dart';
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

/// 全域 Router：以 [refreshListenable] 反映登入狀態變化。
final routerProvider = Provider<GoRouter>((ref) {
  // 監聽登入狀態；變化時觸發 GoRouter 重新評估 redirect。
  final notifier = ValueNotifier(0);
  ref.listen(authStatusProvider, (_, _) => notifier.value++);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    refreshListenable: notifier,
    initialLocation: kRouteDashboard,
    redirect: (context, state) {
      final logged = ref.read(authStatusProvider) == AuthStatus.loggedIn;
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
});

class NptuCampusApp extends ConsumerWidget {
  const NptuCampusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'NPTU 校務系統',
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(routerProvider),
      themeMode: themeMode,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
    );
  }
}
