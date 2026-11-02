/// 統一 HTTP Client（Dio + CookieJar）— 學校系統 WebForms 串接的基礎。
///
/// Shared Dio client with persistent cookies and expired-session detection.
library;

import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import '../constants/app_constants.dart';
import '../errors/failures.dart';

/// 初始化好的 [Dio] 實例。
///
/// - baseUrl 固定為校務系統。
/// - CookieJar 負責 `UNIVWeb_SessionId` / `.PaAuth` / `TS01f68d9a` 的持續性。
Dio buildWebFormsDio({required CookieJar cookieJar}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      followRedirects: false,
      // 伺服器會以 200 + JS 轉址回應；關閉自動轉址利於樣態判斷。
      headers: {
        'Accept': 'text/html,application/json;q=0.9,*/*;q=0.8',
        'Accept-Language': 'zh-TW,zh;q=0.9,en;q=0.8',
      },
      // 遵循學校的 Content-Type（僅 application/x-www-form-urlencoded）。
    ),
  );
  dio.interceptors.add(_TolerantCookieManager(cookieJar));
  dio.interceptors.add(_LoginExpiredInterceptor());
  return dio;
}

/// The school's login response includes a malformed `Set-Cookie` header
/// (`Secure;HttpOnly; ...`) alongside valid session cookies. Keep valid cookies
/// and skip only malformed entries so they cannot fail an otherwise good HTTP
/// response.
class _TolerantCookieManager extends CookieManager {
  _TolerantCookieManager(super.cookieJar);

  @override
  Future<void> saveCookies(Response response) async {
    final rawCookies = response.headers['set-cookie'];
    if (rawCookies == null || rawCookies.isEmpty) {
      return super.saveCookies(response);
    }
    final validCookies = <String>[];
    for (final raw in rawCookies) {
      try {
        Cookie.fromSetCookieValue(raw);
        validCookies.add(raw);
      } on FormatException {
        // Ignore this malformed header, but continue storing other cookies.
      }
    }
    response.headers.set('set-cookie', validCookies);
    await super.saveCookies(response);
  }
}

/// 偵測 Phase 3 記錄的「登入過期」殼頁樣態：
/// 回應極小且包含轉回 `/Web/default.htm` 或登入頁的 script。
class _LoginExpiredInterceptor extends Interceptor {
  static final RegExp _redirectStub = RegExp(
    r"default\.htm|Secure/default\.aspx",
    multiLine: true,
  );

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final data = response.data;
    final path = response.requestOptions.uri.path.toLowerCase();
    final isPublicAuthPage = path == Uri.parse(AppConstants.loginPagePath).path.toLowerCase() ||
        path == AppConstants.captchaImagePath.toLowerCase();
    if (!isPublicAuthPage && data is String && data.length < 512 &&
        _redirectStub.hasMatch(data)) {
      handler.reject(DioException(
        requestOptions: response.requestOptions,
        response: response,
        error: SessionExpiredFailure(),
        message: '校務系統登入已逾時',
      ));
      return;
    }
    handler.next(response);
  }
}
