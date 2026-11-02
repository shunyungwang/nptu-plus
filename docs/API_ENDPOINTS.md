# NPTU 校務系統 Endpoint 清單（Phase 1）

> 基底：`https://webap.nptu.edu.tw`。全部為 HTML/Form POST 型態（非 REST）。
> 「驗證」欄位：⚡=Phase 1 已實測成功；📋=已定位頁面但只做 GET 觀測；✋=尚未驗證。

## 通用

> **Phase 3 狀態更新**：學年切換 PostBack 已實測成功（A0515S → 1142、B0105S → 1151）；A0551R 的 Crystal Reports PDF URL 已取得；公告資料源定位為 `Main.aspx` 的 `HOTNEWS_dgData` 表格（14 列：日期/主題/類別/單位）。

| Endpoint | Method | 用途 | 驗證 |
|---|---|---|---|
| `/Web/Secure/default.aspx?sIndex=2` | GET | 取登入頁（核發 `UNIVWeb_SessionId`、VIEWSTATE、EVENTVALIDATION） | ⚡ |
| `/Web/Modules/CaptchaCreator.aspx` | GET | 圖形驗證碼（JPEG 95×35, 4 位數字，綁 Session） | ⚡ |
| `/Web/Modules/CaptchaVoiceHandler.ashx` | GET | 語音驗證碼（音檔） | ✋ |
| `/Web/jsfunc.js` | GET | 共用前端函式庫（alert/confirm/report 函數語意） | ⚡ |
| `/Web/Secure/default.aspx?sIndex=2` | POST | 登入（欄位見 AUTH_FLOW.md） | ⚡ |
| `/Web/Message/default.aspx` | GET | 登入後框架首頁 | ⚡ |
| `/Web/Message/MenuTree.aspx` | GET | 完整功能選單（101 項） | ⚡ |
| `/Web/Message/Main.aspx` | GET | 主畫面（含使用者名、登出鈕） | ⚡ |
| `/Web/Message/Main.aspx` | POST | 正式登出（`CommonHeader:ibtLogOut.x/y`） | ⚡ |

## 學生核心模組（可直接 GET 模組頁，實測生效）

| Endpoint (GET) | 功能 | 資料機式 | 驗證 |
|---|---|---|---|
| `/Web/A02/A0207SPage.aspx` | 個人資料查詢 | 內嵌表單欄位 | ⚡(GET) |
| `/Web/A02/A0207S1Page.aspx` | 綜合資料紀錄表(A卡) | 待分 | 📋 |
| `/Web/A05/A0515SPage.aspx` | 已選課程清單（含教師/教室/星期節次/學分） | **內嵌 HTML 表格**（預設學期） | ⚡(GET) |
| `/Web/A05/A0551RPage.aspx` | 個人課表（PDF 報表流程） | PostBack 產 PDF | ⚡(GET 殼) |
| `/Web/A04/A0429S3Page.aspx` | 各種課表查詢 | 待分 | 📋 |
| `/Web/A08/A0809QPage.aspx` | 歷年成績查詢 | 選學年→PostBack | ⚡(GET 殼) |
| `/Web/A08/A0810QPage.aspx` | 成績抵免及免修查詢 | 待分 | 📋 |
| `/Web/A07/A0731SPage.aspx` | 已修學分資料查詢 | 待分 | 📋 |
| `/Web/B01/B0105SPage.aspx` | 曠課及請假資料查詢 | 選學年→PostBack | ⚡(GET 殼) |
| `/Web/B01/B0155APage.aspx` | 學生線上請假申請（App 原生假別／日期／節次／原因／附件表單；校務 WebForms `ibtSaveUp`／`ibtDeleteUp`） | App 內確認後才 POST；未代送或代刪 | 📋 |
| `/Web/A05/A0515SPage.aspx` (POST) | 切換學年期取得別學期清單 | PostBack | 📋 |
| `/Web/A08/A0809QPage.aspx` (POST) | 取得指定學年成績表 | PostBack | 📋 |
| `/Web/B01/B0105SPage.aspx` (POST) | 取得指定學年缺曠紀錄 | PostBack | 📋 |

## 其餘功能（Phase 3 依需求探索）

學務資料填報、畢業作業、證照、宿舍、社團、場地、投票、報修等 90+ 項，見 `analysis/menu.json`；所有最終 URL 均為 `/Web/<目錄>/<代碼>Page.aspx` 形式。

## 通用規則（實測歸納）

1. 所有模組頁為**獨立 WebForms 頁**：各自帶自己的 `__VIEWSTATE`/`__EVENTVALIDATION`，form action 為自身檔名（例 `./A0551RPage.aspx`）。
2. Cookie 需求：`.PaAuth`（必要）+ `TS01f68d9a`（跟隨伺服器重發即可）。
3. PostBack 欄位命名與控制項 `name` 屬性一一對應；`ImageButton` 需附 `.x/.y`。
4. 伺服器主動回 `Set-Cookie: TS01f68d9a=...`，Client 應持續存 CookieJar 並回送最新值。

## 尚未確認的資料源

- 校園公告：登入後首頁與選單中尚未比對出獨立公告模組；Phase 3 在 Main.aspx 區塊或系辦/網頁公告（`nptu.edu.tw` 公角）中調查。
- 學生 Email 系統 `stmail.nptu.edu.tw`（忘記密碼信寄往該處）：屬另一子系統，未納入 Phase 1。
