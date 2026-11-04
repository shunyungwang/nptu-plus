/// 校務系統的節次欄位格式並不統一，實際出現過：
///
/// - `05`（單節）
/// - `0607`（連續兩節，無分隔）
/// - `20304`／`020304`（以逗號分隔但被去掉分隔後）
/// - `2,03,04`（逗號分隔，第一段沒有補零）
/// - `M`／`N`／`A`（非數字節次）
///
/// 這裡統一轉成易讀標籤，避免出現 `20304 節` 這種把代碼串起來的結果。
String formatPeriodRange(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '—';

  final numbers = _periodNumbers(value);
  if (numbers.isEmpty) {
    // 非數字節次（M/N/A…）：單一字母才顯示，其餘視為無法辨識。
    return RegExp(r'^[A-Za-z]$').hasMatch(value)
        ? '${value.toUpperCase()} 節'
        : '—';
  }

  final ranges = <String>[];
  var start = numbers.first;
  var previous = start;
  for (final number in numbers.skip(1)) {
    if (number == previous + 1) {
      previous = number;
      continue;
    }
    ranges.add(start == previous ? '$start' : '$start–$previous');
    start = number;
    previous = number;
  }
  ranges.add(start == previous ? '$start' : '$start–$previous');
  return '${ranges.join(', ')} 節';
}

/// 取出節次編號（去重、排序）。
///
/// 只有一段且長度超過 2 時，代表分隔符被去掉了（`20304`），
/// 由右往左每兩個字元切一段：`2|03|04`。
List<int> _periodNumbers(String raw) {
  var tokens = raw
      .split(RegExp(r'[^0-9]+'))
      .where((token) => token.isNotEmpty)
      .toList();
  if (tokens.isEmpty) return const <int>[];

  if (tokens.length == 1 && tokens.single.length > 2) {
    final digits = tokens.single;
    final chunks = <String>[];
    for (var end = digits.length; end > 0; end -= 2) {
      chunks.insert(0, digits.substring(end - 2 < 0 ? 0 : end - 2, end));
    }
    tokens = chunks;
  }

  return tokens
      .map(int.tryParse)
      .whereType<int>()
      .where((period) => period > 0 && period < 100)
      .toSet()
      .toList()
    ..sort();
}
