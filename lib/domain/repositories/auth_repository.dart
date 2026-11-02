/// Auth Repository 抽象介面（domain 層，data 層實作）。
library;

import '../entities/auth_session.dart';

abstract class AuthRepository {
  /// 取得登入前置資料：登入頁隱藏欄位 + 當前 Session 綁定的驗證碼圖。
  Future<LoginPreparation> loadLoginPreparation();

  /// 登入（內部含完整 WebForms 握手）。
  /// 成功回 true；失敗擲回對應 [Failure]。
  Future<bool> signIn({
    required String account,
    required String password,
    required String captcha,
    required LoginPreparation preparation,
  });

  /// 還原已保存的登入憑證（App 冷啟動時呼叫）；
  /// 回傳是否已重建可用的登入 Session。
  Future<bool> restoreSession();

  /// 真實登出：POST `CommonHeader:ibtLogOut` + 清空憑證儲存。
  Future<bool> signOut();
}
