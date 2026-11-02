# NPTU 校務系統 API 分析報告（Phase 1）

> 分析日期：2026-11-02。**Phase 3 實測補充已整合**（見各節「Phase 3 補充」與第 10 節）。
> 分析方式：HTTP 層觀測（curl / Node fetch）＋ 靜態 HTML/JS 解析（Node.js）。**未使用 Apify**（使用者決定不採用 Apify 雲端擷取）。
> 敏感資料已遮蔽：學號以 `BBB1****` 表示，姓名以 `王○○`表示，所有 Token/Cookie 值一律不記錄。

## 1. 網站技術架構（實測確認）

| 項目 | 結論 |
|---|---|
| 入口 | `https://webap.nptu.edu.tw/` → meta-refresh → `/Web/Secure/default.aspx?sIndex=2` |
| 伺服器 | IIS / ASP.NET（ETag 為 IIS 特徵） |
| 框架 | **ASP.NET Web Forms**（`__VIEWSTATE` 加密、`__VIEWSTATEGENERATOR`、`__EVENTVALIDATION`、`WebForm_DoPostBackWithOptions`） |
| 資料架構 | **無 REST/GraphQL API**；資料為伺服器端渲染 HTML + Form PostBack |
| 流量防護 | F5 BIG-IP（`TS01f68d9a`） |
| Session 併發限制 | 同一帳號只能登入一次；非正常登出鎖 5 分鐘 |
| 安全標頭 | HSTS、X-Frame-Options、CSP(frame-ancestors)、nosniff 等 |
| 前端 | jQuery、`UnivWeb.css`、`smartui-compact34.css`、共用 `/Web/jsfunc.js`（46KB，含所有 alert/confirm/report 函數） |
| 系統名稱 | 校務行政系統（UnivWeb），計網中心開發維護 |

## 2. 畫面/Frame 結構（實測）

```
登入前：/Web/Secure/default.aspx?sIndex=2
登入後：/Web/Message/default.aspx (frameset)
        ├─ /Web/Message/MenuTree.aspx (選單, 101 功能項)
        └─ /Web/Message/Main.aspx     (主內容 + HOTNEWS 公告表格)
```

**Phase 3 補充**：`Main.aspx` 帶選單參數（`MENU_ID/MENU_CNAME/MODU_ID/MODU_CNAME/URL`）時，會**直接把模組頁內容輸出**（無 iframe 殼），尺寸與直接 GET 模組頁相近；session 會記住「目前模組」並顯示在每頁 `<title>`（Phase 3 在造訪 A0809Q wrapper 後，A0551R 頁 title 顯示 `[A0809Q]_歷年成績查詢`）。**App 不需要 wrapper**，直接 GET 模組頁即可。

## 3. Cookie 機制

| Cookie | 時點 | 用途 |
|---|---|---|
| `TS01f68d9a` | 每回應 | F5 流量管理 |
| `UNIVWeb_SessionId` | 開登入頁時 | 自訂 Session，綁定驗證碼 |
| `.PaAuth` | 登入成功後 | **持久性登入憑證**（HttpOnly/Secure/SameSite=Lax） |

- 另觀測到一組格式異怪的 `Secure;HttpOnly` Set-Cookie（空值 cookie 名 "Secure"）— App 端 CookieJar 需有跳過這種異常行的防禦（Node fetch 直接丟例外，實測踩雷）。

## 4. 驗證碼機制（實測）

| 項目 | 實測結果 |
|---|---|
| 圖片 | `GET /Web/Modules/CaptchaCreator.aspx`（JPEG）
| 更換 | 同 URL + 隨機 query |
| 長度 | 4 位數字 |
| 語音 | `CaptchaVoiceHandler.ashx` |
| **失敗訊息（Phase 3 實測）** | 驗證碼錯誤 → 回傳**全新登入頁** + `alert("驗證碼不符!!")`，末段有 `LoginStd_lblMsg`。失敗**不會鎖 Session**，但需重新取 VIEWSTATE 與新驗證碼 |

## 5. 全站功能清單

101 項 / 29 組，完整清單見 `analysis/menu.json`。學生端核心：A0207S（個人資料）、A0515S（已選課程清單，內嵌表格）、A0809Q（歷年成績）、B0105S（缺曠）、A0551R（個人課表 PDF 流程）、HOTNEWS（公告，在 Main.aspx 內）。

## 6. 頁面資料模式（Phase 3 實測後的完整歸納）

1. **內嵌表格**：A0515S 已選課程 — 實測切換學期也成功（`__EVENTTARGET=A0515SMenu$ddlSYSE` + `A0515SMenu:ddlSYSE=<value>`）。**114-2 回傳零資料列（合法空狀態：115 學年入學者無 114 學年資料）**。表格 id：`A0515S1_dgData`，另有選課階段下拉（selected 值 `4.選課完成`）。
2. **欄位內嵌**：A0207S 個人資料（唯讀）。
3. **選學年→PostBack（AutoPostBack 下拉）**：
   - B0105S 缺曠：下拉完整（1151/1152/1153/1142…），PostBack 成功（39KB 回應）；**資料區僅在該學期有缺曠紀錄時渲染**（本帳號無缺曠 → 合法空狀態）。
   - **A0809Q 歷年成績：初始下拉為空**（本帳號尚未有任何「確定成績」學期）。若 PostBack 的 `ddlSYSE` 值不在（空）選項清單中，伺服器回「執行結果出現異常」錯誤頁 — 這是**錯誤樣態的關鍵樣本**（POST 了不在清單的值）。
   - ⚠️ 這類「只列有資料學期」的下拉是通用模式，App 需動態讀取 option 而非自建學期清單。
