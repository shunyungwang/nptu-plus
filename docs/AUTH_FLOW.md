# NPTU 校務系統登入流程分析（Phase 1）

> 所有內容來自 Phase 1 實測。敏感值全部遮蔽。

## 1. 登入頁

`GET https://webap.nptu.edu.tw/Web/Secure/default.aspx?sIndex=2`

- 內容型別 `text/html; charset=utf-8`，同時核發 `UNIVWeb_SessionId`（HttpOnly/Secure/SameSite=Lax）。
- 表單：`<form method="post" action="./default.aspx?sIndex=2" id="_default">`
- 隱藏欄位：`__EVENTTARGET`、`__EVENTARGUMENT`、`__VIEWSTATE`（加密，無明文結構）、`__VIEWSTATEGENERATOR=72CE233D`、`__SCROLLPOSITIONX/Y`、`__VIEWSTATEENCRYPTED`、`__EVENTVALIDATION`
- 使用者欄位（命名容器 `LoginStd`）：

| 欄位 name | 類型 | 說明 |
|---|---|---|
| `LoginStd:txtAccount` | text (max 30) | 學號 |
| `LoginStd:txtPassWord` | password (max 30) | 密碼 |
| `LoginStd:txtCheckCode` | text (max 4, numeric) | 圖形驗證碼 |
| `LoginStd:ibtLogin` | image button | 送出（POST 需附 `LoginStd:ibtLogin.x=0&LoginStd:ibtLogin.y=0`） |
| `LoginStd:ibtForgetPwd` | image button | 忘記密碼流程（未測） |

- 驗證碼圖：`<img src="../Modules/CaptchaCreator.aspx">`（→ `/Web/Modules/CaptchaCreator.aspx`），點擊重新取得。
- 語音驗證碼：`/Web/Modules/CaptchaVoiceHandler.ashx?ts=<timestamp>`。

## 2. 登入 POST（實測成功的形狀）

```
POST /Web/Secure/default.aspx?sIndex=2
Content-Type: application/x-www-form-urlencoded
Cookie: UNIVWeb_SessionId=<同一分頁的Session>; TS01f68d9a=<F5值>

__EVENTTARGET=
__EVENTARGUMENT=
__VIEWSTATEENCRYPTED=
__VIEWSTATE=<登入頁的值，GET 時取得>
__VIEWSTATEGENERATOR=72CE233D
__EVENTVALIDATION=<登入頁的值>
__SCROLLPOSITIONX=0
__SCROLLPOSITIONY=0
LoginStd:txtAccount=<帳號>
LoginStd:txtPassWord=<密碼>
LoginStd:txtCheckCode=<4位數驗證碼>
LoginStd:ibtLogin.x=0
LoginStd:ibtLogin.y=0
```

**成功回應（HTTP 200）**

```
Set-Cookie: .PaAuth=<不透明長字串>; path=/; HttpOnly; SameSite=Lax; Secure
Body: <script>top.location.href='../Message/default.aspx';</script>
```

- 判斷登入成功：`.PaAuth` Cookie 核發 + body 為轉址 scripts（文字極短）。
- 判斷登入失敗：重新回傳完整登入頁（含 `LoginStd_lblMsg` 紅字訊息）— 詳細失敗樣態列於 Phase 3 待辦。
- `UNIVWeb_SessionId` 於登入後繼續沿用；`.PaAuth` 是後續所有請求的核心憑證。

## 3. 登入後握手

1. `GET /Web/Message/default.aspx` → frameset（`MenuTree.aspx` + `Main.aspx`）
2. 之後任何模組頁（`/Web/<模組>/<代碼>Page.aspx`）直接 GET 即可，附 `.PaAuth`。

## 4. 登出（正式流程，實測）

```
POST /Web/Message/Main.aspx
Cookie: .PaAuth=…; UNIVWeb_SessionId=…; TS01f68d9a=…

__EVENTTARGET=
__EVENTARGUMENT=
__VIEWSTATEENCRYPTED=
__VIEWSTATE=<Main.aspx 頁面的值>
__VIEWSTATEGENERATOR=<Main.aspx 的值>
__EVENTVALIDATION=<Main.aspx 頁面的值>
__SCROLLPOSITIONX=0
__SCROLLPOSITIONY=0
CommonHeader:ibtLogOut.x=0
CommonHeader:ibtLogOut.y=0
```

成功回應：`<script>top.location.href='https://webap.nptu.edu.tw/Web/default.htm';</script>`

登出後驗證：以原 Cookie 再 GET 模組頁 → 只回 177 bytes 轉址殼頁，**無法再取資料**（已實測）。

## 5. Session 規則（官方明示，影響 App 設計）

1. **同一帳號只能存在一個登入 Session。**
2. 未按登出直接關閉/斷線 → 帳號遭鎖 **5 分鐘**（按官方說法；App 斷網重登需考慮此規則）。
3. App 必須：單一 Session、背景退出時嘗試正規登出、把 `.PaAuth` 存於 `flutter_secure_storage`、Session 失效時走完整重新登入流程（含驗證碼）。

## 6. 對 Flutter 實作的直接含義

- 登入 = 兩個參數化 GET（頁 + 驗證碼）+ 一個完整 Form POST；全部可在 Dio + CookieJar 實現。
- 驗證碼圖片可在 App 內顯示由使用者輸入（不需要人工測試腳本）。
- `__VIEWSTATE` 等值每天/每次載入都變，App 不能快取，需「取頁→解析→提交」動態處理。
- Web Forms 的 `ImageButton` 送出要附 `.x/.y`，缺了可能被 ViewState 判定無效（Phase 3 驗證缺省行為）。
