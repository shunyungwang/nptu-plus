/// Auth Repository 抽象介面（domain 層，data 層實作）。
library;

import '../entities/auth_session.dart';

abstract class AuthRepository {
  /// 取得登入前置資料（登入頁隱藏欄位 + 圖形驗證碼）。
  Future<LoginPreparation> prepareLogin();

  /// 登入（WebForms 握手流程）。
  /// 成功回 true；失敗擲回對應 [Failure]。
  Future<bool> signIn({
    required String account,
    required String password,
    required String captcha,
    required LoginPreparation preparation,
  });

  /// 還原已保存的登入憑證（App 冷啟動時呼叫）。
  Future<bool> restoreSession();

  /// 登出並清除本機憑證；回傳伺服器端是否確認登出。
  Future<bool> signOut();
}
