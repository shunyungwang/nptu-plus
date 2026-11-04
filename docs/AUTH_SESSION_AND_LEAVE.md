# 登入架構清理、帳號切換隔離與請假取消修復

## 1. 移除 RWD 登入整合

RWD（`rwdapp.nptu.edu.tw`）登入路徑已完全移除，App 只剩校務系統 webap（WebForms + 圖形驗證碼）一套流程。

| 動作 | 檔案 |
| --- | --- |
| 刪除 RWD 資料源 | `lib/data/datasources/rwd_api.dart` |
| 刪除 RWD Repository | `lib/data/repositories/rwd_auth_repository.dart` |
| 刪除 RWD HTTP client | `lib/core/network/rwd_client.dart` |
| 刪除登入方式偏好 | `lib/core/storage/auth_mode_storage.dart` |
| 移除 RWD 常數（baseUrl／login／user info／timetable） | `lib/core/constants/app_constants.dart` |
| 移除 `RwdAuthApi` / `rwdDioProvider` / `rwdAuthRepositoryProvider`，`authRepositoryProvider` 直接提供 `AuthRepositoryImpl` | `lib/core/network/providers.dart` |
| 移除 `AuthMode` enum、`authModeProvider`、`AuthModeController` | `lib/app/providers.dart` |
| 移除 `studentDataApiProvider` 的分流與 `rwdStudentApiProvider` | `lib/features/student_data_providers.dart` |
| 移除登入頁的「改用 RWD 登入」切換與 `needsCaptcha` 分支 | `lib/features/auth/login_page.dart` |
| 移除設定的「登入方式」列（改顯示目前帳號） | `lib/features/settings/settings_page.dart` |
| `prepareLogin()` 改為必定回傳 `LoginPreparation`（不再用 null 表示免驗證碼） | `domain/repositories/auth_repository.dart`、`auth_repository_impl.dart`、`app/providers.dart` |
| 移除 `SessionKind`（storage 只存學號與 `.PaAuth`） | `lib/core/storage/auth_session_storage.dart`、`lib/main.dart` |

保留不動的共用基礎：`buildWebFormsDio`（Dio + CookieJar + 登入過期偵測）、`WebFormsAuthApi`、
`.PaAuth` / `UNIVWeb_SessionId` 的 Cookie 處理、`restoreSession`、`VERSION`。

驗證：`grep -rniE "rwd|authMode|SessionKind" lib test pubspec.yaml` → 無結果。
`pubspec.yaml` 未移除任何套件，因為 RWD 只用到共用的 `dio`、`cookie_jar`（WebForms 仍在使用）。

## 2. 帳號切換的資料隔離

### 根因

1. 所有資料都是 `FutureProvider`，Riverpod 會保留上一次結果。
2. 登出只把 `AuthStatus` 改成 `loggedOut`，**沒有任何 Provider 失效**，
   所以再登入 B 時畫面重繪仍讀到 A 的快取（或帶著 A 的 previous value）。
3. 換帳號時沒有中止 A 仍在飛的請求。

### 修正

- 新增 `sessionGenerationProvider`（Session 世代）與 `currentAccountProvider`（目前帳號）。
- 所有帳號相關 Provider（`profileProvider`、`coursesProvider`、`announcementsProvider`、
  `gradesProvider`、`attendanceProvider`、`leavePageProvider`、`studentDataApiProvider`、
  `leaveDataApiProvider`）都 `watch` 這兩個值 → 換帳號時自動作廢、以新帳號重取。
- `AuthStatusController` 生命週期：
  - `signIn`：先中止所有進行中請求 → 認證成功 → 設定帳號 → 世代 +1 → `loggedIn`。
  - `signOut`：先中止請求 → 伺服器登出 → 清除帳號 → 世代 +1 → `loggedOut`（finally 保證）。
  - `sessionExpired`：中止請求 → 清除帳號 → 世代 +1 → `loggedOut`。
  - `restore`（冷啟動）：以儲存的學號重新建立 Session 與世代。
- `SessionRequestTracker`（Dio interceptor）追蹤所有請求的 `CancelToken`，
  換帳號／登出時整批 `cancel()`；舊帳號的回應因此不可能落到新帳號畫面。
