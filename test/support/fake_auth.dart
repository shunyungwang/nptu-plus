// 測試用 Auth Repository：不連線校務系統。
import 'dart:convert';

import 'package:nptu_campus/domain/entities/auth_session.dart';
import 'package:nptu_campus/domain/repositories/auth_repository.dart';

/// 1×1 透明 PNG，讓登入頁的驗證碼區塊在截圖中有實際圖像。
final List<int> kTinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.signInSucceeds = true, this.serverLogout = true});

  final bool signInSucceeds;
  final bool serverLogout;

  /// 記錄每次登入的帳號，方便驗證流程。
  final List<String> signedInAccounts = <String>[];
  int prepareCalls = 0;

  @override
  Future<LoginPreparation> prepareLogin() async {
    prepareCalls++;
    return LoginPreparation(
      hiddenFields: const {'__VIEWSTATE': 'fake'},
      captchaBytes: kTinyPng,
    );
  }

  @override
  Future<bool> signIn({
    required String account,
    required String password,
    required String captcha,
    required LoginPreparation preparation,
  }) async {
    signedInAccounts.add(account);
    return signInSucceeds;
  }

  @override
  Future<bool> restoreSession() async => false;

  @override
  Future<bool> signOut() async => serverLogout;
}
