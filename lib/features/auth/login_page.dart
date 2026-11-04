/// 登入頁：校務系統（webap）帳號密碼 + 圖形驗證碼。
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart' as routes;
import '../../core/errors/failures.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_spacing.dart';
import '../../domain/entities/auth_session.dart';

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
  bool _obscurePassword = true;
  bool _loadingCaptcha = false;
  int _captchaGeneration = 0;
  LoginPreparation? _preparation;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPreparation();
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
    final preparation = _preparation;
    if (preparation == null) {
      setState(() => _error = '驗證碼尚未載入，請稍後重試。');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(authStatusProvider.notifier)
          .signIn(
            account: _accountController.text.trim(),
            password: _passwordController.text,
            captcha: _captchaController.text.trim(),
            preparation: preparation,
          );
      if (mounted) context.go(routes.kRouteDashboard);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _describeError(error));
      _captchaController.clear();
      await _loadPreparation();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _describeError(Object error) {
    if (error is Failure) return error.message;
    if (error is DioException && error.error is Failure) {
      return (error.error as Failure).message;
    }
    if (error is TimeoutException) return '校務系統連線逾時，請檢查網路或 VPN。';
    return '登入失敗，請稍後再試。';
  }

  Future<void> _loadPreparation() async {
    final generation = ++_captchaGeneration;
    setState(() {
      _preparation = null;
      _loadingCaptcha = true;
    });
    try {
      final preparation = await ref
          .read(authStatusProvider.notifier)
          .prepareLogin()
          .timeout(const Duration(seconds: 40));
      if (!mounted || generation != _captchaGeneration) return;
      setState(() {
        _preparation = preparation;
        _loadingCaptcha = false;
      });
    } catch (error) {
      if (!mounted || generation != _captchaGeneration) return;
      setState(() {
        _loadingCaptcha = false;
        _error = _describeError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: AppDimensions.pagePadding,
                vertical: constraints.maxHeight > 700 ? 40 : AppSpacing.xl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.school_outlined,
                            size: AppDimensions.iconMedium,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.l),
                      Text('國立屏東大學', style: theme.textTheme.headlineSmall),
                      const SizedBox(height: AppDimensions.tightGap),
                      Text(
                        '校務系統登入',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _accountController,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
                        decoration: const InputDecoration(labelText: '帳號（學號）'),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? '請輸入帳號'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.m),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: '密碼',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: AppDimensions.iconMedium,
                            ),
                            tooltip: _obscurePassword ? '顯示密碼' : '隱藏密碼',
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        validator: (value) =>
                            (value == null || value.isEmpty) ? '請輸入密碼' : null,
                      ),
                      const SizedBox(height: AppSpacing.m),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _captchaController,
                              keyboardType: TextInputType.number,
                              maxLength: 4,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) =>
                                  _submitting ? null : _submit(),
                              decoration: const InputDecoration(
                                labelText: '驗證碼',
                                helperText: '4 位數字',
                                counterText: '',
                              ),
                              validator: (value) =>
                                  (value == null || value.trim().length < 4)
                                  ? '請輸入 4 位數字驗證碼'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.m),
                          Tooltip(
                            message: '重新取得驗證碼',
                            child: InkWell(
                              onTap: _submitting ? null : _loadPreparation,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                height: AppDimensions.inputHeight,
                                width: 116,
                                decoration: BoxDecoration(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: _preparation != null
                                    ? Image.memory(
                                        Uint8List.fromList(
                                          _preparation!.captchaBytes,
                                        ),
                                        gaplessPlayback: true,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, _, _) =>
                                            const Icon(Icons.refresh),
                                      )
                                    : _loadingCaptcha
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.refresh,
                                        size: AppDimensions.iconMedium,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.m),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: AppDimensions.iconSmall,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(width: AppSpacing.s),
                            Expanded(
                              child: Text(
                                _error!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 28),
                      FilledButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('登入'),
                      ),
                      const SizedBox(height: AppSpacing.l),
                      Text(
                        '同一帳號僅允許單一登入；忘記密碼請洽學校資訊服務單位。',
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
      ),
    );
  }
}