- 舊世代的 `FutureProvider` 實例已被丟棄，晚到的回應只會寫進不再被監聽的舊實例。

### 快取命名空間說明

本專案沒有本機資料庫或 API 回應快取（`drift` 依賴存在但未被使用），
所以「依帳號隔離的快取」實作在 Provider 層：一次登入世代 = 一份快取，
世代更迭即整份作廢，等於 `cache/account_A/*` 與 `cache/account_B/*` 互不相通。

### 驗收測試（`test/account_switch_test.dart`）

| 情境 | 結果 |
| --- | --- |
| A 登入 | `currentAccount == A`、世代 1、資料為 A |
| A 登出 | 帳號清空、世代 2、畫面狀態不再是 A 的資料 |
| A → B | 世代 2、資料為 B |
| A 請求延遲期間登入 B | B 資料先呈現；A 完成後目前狀態仍是 B |
| B 重新整理 | 只拿到 B；再切回 A 得到新的 A |
| 冷啟動 | `restore(account:)` 走同一條世代流程（需實機驗證伺服器端） |

限制：測試以假的 `StudentDataApi` 驗證 Provider 生命週期；真實伺服器端的
Session 行為（同一帳號單一登入、鎖定 5 分鐘）仍建議用兩個真帳號實測一次。

## 3. 請假取消

> **2026-11-04 實測更新：** 校務系統真正的取消機制與下列最初假設不同，最終實作為
> 「勾選該列的 checkbox + 送出表格下方的 `B0155A:ibtDeleteUp`」，詳見第 4 節。
> 本節保留最初的錯誤分析，第 4 節是實測後的事實。

### 原本的錯誤

舊版「取消已送出的請假」要求畫面同時存在：

- `name.endsWith(':txtEXCESE_DT')`（拼字疑似錯，實際多為 `txtEXCUSE_DT`）
- `name.endsWith(':ddlABSENCE')`
- 節次 checkbox
- `name.endsWith(':ibtDeleteUp')` 或標籤含「刪除」

只要校務系統改了欄位名稱、把日期欄位設為唯讀，或取消鈕是 GridView 每列的
`__doPostBack` 連結，就會直接顯示「無法辨識校務系統取消欄位」而無法取消。

### 修正方式

1. **改以該列自己的 postback 取消**（網站真正的行為）：
   - 解析器在每一列找出 `__doPostBack('...$dgData$ctlNN$ibtDelete','')` 這類連結，
     存成 `LeaveRecord.cancelAction`。
   - `WebFormsLeaveApi.cancelRecord()` 以載入時的 hidden fields（VIEWSTATE／
     EVENTVALIDATION）加上該列的 `__EVENTTARGET` / `__EVENTARGUMENT` POST 回原頁面。
   - UI 每筆紀錄右下角出現「取消這筆請假」，確認後直接送出，不再要求使用者重填日期與節次。
2. **欄位辨識改為語意比對**（不再綁死拼字與 control id）：
   - 假別：`ABSENCE` / `LEAVEKIND` / 標籤「假別」
   - 日期：`EXCE` + `DT` / 標籤「日期」
   - 原因：`REASON` / `MEMO`
   - 取消類操作：`取消|刪除|撤回|delete|cancel`（label／name／eventTarget 任一命中）
3. **不再提供「自行輸入日期＋節次取消」這條易錯路徑**；沒有取消鈕的紀錄只顯示提示，
   引導回校務系統處理，避免送出錯誤的取消請求。
4. 欄位模型新增 `LeaveControl.shortName`、`LeaveAction.isCancel`、
   `LeavePageDefinition.cancelActions` / `cancellableRecords`，供 UI 與診斷使用。

### 測試（`test/leave_cancel_test.dart` + `test/fixtures/b0155a_leave.html`）

- 以 `EXCUSE` 拼法的 fixture 驗證欄位仍被正確辨識（證明不再依賴舊拼字）。
- 每一列都被解析出獨立的 `eventTarget`（`dgData$ctl02$ibtDelete`、`ctl03$ibtDelete`）。
- `cancelRecord()` 送出的 POST body 含正確的 `__EVENTTARGET`、`__EVENTARGUMENT`、
  `__VIEWSTATE`、`__EVENTVALIDATION`。
