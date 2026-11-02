/// WebForms HTML 解析器（Phase 1-3 實測結構）。
library;

import 'package:html/parser.dart' as html_parser;

/// 解析頁面中所有 `<input type="hidden">` 的 name/value。
///
/// ## 注意事項
/// Phase 3 實測確認：VIEWSTATE 等欄位的 `name` 與 `value` 中間可能夾其他屬性
/// (如 `id`)，不可用簡單的字串掃描，必須用真正的 HTML 解析器。
Map<String, String> extractHiddenFields(String html) {
  final doc = html_parser.parse(html);
  final result = <String, String>{};
  for (final el in doc.querySelectorAll('input[type="hidden"]')) {
    final name = el.attributes['name'];
    if (name == null || name.isEmpty) continue;
    result[name] = (el.attributes['value'] ?? '').trim();
  }
  return result;
}

/// 擷取回應中的所有 JavaScript alert 文字（含解去 \\ 與 &quot; 轉義）。
///
/// Phase 3 實測樣態：
/// - 驗證碼錯誤: `alert("驗證碼不符!!")`
/// - 未登入: `alert('未檢測到您的登入資訊，請重新登入!!')`
List<String> extractAlerts(String html) {
  final alerts = <String>[];
  final re = RegExp("alert\\(['\"]([^'\"]*)['\"]\\)");
  for (final m in re.allMatches(html)) {
    alerts.add(m.group(1)!.replaceAll(r"\'", "'"));
  }
  return alerts;
}

/// 判斷是否為轉址殼頁（登入過期/登出後殼頁）。
///
/// Phase 3 實測樣態:
/// - 登入過期: `<script>top.location.href='...default.htm';</script>` 等極短殼頁。
bool isRedirectShell(String html) {
  final t = html.trim();
  if (t.length > 512) return false;
  if (!t.contains('top.location.href') && !t.contains('location.href')) {
    return false;
  }
  // 必須導回登入頁/入口，且不含「登入使用的表單結構」。
  return t.contains('default.htm') ||
      t.contains('Secure/default.aspx') ||
      t.contains('未檢測到您的登入資訊');
}

/// 判斷回應是否為驗證碼不符（重新回傳完整登入頁 + alert）。
bool isCaptchaError(String html) {
  return html.contains('驗證碼不符') ||
      html.contains('驗證碼錯誤');
}

/// 判斷伺服器「執行結果出現異常」頁。
bool isServerErrorPage(String html) {
  return html.contains('執行結果出現異常');
}

/// 判斷是否為登入成功的轉址 script：
/// `<script>top.location.href='../Message/default.aspx';</script>`
bool isLoginSuccessRedirect(String html) {
  final t = html.trim();
  return t.length < 512 &&
      t.contains('location.href') &&
      t.contains('Message/default.aspx');
}
