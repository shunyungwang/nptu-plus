/// 全域登入狀態：帳號、登入狀態與「Session 世代」。
///
/// 為什麼需要 Session 世代（generation）？
/// Riverpod 的 `FutureProvider` 會快取上一次結果；若登出／換帳號時只改登入狀態，
/// 舊帳號的課表、成績、個資仍留在快取中，就會出现「B 帳號看到 A 資料」。
/// 因此所有帳號資料 Provider 都 `watch` 這個世代值：
/// 每次登入、登出、Session 逾期都 +1，相關 Provider 立刻作廢並以新帳號重取。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/providers.dart';
import '../domain/entities/auth_session.dart';

/// SharedPreferences 實例（main.dart 啟動時注入）。
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('main.dart 必須 override 注入 SharedPreferences');
});

/// 登入狀態由實際校務系統認證結果驅動。
enum AuthStatus { loggedOut, loggedIn }

final authStatusProvider = NotifierProvider<AuthStatusController, AuthStatus>(
  AuthStatusController.new,
);

/// 目前登入的帳號（僅學號，不含密碼）；未登入為 null。
final currentAccountProvider =
    NotifierProvider<CurrentAccountController, String?>(
      CurrentAccountController.new,
    );

/// Session 世代：換帳號時 +1，用來作廢所有帳號相關快取。
final sessionGenerationProvider =
    NotifierProvider<SessionGenerationController, int>(
      SessionGenerationController.new,
    );

class CurrentAccountController extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? account) {
    final trimmed = account?.trim() ?? '';
    state = trimmed.isEmpty ? null : trimmed;
  }
}

class SessionGenerationController extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

class AuthStatusController extends Notifier<AuthStatus> {
  @override
  AuthStatus build() => AuthStatus.loggedOut;

  Future<LoginPreparation> prepareLogin() =>
      ref.read(authRepositoryProvider).prepareLogin();

  Future<void> signIn({
    required String account,
    required String password,
    required String captcha,
    required LoginPreparation preparation,
  }) async {
    // 先中止上一個帳號仍在飛的請求，避免舊回應在切換後才回來。
    ref.read(sessionRequestTrackerProvider).cancelAll('sign-in');
    await ref
        .read(authRepositoryProvider)
        .signIn(
          account: account,
          password: password,
          captcha: captcha,
          preparation: preparation,
        );
    _activate(account);
  }

  /// 冷啟動還原已保存的 Session（main.dart 呼叫）。
  void restore({required String account}) => _activate(account);

  /// 任何請求回報 Session 逾期時呼叫。
  void sessionExpired() {
    ref.read(sessionRequestTrackerProvider).cancelAll('session-expired');
    _deactivate();
  }

  Future<bool> signOut() async {
    ref.read(sessionRequestTrackerProvider).cancelAll('sign-out');
    try {
      return await ref.read(authRepositoryProvider).signOut();
    } finally {
      // 即使伺服器端登出失敗，也一定要清掉本機帳號狀態與快取。
      _deactivate();
    }
  }

  /// 建立新帳號的 Session：先切換帳號與世代，再切換登入狀態，
  /// 讓畫面重建時讀到的一定是新帳號的資料。
  void _activate(String account) {
    ref.read(currentAccountProvider.notifier).set(account);
    ref.read(sessionGenerationProvider.notifier).bump();
    state = AuthStatus.loggedIn;
  }

  void _deactivate() {
    ref.read(currentAccountProvider.notifier).set(null);
    ref.read(sessionGenerationProvider.notifier).bump();
    state = AuthStatus.loggedOut;
  }
}