4. **PDF 報表（Crystal Reports）**：A0551R `A0551R:ibtPrint` PostBack 後，回應中出現報表 URL：
   `https://webap.nptu.edu.tw:9443/crystal7/A0551RRPT.rpt?prompt0=國立屏東大學&prompt1=列印日期…&prompt3=<學年期>&prompt4=<學年>&prompt5=<學期>&prompt6=<加密值>&prompt7=<UNIVWeb_SessionId值+時間戳>&init=pdf`
   - 票券綁定 Session（prompt7）→ App 端可用 webview/Dio 下載；但**建議 App 以 A0515S 資料自行渲染課表**（資料齊全：星期/節次/教室/教師）。
5. **公告**：`Main.aspx` 內 `HOTNEWS_dgData` 表格，14 列（日期/公布主題/類別/單位），實測讀取成功。公告點入詳情為校方對外公告系統（另站，Phase 7 前調查）。

## 7. Session 維持（Phase 3 實測）

- 直接 GET 模組頁需有 `.PaAuth`；**Cookie 傳遞不完整會回 `<script>alert('未檢測到您的登入資訊，請重新登入!!')</script>` + 轉回 `/Web/default.htm`**（145 bytes 特徵，可作為 App 的「登入過期」偵測訊號）。
- Phase 3 整個 session 使用期間（多次 GET/POST，跨數十分鐘）`.PaAuth` 持續有效，無須重新驗證。
- jsfunc.js 中存在閒置登出提示程式碼（`setTimeout ... 1500000` = 25 分鐘提醒「系統將於5分鐘後自動登出」的註解狀態，未啟用），代表閒置過期可能存在但不明確 — App 應假設可能有閒置過期並自動偵測處理。

## 8. 通用 WebForms PostBack 實測指引（可程式化）

1. `GET` 模組頁 → 解析每個 `<input type="hidden">` 的 name/value（**不能只抓 name+value 相鄰的寫法**，需完整解析整個 tag）。
2. POST 回原 URL，帶全部 hidden 欄位 + 目標控件欄位：
   - AutoPostBack 下拉：`__EVENTTARGET=<Ctrl$Ctrl>`、`<Ctrl:Ctrl>=<新 value>`。
   - ImageButton：`__EVENTTARGET=` 空 + `<Ctrl>ibtPrint.x/y` 等座標值。
3. `__EVENTVALIDATION` 必須原封帶回，否則驗證失敗。
4. 成功辨別：同 URL 重新渲染、資料區/selected 屬性已更新。
5. 失敗樣態：145 bytes（未檢測到登入資訊）／16296 bytes（執行結果出現異常／資料格式錯誤）／重新登入頁。

## 9. 已驗證／未確認清單（更新）

### 驗證完成
- [x] 登入頁結構、登入 POST、`.PaAuth`、登出、Session 失效都完整可用（Phase 1）
- [x] 驗證碼錯誤處理樣態（`alert("驗證碼不符!!")`）與重試取出新驗證碼（Phase 3）
- [x] 學年切換 PostBack（A0515S → 1142 empty、B0105S → 1151）與 ImageButton 事件（A0551RibtPrint → Crystal Reports URL）（Phase 3）
- [x] 公告資料源（HOTNEWS_dgData）（Phase 3）
- [x] 未登入偵測訊號（145 bytes "未檢測到您的登入資訊"）（Phase 3）
- [x] 伺服器錯誤樣態（16296 bytes "執行結果出現異常"）（Phase 3）

### 尚未確認
- [ ] 帳密錯誤的訊息（驗證碼錯誤以外的失敗；為避免風險未測）
- [ ] Session 閒置過期的精確閾值
- [ ] A0809Q 有成績後的下拉行為（等有確定成績學期）
- [ ] 公告詳細頁 / 附件資料源（公告點入為校外系統）
- [ ] A0429S 課程查詢（公共目錄查詢）— 表單欄位已採樣（`A0425Q3:ddlDEPT_ID` 等），未做 PostBack

## 10. 工具與安全記錄

- 工具：curl、Node.js（fetch，配自寫 `analysis/webforms.js` 通用 WebForms PostBack 工具與 `analysis/parse_menu.js`）。使用者 Phase 1 決定**不使用 Apify**。
- 人工：驗證碼由使用者本人輸入（Phase 3 共計 1 次登入、1 次錯誤驗證碼測試、1 次正式登出）。
- 安全：帳密只存在暫存腳本並已刪除；Cookie jar 已刪除；`analysis/*.html`（含個人資料）加 `.gitignore` 防提交；文件全部遮蔽。
