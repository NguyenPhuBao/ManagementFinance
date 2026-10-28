import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Công tắc [sw] (finder trỏ vào chính `Switch`) đang vẽ DẠNG KHOÁ theo quyền — G111, Stitch `68593384…`: mờ 50 %
/// (`Opacity` bọc ngoài), ổ khoá trong núm, không chạm được. Ba vế phải cùng đúng: chỉ `onChanged == null` là công tắc
/// bị khoá mà trông y hệt công tắc mở (màu đặt cứng thắng màu khoá mặc định — đo 2026-10-28).
bool laCongTacKhoa(WidgetTester tester, Finder sw) {
  final s = tester.widget<Switch>(sw);
  final mo = find.ancestor(
      of: sw, matching: find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0.5));
  final icon = s.thumbIcon?.resolve({WidgetState.disabled, if (s.value) WidgetState.selected});
  return s.onChanged == null && mo.evaluate().isNotEmpty && icon?.icon == Icons.lock;
}
