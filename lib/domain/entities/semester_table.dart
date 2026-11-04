/// 學期選單與表格資料（成績／出缺勤共用的通用結構）。
library;

class SemesterOption {
  const SemesterOption(this.value, this.label);

  final String value;
  final String label;
}

/// 一個學期的表格資料：可選學期、目前選取學期、表頭與資料列。
class SemesterTable {
  const SemesterTable({
    required this.semesters,
    required this.selected,
    required this.rows,
    this.headers = const [],
  });

  final List<SemesterOption> semesters;
  final String selected;
  final List<List<String>> rows;
  final List<String> headers;
}
