# NPTU 校務資料模型（Phase 1 初版）

> 依據 Phase 1 抓到的頁面結構推導；欄位名與實際 HTML 來源頁一致者列於「來源」。
> 敏感欄位在 App 內僅本地儲存、不上傳第三方。

## 1. UserInfo（個人資料，A0207SPage.aspx）

```dart
class StudentProfile {
  final String studentId;      // 學號
  final String name;           // 姓名 (中文)
  final String? englishName;   // 英文姓名（可空）
  final Gender gender;         // 1.男 2.女 3.其他
  final String idNumber;       // 身分證字號（App 內不顯示、不存記錄檔）
  final String className;      // 班級（實測值例：資訊工程學系○○○○年○班/碩士班一年級）
  final String department;     // 系所
  final int grade;             // 年級（由班級年級推導或 A卡 提供）
  final String? emergencyContact;      // 緊急聯絡人（可空 — 實測許多欄位常為未輸入）
  // …其他欄位：入學日期、費用別（公費/自費）、學籍狀態、身分別、出生日期（民國）、原住民註記等
}
```

- 來源頁含完整欄位清單（基本資料/註冊紀錄 兩個分頁，唯讀）。

## 2. Semester（學年期）

```dart
class Semester {
  final int academicYear;      // 學年度 e.g. 115
  final int term;              // 1=第1學期, 2=第2學期, 3=暑期
  String get display => '$academicYear學年度第$term學期';
}
```

- 來源：B0105S/A0515S 頁面內的學年下拉（實測含 98~115 學年全部選項）。
- A0551R 標題格式實測：`115學年 第1學期`。

## 3. CourseEntry（已選課程，A0515S 內嵌表格）

```dart
class CourseEntry {
  final String className;      // 班級 e.g. 資工碩
  final bool   dropped;        // 停開 欄位（有值者為停開）
  final String courseNo;       // 開課號 e.g. 0078
  final String subjectCode;    // 科目代碼 e.g. BFBZ001
  final String subjectName;    // 科目名稱 e.g. 專題討論(一)
  final String requiredType;   // 選修別：必/選
  final String purpose;        // 課程用途
  final double totalCredits;   // 總學分 e.g. 1.00
  final double credits;        // 學分 e.g. 1
  final String teacher;        // 授課教師（可含代碼 e.g. 歐○○(227009)）
  final String classroom;      // 上課地點 e.g. VAR教學研討室(55人)
  final String weekday;        // 星期 e.g. [1]
  final String period;         // 節次 e.g. [0506] → 第5~6節
  final String? note;          // 備註 e.g. 資工碩一必修，VAR教室
  final String? prerequisite;  // 先修科目
}
```

- 表格欄位（實測順序）：班級、停開、開課號、科目代碼、科目名稱、選修別、課程用途、總學分、學分、授課教師、上課地點、星期、節次、停休、扣考、先修科目、備註。
- 頁面同時給：`學分合計`、`停修後學分合計`、學號、姓名、班級（碩士班一年級實測在班級欄）。

## 4. CourseSchedule / TimetableSlot（課表，來源 A0551R 或未來 A0429S 資料源）

```dart
class TimetableSlot {
  final CourseEntry course;
  final int weekday;        // 1-7
  final int periodFrom;     // 起始節（由 [0506] 展開）
  final int periodTo;
}
```

- 需 Phase 3 確認最終資料源（A0551R 為 PDF 流程；A0429S 或 A0515S 的節次資料可能可直接組出課表）。

## 5. GradeRecord（歷年成績，A0809Q — PostBack 後解析）

```dart
class GradeRecord {
  final Semester semester;
  final String subjectName;
  final double credits;
  final String grade;        // 等第（A/B/C 或 數字；Phase 3 確認格式）
  final double? gradePoint;  // 績點
  final bool   closed;       // 扣考/停休 等
}
class SemesterGrades {
  final Semester semester;
  final List<GradeRecord> records;
  final double? average;     // 學期平均
  final double? gpa;
}
```

## 6. AttendanceRecord（缺曠/請假，B0105S — PostBack 後解析）

```dart
class AttendanceRecord {
  final DateTime date;
  final String courseName;
  final AttendanceType type; // 缺課/曠課/請假/公假/病假…（格式 Phase 3 確認）
  final int periodFrom;
  final int periodTo;
}
class AttendanceSummary {
  final Semester semester;
  final int total;                    // 總缺曠時數/數
  final Map<AttendanceType, int> byType;
}
```

## 6b. Announcement（系統公告，Main.aspx 的 HOTNEWS_dgData — Phase 3 實測）

```dart
class Announcement {
  final DateTime date;      // 2026/10/30 格式
  final String title;       // 公布主題
  final String category;    // 類別（實測皆為「一般公告」）
  final String unit;        // 單位（教務處/總務處/體育室…）
}
```

- 實測 Main.aspx 一次回傳 13 筆公告（含表頭）。
- 詳情頁/附件在校外公告系統，Phase 7 前調查；如有需要先用標題+單位顯示。

## 7. Auth（本地儲存模型）

```dart
class StoredAuth {
  final String account;          // flutter_secure_storage
  final String? savedPassword;   // 視使用者意願選擇是否記憶
  final String paAuthCookie;     // .PaAuth 值（加密機制由 OS 提供）
  final String sessionIdCookie;  // UNIVWeb_SessionId
  final DateTime obtainedAt;
}
```

## 8. OSC（公告）

- Phase 1 尚未定位出公告資料源；模型延後定義（多為 `title/date/category/attach` 基本）。

## 本地資料表（Drift 預規劃）

| 表 | 用途 |
|---|---|
| profiles | 最後一次取得的個人資料快取 |
| courses | 各學期課程清單快取 |
| timetable_slots | 課表展開 |
| grades | 歷年成績快取 |
| attendance | 缺曠紀錄快取 |
| refresh_meta | 各資料最後更新時間 |
| auth_state | 裝置端 Session 狀態（系統檔案由 secure_storage 儲存） |

## 資料遮蔽政策

- App 不收集、不備份、不傳送任何個人資料到學校系統之外的第三方。
- 模擬 UI 用的 example 資料僅放在本地 `example data`，由使用者於執行階段提供真實資料。
