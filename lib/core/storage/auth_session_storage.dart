/// 登入憑證安全儲存 — Android Keystore 保護（flutter_secure_storage）。
///
/// 僅保存最小必要資訊：`.PaAuth` cookie 值 + 學號（利於 UI 顯示）；
/// 密碼不儲存；僅保存必要的校務系統 Session 憑證與帳號。
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 儲存鍵值。
const String kAuthCookieKey = 'auth.paAuthCookie';
const String kAccountKey = 'auth.account';

class AuthSessionStorage {
  AuthSessionStorage(this._secure);

  final FlutterSecureStorage _secure;

  Future<void> saveSession({
    required String paAuthCookie,
    required String account,
  }) async {
    await _secure.write(key: kAuthCookieKey, value: paAuthCookie);
    await _secure.write(key: kAccountKey, value: account);
  }

  Future<String?> readAuthCookie() => _secure.read(key: kAuthCookieKey);

  Future<String?> readAccount() => _secure.read(key: kAccountKey);

  Future<void> clear() async {
    await _secure.delete(key: kAuthCookieKey);
    await _secure.delete(key: kAccountKey);
  }
}
