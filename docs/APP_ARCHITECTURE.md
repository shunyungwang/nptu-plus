# App 架構文件（Phase 5 交付）

> 版本資訊：Flutter 3.47.5 / Dart 3.13.4。
> 架構原則：Clean Architecture + Riverpod + Repository Pattern；UI 一律不直接呼叫 API。

## 環境

| 項目 | 值 |
|---|---|
| Flutter | 3.47.5 stable |
| Dart | 3.13.4 |
|Android | minSdk 由 template（flutter 默認），targetSdk 依 flutter config |
| 套件管理 | pub.dev 最新相容版（見 pubspec.yaml / pubspec.lock） |

## 主要相依套件

| 套件 | 用途 |
|---|---|
| flutter_riverpod | 狀態管理（全域 + scope） |
| go_router | 路由 + StatefulShellRoute（分頁狀態保留） |
| dio + cookie_jar + dio_cookie_manager | HTTP Client + Session/Cookie 持續管理（`.PaAuth` / `UNIVWeb_SessionId` / `TS01f68d9a`） |
| html | 官方 HTML 解析（WebForms 回應 → 資料模型） |
| drift + sqlite3_flutter_libs | 本地快取（課程/成績/公告） |
| flutter_secure_storage | 登入憑證儲存（Android Keystore 加密） |
| shared_preferences | 淺偏好（主題模式） |
| cached_network_image | 預留圖片快取；目前資料頁顯示文字與表格 |
| intl | 日期格式 |
| json_serializable + build_runner (dev) | JSON → Model codegen |
| drift_dev (dev) | 資料庫 codegen |

## 專案結構（已建立的骨架）

```
lib/
├── main.dart                      # 啟動 + SharedPreferences 注入
├── app/
│   ├── app.dart                   # MaterialApp.rootRouter + theme
│   ├── routers.dart (app/router.dart)  # 路由常數與 buildRouter
│   └── providers.dart             # 全域 providers（主題、登入狀態）
├── core/
│   ├── constants/app_constants.dart    # 學校系統 URL/Cookie/樣態特徵常數
│   ├── errors/failures.dart       # Failure 型別（登入過期/驗證碼錯/帳密錯/…）
│   ├── network/webforms_client.dart    # Dio + CookieJar + Session 過期偵測
│   ├── storage/theme_storage.dart # 主題偏好持久化
│   └── theme/                     # Design System
│       ├── app_colors.dart        # 種子色、亮/暗 scheme 生成
│       ├── app_typography.dart    # 字體排版階層
│       ├── app_spacing.dart       # 留白尺度
│       ├── app_radius.dart        # 圓角尺度
│       ├── app_components.dart    # 按鈕/輸入框/卡片/導航樣式
│       └── app_theme.dart         # Theme 總裝（light/dark）
└── features/
    ├── auth/login_page.dart       # WebForms 登入、圖形驗證碼與錯誤處理
    ├── shell/main_shell.dart      # 底部導航殼（5 分頁）
    ├── dashboard/                  # 首頁
    ├── timetable/                  # 課表
    ├── grades/                     # 成績
    ├── announcements/              # 公告
    ├── course_selection/           # 選課查詢
    ├── attendance/                 # 出缺勤
    ├── profile/                    # 個人資料
    ├── settings/                   # 設定（主題三模式/登出/版本）
    └── more/                       # 更多入口
```

## 資料方向（已實作）

```
UI (features) → Riverpod StateNotifier
→ domain/usecases
→ data/repositories（實作 domain 抽象）
→ data/datasources
   ├─ remote: WebFormsClient（Dio；GET 頁 → 解析 → PostBack）
   │    - 登入、Session、驗證碼、各模組頁表格解析
   └─ local: Drift 快取（refresh timestamps）
```

- UI 不得 import 'dio'，只吃經生成/手寫實體的 pure Dart 物件。
- 解析器集中在 `data/parsers/`（依 Phase 1-3 實測的頁面結構；含 `A0515S1_dgData` 等表格 id）。
- 回應樣態判斷（145/177 bytes 殼頁、「執行結果出現異常」）統一在 client 層轉為 `Failure`。

## 主題與 120Hz 策略

- 主題三模式：App 內設定（Light/Dark/System），儲存 SharedPreferences；首次啟動預設 System。
- 亮色/深色各自完整配色（`ColorScheme.fromSeed` 分別生成，非反轉）。
- 120Hz：不限制幀率、不套用會讓 Android 強制 60 的設定；動畫避免 blur/大陰影；清單用 `ListView.builder`；**尊重裝置與系統的刷新率設定**（Phase 9 進一步實測قی Profiles）。
- `StatefulShellRoute.indexedStack` 保留各分頁狀態，切換零重建。

## 目前驗證狀態

- 已串接登入、Session 還原與正式登出。
- 已串接首頁、公告、已選課程/課表、個人資料、成績及出缺勤查詢。
- 頁面資料即時從校務系統讀取；不使用固定示例資料或第三方同步。
- Android Internet 權限已設定；本機可使用 debug key 建置安裝版。
- 正式發行需設定使用者自己的 keystore（`android/key.properties`）。
