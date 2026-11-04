/// Auth Repository 實作（data 層）。
library;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/failures.dart';
import '../../core/storage/auth_session_storage.dart';
import '../parsers/webforms_parsers.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/webforms_auth_api.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(
    this._api, {
    required CookieJar cookieJar,
    required AuthSessionStorage storage,
  }) : _jar = cookieJar,
       _storage = storage;

  final WebFormsAuthApi _api;
  final CookieJar _jar;
  final AuthSessionStorage _storage;

  int _captchaNonce = 0;

  static Uri get _baseUri => Uri.parse(AppConstants.baseUrl);

  @override
  Future<LoginPreparation> prepareLogin() {
    _captchaNonce++;
    return _api.fetchLoginPreparation(nonce: _captchaNonce);
  }

  @override
  Future<bool> signIn({
    required String account,
    required String password,
    required String captcha,
    required LoginPreparation preparation,
  }) async {
    final outcome = await _api.login(
      account: account,
      password: password,
      captcha: captcha,
      hiddenFields: preparation.hiddenFields,
    );
    switch (outcome) {
      case LoginSuccess():
        final authCookie = await _readAuthCookieFromJar();
        if (authCookie == null) {
          // 轉址 script 存在但沒拿到 .PaAuth → 視為異常。
          throw ServerFailure(detail: '登入未核發憑證');
        }
        await _storage.saveSession(account: account, paAuthCookie: authCookie);
        return true;
      case LoginCaptchaError():
        throw CaptchaFailure();
      case LoginRejected(:final alertText):
        throw _mapRejected(alertText);
    }
  }

  @override
  Future<bool> restoreSession() async {
    final jarHasAuth = await _readAuthCookieFromJar() != null;
    final stored = await _storage.readAuthCookie();
    if (!jarHasAuth && stored == null) return false;
    if (!jarHasAuth && stored != null) {
      // 重新注入上次的 .PaAuth（Cookie jar 冷啟動為空）。
      final cookie = Cookie.fromSetCookieValue(
        '${AppConstants.kAuthCookie}=$stored',
      );
      await _jar.saveFromResponse(_baseUri, [cookie]);
    }
    // 用需要授權的頁面驗證是否仍有效（Phase 3 樣態：殼頁 = 已過期）。
    try {
      final page = await _api.getPlainText(AppConstants.homePagePath);
      if (isRedirectShell(page)) {
        await _clearSession();
        return false;
      }
      return page.contains('LogOut') || page.contains('MenuTree');
    } catch (error) {
      if (error is DioException && error.error is SessionExpiredFailure) {
        await _clearSession();
        return false;
      }
      // 網路不可用：保守視為已還原（離線狀態），由後續請求判斷過期。
      return true;
    }
  }

  @override
  Future<bool> signOut() async {
    try {
      return await _api.logout();
    } finally {
      await _clearSession();
    }
  }

  Future<void> _clearSession() async {
    await _storage.clear();
    await _jar.delete(_baseUri, true);
  }

  Future<String?> _readAuthCookieFromJar() async {
    final cookies = await _jar.loadForRequest(_baseUri);
    for (final c in cookies) {
      if (c.name == AppConstants.kAuthCookie) return c.value;
    }
    return null;
  }

  Failure _mapRejected(String alertText) {
    if (alertText.contains('鎖') || alertText.contains('已登入')) {
      return AccountLockedFailure();
    }
    if (alertText.contains('驗證碼')) return CaptchaFailure();
    return CredentialFailure();
  }
}

/// 供測試/除錯用：把 jar cookie 序列化為可讀名稱清單（不含值）。
String debugCookieNames(List<String> rawCookies) {
  final names = <String>[];
  for (final raw in rawCookies) {
    final i = raw.indexOf('=');
    if (i > 0) names.add(raw.substring(0, i));
  }
  return names.join(',');
}

/// 帳號顯示的最後幾位（409 遮蔽用）。
String maskAccount(String account) {
  if (account.length <= 4) return account;
  final head = account.substring(0, account.length - 4);
  return '$head****';
}
