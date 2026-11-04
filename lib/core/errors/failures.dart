/// 錯誤模型：Repository 層對上（domain/UI）回傳的失敗型別。
///
/// 對應 Phase 3 實測的學校系統各種回應樣態。
library;

sealed class Failure {
  const Failure({required this.message, this.cause});

  /// 顯示給使用者的訊息（繁體中文）。
  final String message;

  /// 原始例外（log 用，不顯示給使用者）。
  final Object? cause;

  @override
  String toString() => message;
}

/// 網路不可用 / DNS 失敗 / timeout。
class NetworkFailure extends Failure {
  NetworkFailure({super.cause}) : super(message: '無法連線到學校系統，請檢查網路狀態。');
}

/// 登入頁解析失敗（頁面結構不符預期 — 學校改版）。
class PageParseFailure extends Failure {
  PageParseFailure({super.cause}) : super(message: '學校系統出現未知的頁面結構，請稍後再試或回報。');
}

/// 驗證碼錯誤。
class CaptchaFailure extends Failure {
  CaptchaFailure({super.cause}) : super(message: '驗證碼不正確，請重新輸入。');
}

/// 帳號或密碼錯誤。
class CredentialFailure extends Failure {
  CredentialFailure({super.cause}) : super(message: '帳號或密碼不正確。');
}

/// 帳號被鎖（同一帳號單一 Session；非正常登出 → 鎖 5 分鐘）。
class AccountLockedFailure extends Failure {
  AccountLockedFailure({super.cause})
    : super(message: '帳號已被登入或遭鎖定，請先在別處登出，或稍候 5 分鐘再嘗試。');
}

/// Session 過期（145 bytes 殼頁樣態 / 轉回登入頁）。
class SessionExpiredFailure extends Failure {
  SessionExpiredFailure({super.cause}) : super(message: '登入已逾時，請重新登入。');
}

/// 伺服器錯誤（「執行結果出現異常」頁 / 5xx）。
class ServerFailure extends Failure {
  ServerFailure({required String detail, super.cause})
    : super(message: '學校系統回應異常：$detail');
}

/// 解析資料失敗（表格不存在 / 格式改變）。
class DataParseFailure extends Failure {
  DataParseFailure({String? detail, super.cause})
    : super(message: detail ?? '資料解析失敗，請稍後再試。');
}

/// 該功能在此版本尚未支援（保留下來給未實作的校務模組）。
class UnsupportedFailure extends Failure {
  UnsupportedFailure({required String detail, super.cause})
    : super(message: detail);
}

/// 未知失敗。
class UnknownFailure extends Failure {
  UnknownFailure({super.cause}) : super(message: '發生未預期的錯誤，請稍後再試。');
}
