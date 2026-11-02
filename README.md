# NPTU 校務系統 App

Flutter Android 用戶端，直接讀取國立屏東大學既有 WebForms 校務系統。使用者在裝置上輸入校務帳密與圖形驗證碼；App 不會保存密碼。登入憑證放在 Android 安全儲存區，HTTP cookies 由 CookieJar 管理。

## 已完成

- WebForms 登入、Session 綁定圖形驗證碼、登入失敗重試、正式登出與啟動時登入狀態還原。
- 首頁顯示已選課程與最新公告。
- 課表與已選課程清單使用 A0515S 資料。
- 歷年成績與出缺勤紀錄支援學期選擇。
- 公告使用 Main.aspx 的 HOTNEWS 表格；個人資料使用 A0207S 唯讀頁面，並遮蔽身分證與護照號碼欄位。
- 淺色、深色與跟隨系統主題。
- Android 網路權限與可選的 release keystore 設定。

## 執行

```powershell
flutter pub get
flutter run
```

校務資料需使用者以自己的帳號登入，並由校務系統即時提供。各資料頁有重新載入按鈕；首頁可下拉更新。

## Android 簽署

未提供發行 keystore 時，release build 使用本機 Android debug key，僅適合本機安裝與檢查。要發布更新，請在 `android/key.properties` 設定 `storeFile`、`storePassword`、`keyAlias` 和 `keyPassword`，並將 keystore 放在受控位置。這些簽署檔已加入 Git 忽略清單。

```powershell
flutter build apk --release
```
