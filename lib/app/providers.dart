/// 全域 Provider：主題模式與登入狀態。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/storage/theme_storage.dart';
import '../domain/entities/auth_session.dart';
import '../core/network/providers.dart';

/// SharedPreferences 實例（main.dart 啟動時注入）。
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('main.dart 必須 override 注入 SharedPreferences');
});

/// 主題模式（Light / Dark / System），持久化到 SharedPreferences。
final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => loadThemeMode(ref.read(sharedPreferencesProvider));

  void setMode(ThemeMode mode) {
    state = mode;
    saveThemeMode(ref.read(sharedPreferencesProvider), mode);
  }
}

/// 登入狀態由實際校務系統認證結果驅動。
enum AuthStatus { loggedOut, loggedIn }

final authStatusProvider = NotifierProvider<AuthStatusController, AuthStatus>(
  AuthStatusController.new,
);

class AuthStatusController extends Notifier<AuthStatus> {
  @override
  AuthStatus build() => AuthStatus.loggedOut;

  void loggedIn() => state = AuthStatus.loggedIn;

  void sessionExpired() => state = AuthStatus.loggedOut;

  Future<LoginPreparation> loadLoginPreparation() =>
      ref.read(authRepositoryProvider).loadLoginPreparation();

  Future<void> signIn({
    required String account,
    required String password,
    required String captcha,
    required LoginPreparation preparation,
  }) async {
    await ref.read(authRepositoryProvider).signIn(
      account: account,
      password: password,
      captcha: captcha,
      preparation: preparation,
    );
    state = AuthStatus.loggedIn;
  }

  Future<bool> signOut() async {
    try {
      return await ref.read(authRepositoryProvider).signOut();
    } finally {
      // Always leave the authenticated area even if the server logout request fails.
      state = AuthStatus.loggedOut;
    }
  }
}
