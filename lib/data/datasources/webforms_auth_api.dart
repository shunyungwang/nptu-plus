/// 學校 WebForms 認證 API 資料源（Phase 1/3 實測結構）。
///
/// 實測樣態對照：
/// - 登入頁 `GET /Web/Secure/default.aspx?sIndex=2`（核發 `UNIVWeb_SessionId`）
/// - 驗證碼 `GET /Web/Modules/CaptchaCreator.aspx`（GET，綁 Session，4 位數字）
/// - 登入 `POST /Web/Secure/default.aspx?sIndex=2`
///   → 成功：200 + 極短轉址 script + `Set-Cookie: .PaAuth`
///   → 驗證碼錯：重新渲染整頁登入表單 + `alert("驗證碼不符!!")`
/// - 登出：任一含 CommonHeader 頁面 → `POST CommonHeader:ibtLogOut.x/y`
library;

import 'package:dio/dio.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/auth_session.dart';
import '../../core/errors/failures.dart';
import '../parsers/webforms_parsers.dart';

/// 登入回應樣態。
sealed class LoginOutcome {
  const LoginOutcome();
}

/// 登入成功（轉址 script；`.PaAuth` 已被 CookieManager 收進 jar）。
class LoginSuccess extends LoginOutcome {
  const LoginSuccess();
}

/// 驗證碼錯誤（伺服器已重發新頁面，需重新取驗證碼）。
class LoginCaptchaError extends LoginOutcome {
  const LoginCaptchaError();
}

/// 帳密錯誤或登入被拒（附伺服器 alert 原文）。
class LoginRejected extends LoginOutcome {
  const LoginRejected(this.alertText);
  final String alertText;
}

class WebFormsAuthApi {
  WebFormsAuthApi(this._dio);

  final Dio _dio;

  /// 「登入前置」：登入頁 hidden 欄位 + 綁 Session 的驗證碼圖 JPEG bytes。
  Future<LoginPreparation> fetchLoginPreparation({int nonce = 0}) async {
    final page = await getPlainText(AppConstants.loginPagePath);
    final hidden = extractHiddenFields(page);
    if (hidden.isEmpty || !hidden.containsKey('__VIEWSTATE')) {
      throw PageParseFailure(cause: '登入頁未取得 VIEWSTATE');
    }
    final captcha = await fetchCaptchaImage(nonce);
    return LoginPreparation(hiddenFields: hidden, captchaBytes: captcha);
  }

  /// 取得驗證碼圖片（綁定當前 Session，重取時用 [nonce] 避免快取）。
  Future<List<int>> fetchCaptchaImage([int nonce = 0]) async {
    final response = await _dio.get<List<int>>(
      AppConstants.captchaImagePath,
      queryParameters: nonce > 0 ? {'nonce': nonce} : null,
      options: Options(responseType: ResponseType.bytes),
    );
    final data = response.data;
    final contentType = response.headers.value(Headers.contentTypeHeader) ?? '';
    if (data == null || data.isEmpty || !contentType.startsWith('image/')) {
      throw DataParseFailure(
        detail: '驗證碼回應不是圖片（${contentType.isEmpty ? '無 Content-Type' : contentType}）',
      );
    }
    return data;
  }

  /// 登入（全欄位 WebForms POST）。
  Future<LoginOutcome> login({
    required String account,
    required String password,
    required String captcha,
    required Map<String, String> hiddenFields,
  }) async {
    final form = <String, String>{
      ...hiddenFields,
      'LoginStd:txtAccount': account,
      'LoginStd:txtPassWord': password,
      'LoginStd:txtCheckCode': captcha,
      'LoginStd:ibtLogin.x': '0',
      'LoginStd:ibtLogin.y': '0',
    };
    final response = await _dio.post<String>(
      AppConstants.loginPagePath,
      data: form,
      options: Options(contentType: 'application/x-www-form-urlencoded'),
    );
    final body = response.data ?? '';

    // 成功樣態：`<script>top.location.href='../Message/default.aspx';</script>`
    if (isLoginSuccessRedirect(body)) return const LoginSuccess();

    // 樣態：驗證碼不符
    if (isCaptchaError(body)) return const LoginCaptchaError();

    // 其餘 alert 樣態（帳密錯 / 帳號鎖定…）— 原文往上層以利 UI 顯示
    final alerts = extractAlerts(body);
    if (alerts.isNotEmpty) {
      return LoginRejected(alerts.join('；'));
    }
    // 重新渲染的完整登入頁但無 alert → 帳密錯誤（Phase 3 未測，保守文案）
    if (body.contains('LoginStd')) {
      return const LoginRejected('登入失敗，請確認帳號、密碼與驗證碼。');
    }
    throw ServerFailure(detail: '登入回應無法辨識', cause: body.length);
  }

  /// 一般 GET 純文字（供各解析層複用）。
  Future<String> getPlainText(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final response = await _dio.get<String>(
      path,
      queryParameters: query,
      options: Options(responseType: ResponseType.plain),
    );
    return response.data ?? '';
  }

  /// 登出：先 GET 一個含 CommonHeader 的頁面拿 hidden 欄位，再 POST 登出。
  Future<bool> logout() async {
    late final String page;
    try {
      page = await getPlainText(AppConstants.mainPagePath);
    } on DioException catch (error) {
      // The logout page returns the same short redirect shell used by the
      // expired-session detector when the server has already ended the session.
      if (error.error is SessionExpiredFailure) return true;
      rethrow;
    }
    final hidden = extractHiddenFields(page);
    if (hidden.isEmpty) {
      // 可能已是登出狀態（頁面轉回登入）— 視為已登出。
      return isRedirectShell(page);
    }
    final form = <String, String>{
      ...hidden,
      'CommonHeader:ibtLogOut.x': '5',
      'CommonHeader:ibtLogOut.y': '5',
    };
    late final Response<String> response;
    try {
      response = await _dio.post<String>(
        AppConstants.mainPagePath,
        data: form,
        options: Options(contentType: 'application/x-www-form-urlencoded'),
      );
    } on DioException catch (error) {
      if (error.error is SessionExpiredFailure) return true;
      rethrow;
    }
    final body = response.data ?? '';
    return body.contains('default.htm') || body.contains('Secure/default.aspx');
  }
}
