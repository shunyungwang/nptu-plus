// 節次標籤：校務系統實際出現的各種寫法都要轉成區間。
import 'package:flutter_test/flutter_test.dart';
import 'package:nptu_campus/core/utils/period_format.dart';

void main() {
  test('單節', () {
    expect(formatPeriodRange('05'), '5 節');
    expect(formatPeriodRange('2'), '2 節');
  });

  test('連續節次（首頁先前顯示 20304 / 50607 的情況）', () {
    expect(formatPeriodRange('2,03,04'), '2–4 節');
    expect(formatPeriodRange('20304'), '2–4 節');
    expect(formatPeriodRange('020304'), '2–4 節');
    expect(formatPeriodRange('5,06,07'), '5–7 節');
    expect(formatPeriodRange('50607'), '5–7 節');
    expect(formatPeriodRange('0607'), '6–7 節');
  });

  test('不連續節次以逗號分隔', () {
    expect(formatPeriodRange('2'), '2 節');
    expect(formatPeriodRange('2,5'), '2, 5 節');
    expect(formatPeriodRange('01,02,03,05'), '1–3, 5 節');
  });

  test('非數字節次與空值', () {
    expect(formatPeriodRange('M'), 'M 節');
    expect(formatPeriodRange(' n '), 'N 節');
    expect(formatPeriodRange(''), '—');
    expect(formatPeriodRange('  '), '—');
    expect(formatPeriodRange('abc'), '—');
  });
}
