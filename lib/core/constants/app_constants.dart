/// 全域常數：所有對接學校系統的基礎資訊集中在這裡。
/// 來源依據：docs/API_ANALYSIS.md / docs/API_ENDPOINTS.md（Phase 1-3 實測）。
library;

class AppConstants {
  const AppConstants._();

  /// 校務系統基底網址（HTTPS；伺服器端強制 HSTS）。
  static const String baseUrl = 'https://webap.nptu.edu.tw';

  /// 登入頁。
  static const String loginPagePath = '/Web/Secure/default.aspx?sIndex=2';

  /// 圖形驗證碼（JPEG 95x35，4 位數字，綁定 Session）。
  static const String captchaImagePath = '/Web/Modules/CaptchaCreator.aspx';

  /// 語音驗證碼。
  static const String captchaVoicePath =
      '/Web/Modules/CaptchaVoiceHandler.ashx';

  /// 登入後框架首頁（含公告 HOTNEWS_dgData 表格）。
  static const String homePagePath = '/Web/Message/default.aspx';

  /// 主選單。
  static const String menuTreePath = '/Web/Message/MenuTree.aspx';

  /// 正式登出（POST CommonHeader:ibtLogOut）。
  static const String mainPagePath = '/Web/Message/Main.aspx';

  // ---- Session / Cookie 名稱（Phase 1 實測）----
  /// 未驗證狀態即核發的 ASP.NET 自訂 Session。
  static const String kSessionCookie = 'UNIVWeb_SessionId';

  /// 登入成功後核發的持久性登入憑證（不透明字串）。
  static const String kAuthCookie = '.PaAuth';

  /// F5 BIG-IP 流量管理 Cookie（每回應重發，需跟隨最新值）。
  static const String kF5Cookie = 'TS01f68d9a';

  // ---- 判斷樣態（Phase 3 實測大小特徵）----
  /// 「未檢測到您的登入資訊」殼頁 ≈145 bytes（登入過期訊號）。
  static const int loginExpiredShellBytes = 145;

  /// 登出後受保護頁的殼頁 ≈177 bytes。
  static const int loggedOutShellBytes = 177;

  /// 登入頁正常渲染大小 ≈23 KB。
  static const int loginPageBytes = 23387;
}