- 沒有取消鈕的紀錄會得到 `DataParseFailure`（明確錯誤，而不是靜默失敗）。

## 4. 實機實測結果（2026-11-04，webap 正式伺服器）

### 方式

以人工輸入圖形驗證碼登入（未破解、未繞過 CAPTCHA），再於瀏覽器抓取真實頁面結構與送出請求。

### 實際頁面結構（與原假設的差異）

| 項目 | 實際值 |
| --- | --- |
| control 前綴 | `B0155A:`（不是 `ctl00$ContentPlaceHolder1$`） |
| 日期欄位 | `B0155A:txtEXCESE_DT`（校方拼字就是 `EXCESE`），以 `WdatePicker` 選日期 |
| 假別 | `B0155A:ddlABSENCE`，值 `B/C/J/P`，文字為 `B.事假` 等 |
| 節次 | `B0155A:cblLESSON_ID:0..14`（CheckBoxList），值 `1..12` 與 `78/45/89` 等合併節次 |
| 送出 | `B0155A:ibtSaveUp`（image 按鈕，alt=存檔） |
| 紀錄表 | `B0155A_dgData`（`DgTable`），表頭 `刪除/請假日期/節次/假別/請假原因/審核狀態` |
| 干擾表 | `B0155A_dgDataSession`（節次時間表）必須排除，不可當成紀錄 |

### 取消的真實機制（重點）

紀錄列的「刪除」欄**不是按鈕，而是一個 checkbox**：

```html
<input id="B0155A_dgData_chkDel_0" type="checkbox" name="B0155A:dgData:_ctl2:chkDel">
```

真正的刪除鈕是表格下方的 image 按鈕（同頁還有 `ibtCancelUp`「取消」與 `ibtBackUp`「回上層」，
後者只是離開畫面，**不可**當成刪除）：

```html
<input type="image" name="B0155A:ibtDeleteUp" id="B0155A_ibtDeleteUp" alt="刪除" onclick="return deleteConfirm();">
```

因此取消請求 = 所有 hidden fields（`__VIEWSTATE`／`__EVENTVALIDATION`／空的 `__EVENTTARGET`）
＋ 該列的 `B0155A:dgData:_ctlN:chkDel=on` ＋ `B0155A:ibtDeleteUp.x=0`／`.y=0`。

### 實測步驟與結果

1. 登入後導向 `/Web/B01/B0155APage.aspx`，紀錄表 0 筆。
2. 以真實表單建立一筆測試請假（2026/11/05、第 01 節、事假），紀錄出現且狀態「導師未審」。
3. 以與 App 相同形狀的請求取消：`chkDel=on` + `ibtDeleteUp.x/y`，並帶原有 ViewState。
4. 伺服器回應 HTTP 200、訊息「刪除成功。」，`B0155A_dgData` 回到只剩表頭。
5. 重新載入頁面確認已持久化（仍為 0 筆）。

### 對應的程式變更

- `LeaveRecord.selection`（列上 checkbox 的 name/value）。
- `LeavePageDefinition.deleteAction`（以 `isDelete` 挑選 `ibtDeleteUp`，避免誤選 `ibtCancelUp`）。
- `canCancel()`／`cancellableRecords`：有逐列 postback **或**（有 checkbox 且頁面有刪除鈕）即可取消。
- 文字欄位會保留頁面預填值（實際頁面預填 `2026/11/05`）。
- 同時保留舊式「每列自帶 `__doPostBack`」的處理路徑，供其他學年度／頁面版本使用。

### 仍未涵蓋

- App 端是透過 Dio 帶 CookieJar 送出；本次驗證是在同一登入 session 以相同 body 送出，
  尚未在手機上完成「App 內登入 → 取消」的端到端流程（需人工輸入驗證碼）。
- 一次僅取消一筆；校務系統本身支援多筆勾選後一次刪除，App 目前不提供多選。
- `ibtDeleteUp` 對已核准的紀錄是否同樣有效，未逐一測試。
