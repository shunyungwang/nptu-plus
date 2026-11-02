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

/// Http Dio 建置（依 CookieJar）。
final dioProvider = Provider<Dio>(
  (ref) => buildWebFormsDio(cookieJar: ref.watch(cookieJarProvider)),
);

/// 學校 WebForms 認證 API。
final authApiProvider = Provider<WebFormsAuthApi>(
  (ref) => WebFormsAuthApi(ref.watch(dioProvider)),
);

/// Session 安全儲存。
final authSessionStorageProvider = Provider<AuthSessionStorage>(
  (ref) => AuthSessionStorage(ref.watch(secureStorageProvider)),
);

/// Auth Repository（唯一入口）。
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    ref.watch(authApiProvider),
    cookieJar: ref.watch(cookieJarProvider),
    storage: ref.watch(authSessionStorageProvider),
  ),
);
