# Layout & UI Refinement（版面重構紀錄）

這次改版不是「換顏色」，而是把每個頁面的資訊結構重排，並把所有尺寸收斂到單一 Design Tokens。
雙主題（Pure White / True OLED Black）與版面重構一起完成，Light 與 Dark 共用同一套版面邏輯。

## 1. Design Tokens（唯一尺寸來源）

| 檔案 | 內容 |
| --- | --- |
| `lib/core/theme/app_colors.dart` | Light `#FFFFFF` 底、Dark `#000000` 底、Dark surface `#0A0A0A` / `#111111`、語意色 |
| `lib/core/theme/app_typography.dart` | 單一 TextTheme（display → label），只用字重／字級／行高建立層級 |
| `lib/core/theme/app_spacing.dart` | 4 / 8 / 12 / 16 / 24 / 32 六階留白 |
| `lib/core/theme/app_radius.dart` | 8 / 12 / 16 / 28 / pill 圓角 |
| `lib/core/theme/app_dimensions.dart` | 頁面邊距 20、區塊間距 28、卡片內距 16、按鈕 52、輸入框 52、icon 18/22/28、清單列 14 |
| `lib/core/theme/app_components.dart` | 按鈕／輸入框／Card／NavigationBar／SnackBar／Dialog／Chip 主題 |
| `lib/core/theme/app_theme.dart` | `buildLightTheme()` / `buildDarkTheme()` 唯一組裝點 |
| `lib/core/theme/theme_provider.dart` | `themeModeProvider`（light / dark / system，持久化） |
| `lib/core/widgets/app_surfaces.dart` | `AppCard` / `AppSectionHeader` / `AppLoadingView` / `AppEmptyView` / `AppErrorView` |

頁面不再自行寫 `EdgeInsets.all(16)`、`height: 88` 或宣告 `TextStyle`。

## 2. 逐頁結構調整

### Login
- 移除裝飾性大圖與多餘卡片：品牌標記（44×44）→ 校名 → 登入方式 → 表單 → 主要按鈕 → 次要切換。
- 帳號／密碼同一欄寬、同一高度（52）；錯誤訊息緊接在欄位群組下方並附 icon，不再用 SnackBar。
- 登入流程只有校務系統 webap 一套（RWD 登入已移除）：帳號 → 密碼 → 驗證碼，驗證碼圖片可點擊重取；登入按鈕為頁面唯一的 `FilledButton`。
- 內容以 `ConstrainedBox(maxWidth: 400)` 限制，平板／橫向不會拉成過寬的一行。

### Dashboard
- 由上而下：招呼語（純文字）→ 姓名（headlineSmall）→ 日期 → 今日課程 → 最新公告 → 常用功能。
- 「今日課程」改為單一卡片內的時間軸列（時間欄 + 課名 + 教室／教師），不再一課一張卡；無課時顯示一行「今天沒有排定課程」。
- 最新公告只留一則（標題 + 日期／單位），完整列表在公告頁；常用功能四個入口合併在同一張卡。
- 每個區塊都有 `AppSectionHeader`（標題 + 右側文字操作／數量），資訊層級一致。

### Timetable
- 星期選擇器為 7 格等寬膠囊（今天以圓點標記），選取狀態清楚。
- 內容為「節次 / 時間」左欄 + 「課名 / 教室・教師・班級」右欄的時間軸；同一節多門課以間距分隔。
- 節次代碼（M、A–D、01–08…）統一轉為「第 N 節」，時間以開始／結束兩行呈現；長課名最多兩行並省略，不裁切。
- 空狀態、載入、錯誤都改用共用狀態元件。

### Grades
- 學期選擇器改為單列（標籤「學期」+ 內嵌 Dropdown），只出現一次，不再重複顯示於卡片內外。
- 成績改為對齊清單：左側課名（主）+ 學分（次），右側分數（等寬數字、靠右）。六筆成績在一個區塊內即可掃讀，不再一筆一張卡。
- 表頭欄位以關鍵字（科目／學分／成績）定位，欄位順序變動仍能正確對應；無成績時顯示空狀態。

### Profile
- 身份區（頭像、姓名、學號、在學狀態）不放在卡片裡，改用大字與留白建立焦點。
- 「學籍資訊」「聯絡資訊」各自一張卡，卡內以分隔線列項；標籤固定 84dp，值自動換行。
- 「更多資料」收合，控制頁面長度；同值欄位（手機／地址）去重。
- 載入／錯誤／空資料改用共用狀態元件。

### Announcements
- 列表以日期為錨點（月 + 日兩行），標題優先（最多三行），單位／類別為次要文字；整列可點，右側 chevron。
- 移除逐則卡片與多餘 icon，改用細分隔與留白，提高單屏資訊量與掃讀速度。
- 新增閱讀頁：大字標題 → 中繼資訊 → 分隔線 → 內容說明，並明確標示僅同步標題與發布資訊。

### Settings
- 分為「外觀 / 帳號 / 關於」三組，每組一張卡、卡內列項，不再每項一張大卡。
- 主題選項為 radio 列（含 icon），帳號區顯示目前登入學號，登出為唯一的破壞性操作（error 色），並有 loading 狀態。

### More / Course Selection / Attendance
- 功能入口改為分組清單（課務 / 個人），單卡多列。
- 選課查詢改為課名 + 星期節次／教室／教師 + 右側學分，與成績頁同一種列式結構。
- 出缺勤的載入與錯誤改用共用狀態元件。

## 3. 響應式與可及性

- 所有頁面使用 `SafeArea`（登入頁）或 `AppBar + ListView(padding: pageInsets)`，底部留白 40 避開手勢區。
- 登入頁使用 `LayoutBuilder`，矮螢幕縮小上緣留白。
- 課表、公告、成績、選課皆為 `ListView`／`ListView.separated`；不設固定高度，不硬編螢幕尺寸。
- 觸控目標：按鈕 52、清單列 ≥ 48、icon button 走 Material 預設 48。
- 文字皆設 `maxLines` + `ellipsis` 或自動換行；已用 1.3× 字體與 320dp 窄螢幕測試無 overflow。

## 4. 視覺驗收（截圖）

因本機沒有 Android 模擬器／實機（`flutter emulators` 無可用項目、`adb devices` 為空），
改以 Flutter 測試渲染真實 Widget 樹並輸出 PNG：`flutter test --update-goldens test/screenshots_test.dart`。
harness 會載入系統 CJK 字型（`C:/Windows/Fonts/kaiu.ttf`）與 MaterialIcons，因此截圖中的中文字與 icon 為實際字形。

輸出於 `docs/screenshots/`（412×915 dp，devicePixelRatio 2）：

- `login_light.png` / `login_dark.png`
- `dashboard_light.png` / `dashboard_dark.png`
- `timetable_light.png` / `timetable_dark.png`
- `grades_light.png` / `grades_dark.png`
- `announcements_light.png` / `announcements_dark.png`
- `profile_light.png` / `profile_dark.png`
- `settings_light.png` / `settings_dark.png`

同一 harness 另含兩個 regression 檢查：1.3× 系統字體、320dp 窄螢幕，皆不得出現 RenderFlex overflow。

限制：golden 為離線渲染，無法驗證鍵盤彈出、實際觸控回饋與廠牌 ROM 的字型差異；這些需實機再確認。
