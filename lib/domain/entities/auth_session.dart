/// Auth Domain 實體。
library;

/// 登入前置資料（Phase 3 實測結構）。
class LoginPreparation {
  const LoginPreparation({
    required this.hiddenFields,
    required this.captchaBytes,
  });

  /// 登入頁所有 `<input type="hidden">`（VIEWSTATE/EVENTVALIDATION/...）。
  final Map<String, String> hiddenFields;

  /// 圖形驗證碼 JPEG bytes（95x35，4 位數字）。
  final List<int> captchaBytes;
}

/// 登入狀態。
enum AuthStatusDomain { unauthenticated, authenticated }
