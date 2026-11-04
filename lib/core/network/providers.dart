/// Network 層 Provider：CookieJar、Dio、AuthApi 與 Repository。
library;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../data/datasources/webforms_auth_api.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../storage/auth_session_storage.dart';
import 'webforms_client.dart';

/// CookieJar（main.dart 以檔案路徑 override 注入）。
final cookieJarProvider = Provider<CookieJar>((ref) {
  throw UnimplementedError('main.dart 必須 override 注入 PersistCookieJar');
});

/// 安全儲存。
final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

/// 進行中請求的追蹤器：換帳號時可整批取消，避免舊請求回寫新帳號畫面。
final sessionRequestTrackerProvider = Provider<SessionRequestTracker>(
  (ref) => SessionRequestTracker(),
);

/// Http Dio 建置（依 CookieJar + 請求追蹤器）。
final dioProvider = Provider<Dio>(
  (ref) => buildWebFormsDio(
    cookieJar: ref.watch(cookieJarProvider),
    tracker: ref.watch(sessionRequestTrackerProvider),
  ),
);

/// 學校 WebForms 認證 API。
final authApiProvider = Provider<WebFormsAuthApi>(
  (ref) => WebFormsAuthApi(ref.watch(dioProvider)),
);

/// Session 安全儲存。
final authSessionStorageProvider = Provider<AuthSessionStorage>(
  (ref) => AuthSessionStorage(ref.watch(secureStorageProvider)),
);

/// 校務系統 Auth Repository（唯一登入流程：webap WebForms + 圖形驗證碼）。
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    ref.watch(authApiProvider),
    cookieJar: ref.watch(cookieJarProvider),
    storage: ref.watch(authSessionStorageProvider),
  ),
);
