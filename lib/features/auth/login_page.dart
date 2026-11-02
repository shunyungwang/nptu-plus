/// 登入頁。
///
/// WebForms 登入頁，含 Session 綁定驗證碼與伺服器錯誤回饋。
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/auth_session.dart';

import '../../app/providers.dart';
import '../../app/router.dart' as routes;
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';

/// 登入頁面內部的本地 UI 狀態。
class LoginUiState {
  const LoginUiState({
    this.obscurePassword = true,
    this.captchUrl = AppConstants.captchaImagePath,
  });

  /// 密碼是否遮蔽。
  final bool obscurePassword;

  /// 驗證碼圖片的載入 URL（帶 cache-busting query）。
  final String captchUrl;

  LoginUiState copyWith({bool? obscurePassword, String? captchUrl}) =>
      LoginUiState(
        obscurePassword: obscurePassword ?? this.obscurePassword,
        captchUrl: captchUrl ?? this.captchUrl,
      );
}

class LoginUiController extends Notifier<LoginUiState> {
  int _captchaNonce = 0;

  @override
  LoginUiState build() => const LoginUiState();

  void togglePassword() =>
      state = state.copyWith(obscurePassword: !state.obscurePassword);

  /// 重新取得驗證碼（點擊圖片 → 新 query，Phase 3 實測行為）。
  void refreshCaptcha() {
    _captchaNonce++;
    state = state.copyWith(
      captchUrl: '${AppConstants.captchaImagePath}?$_captchaNonce',
    );
  }
}

final loginUiProvider = NotifierProvider<LoginUiController, LoginUiState>(
  LoginUiController.new,
);

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();
  final _captchaController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;
  bool _loadingCaptcha = true;
  int _captchaGeneration = 0;
  LoginPreparation? _preparation;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _refreshCaptcha();
  }

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_preparation == null) {
      setState(() => _loadError = '驗證碼尚未載入，請稍後重試。');
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(authStatusProvider.notifier).signIn(
        account: _accountController.text.trim(),
        password: _passwordController.text,
        captcha: _captchaController.text.trim(),
        preparation: _preparation!,
      );
      if (mounted) GoRouter.of(context).go(routes.kRouteDashboard);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error is Failure
          ? error.message
          : '登入失敗，請檢查網路後重試。');
      _captchaController.clear();
      await _refreshCaptcha();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _refreshCaptcha() async {
    final generation = ++_captchaGeneration;
    setState(() {
      _preparation = null;
      if (_loadError?.startsWith('無法載入驗證碼') ?? false) _loadError = null;
      _loadingCaptcha = true;
    });
    try {
      final prep = await ref
          .read(authStatusProvider.notifier)
          .loadLoginPreparation()
          .timeout(const Duration(seconds: 40));
      if (mounted && generation == _captchaGeneration) {
        setState(() {
          _preparation = prep;
          _loadingCaptcha = false;
        });
      }
    } catch (error) {
      if (mounted && generation == _captchaGeneration) {
        setState(() {
          _loadError = _describeCaptchaError(error);
          _loadingCaptcha = false;
        });
      }
    }
  }

  String _describeCaptchaError(Object error) {
    if (error is Failure) return error.message;
    if (error is DioException) {
      if (error.error is Failure) return (error.error as Failure).message;
      final status = error.response?.statusCode;
      if (status != null) {
        final contentType = error.response?.headers.value(Headers.contentTypeHeader) ?? 'unknown';
        final cause = error.error?.toString() ?? error.type.name;
        return 'HTTP $status ($contentType)，請求 ${error.requestOptions.uri.path} 失敗：$cause';
      }
      final details = error.message;
      return details == null || details.isEmpty
          ? '連線校務系統失敗（${error.type.name}），請檢查網路或 VPN。'
          : '連線校務系統失敗：$details';
    }
    if (error is TimeoutException) return '校務系統連線逾時，請檢查網路或 VPN。';
    return '驗證碼載入失敗：$error';
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(loginUiProvider);
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ---- 品牌區 ----
                    Icon(
                      Icons.school,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: AppSpacing.l),
                    Text(
                      '國立屏東大學',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium,
                    ),
                    Text(
                      '校務行政系統',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    // ---- 帳號 ----
                    TextFormField(
                      controller: _accountController,
                      decoration: const InputDecoration(
                        labelText: '帳號（學號）',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      maxLength: 30,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '請輸入帳號' : null,
                    ),
                    const SizedBox(height: AppSpacing.m),
                    // ---- 密碼 ----
                    TextFormField(
                      controller: _passwordController,
                      obscureText: ui.obscurePassword,
                      decoration: InputDecoration(
                        labelText: '密碼',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            ui.obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          tooltip: ui.obscurePassword ? '顯示密碼' : '隱藏密碼',
                          onPressed: ref
                              .read(loginUiProvider.notifier)
                              .togglePassword,
                        ),
                      ),
                      maxLength: 30,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? '請輸入密碼' : null,
                    ),
                    const SizedBox(height: AppSpacing.m),
                    // ---- 驗證碼 ----
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _captchaController,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            decoration: const InputDecoration(
                              labelText: '驗證碼（4 位數字）',
                              counterText: '',
                            ),
                            validator: (v) => (v == null || v.length < 4)
                                ? '請輸入 4 位數字驗證碼'
                                : null,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.m),
                        GestureDetector(
                          onTap: _submitting ? null : _refreshCaptcha,
                          child: Container(
                            height: 48,
                            width: 128,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: _preparation != null
                                ? Image.memory(
                                    Uint8List.fromList(_preparation!.captchaBytes),
                                    gaplessPlayback: true,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, _, _) => const Icon(Icons.refresh),
                                  )
                                : _loadingCaptcha
                                    ? const CircularProgressIndicator(strokeWidth: 2)
                                    : const Icon(Icons.refresh),
                          ),
                        ),
                      ],
                    ),
                    if (_loadError != null) ...[
                      const SizedBox(height: AppSpacing.s),
                      Text(_loadError!, textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.error)),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('登入'),
                    ),
                    const SizedBox(height: AppSpacing.l),
                    Text(
                      '同一帳號僅允許單一登入；未正常登出會暫時鎖定 5 分鐘。',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
