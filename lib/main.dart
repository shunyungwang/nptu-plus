/// NPTU 校務系統 App 進入點。
///
/// 啟動流程：
/// 1. 預先載入 SharedPreferences（主題偏好同步可用）。
/// 2. 建立檔案型 CookieJar（app 支援目錄內）。
/// 3. ProviderScope 注入 SharedPreferences + CookieJar。
/// 4. 嘗試還原上次登入（secure storage 的 `.PaAuth` + 伺服器端校驗）。
library;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/network/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 保持高刷新率可用：交由系統決定顯示模式（尊重裝置與使用者設定），
  // App 端不限制幀率；動畫與捲動全部以高刷新率為目標最佳化。
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final prefs = await SharedPreferences.getInstance();
  final dir = await getApplicationSupportDirectory();
  final cookieJar = PersistCookieJar(
    storage: FileStorage('${dir.path}/cookies'),
    // 學校 .PaAuth 為 session cookie（無 expires）；需跨啟動保存必須 ignoreExpires。
    ignoreExpires: true,
  );

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        cookieJarProvider.overrideWithValue(cookieJar),
      ],
      child: const _Bootstrap(),
    ),
  );
}

/// 啟動還原控制器：完成後isReady=true。
final appReadyProvider = NotifierProvider<AppReadyController, bool>(
  AppReadyController.new,
);

class AppReadyController extends Notifier<bool> {
  @override
  bool build() => false;

  void ready() => state = true;
}

class _Bootstrap extends ConsumerStatefulWidget {
  const _Bootstrap();

  @override
  ConsumerState<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends ConsumerState<_Bootstrap> {
  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      final repo = ref.read(authRepositoryProvider);
      final ok = await repo.restoreSession();
      if (ok) ref.read(authStatusProvider.notifier).loggedIn();
    } catch (_) {
      // 還原失效 → 未登入，UI 走登入流程。
    } finally {
      ref.read(appReadyProvider.notifier).ready();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = ref.watch(appReadyProvider);
    if (!ready) {
      return MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return const NptuCampusApp();
  }
}
