/// A5 — Huỷ ở pha AI đóng màn Quét NGAY (người dùng duyệt 2026-10-22): lượt đọc ảnh native không ngắt được tức thì
/// (Realme CPU: huỷ 14:23:53, native trả 14:23:58) nên nó chạy nốt ở nền; lời gọi mô hình kế tiếp phải CHỜ nó — một bản
/// mô hình, hai lượt chồng nhau trên engine là vùng chưa đo.
library;

import 'dart:async';
import 'dart:io';

import 'package:flowmoney/features/ai_edge/data/luot_khong_ngat_duoc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('không có lượt nào đang chạy → cho() xong ngay', () async {
    var xong = false;
    unawaited(LuotKhongNgatDuoc().cho().then((_) => xong = true));
    await pumpEventQueue();
    expect(xong, isTrue);
  });

  test('⭐ cho() chỉ xong SAU KHI lượt đang chạy xong', () async {
    final l = LuotKhongNgatDuoc();
    final nativ = Completer<String>();
    final luot = l.chay(() => nativ.future);
    var daCho = false;
    unawaited(l.cho().then((_) => daCho = true));
    await pumpEventQueue();
    expect(daCho, isFalse, reason: 'lượt đọc ảnh còn chạy ở nền — lời gọi mới không được chồng lên');
    nativ.complete('kq');
    expect(await luot, 'kq');
    await pumpEventQueue();
    expect(daCho, isTrue);
  });

  test('lượt ném lỗi → chay() ném lại cho người gọi, cho() vẫn xong và không ném', () async {
    final l = LuotKhongNgatDuoc();
    final nativ = Completer<String>();
    final luot = l.chay(() => nativ.future);
    final cho = l.cho();
    nativ.completeError(StateError('native hỏng'));
    await expectLater(luot, throwsStateError);
    await expectLater(cho, completes);
  });

  test('⭐ hai lượt gọi liền nhau chạy NỐI TIẾP, không bao giờ chồng', () async {
    final l = LuotKhongNgatDuoc();
    var dangChay = 0;
    var dinh = 0;
    Future<int> mot(int i) async {
      dangChay++;
      if (dangChay > dinh) dinh = dangChay;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      dangChay--;
      return i;
    }

    final kq = await Future.wait([l.chay(() => mot(1)), l.chay(() => mot(2)), l.chay(() => mot(3))]);
    expect(kq, [1, 2, 3]);
    expect(dinh, 1);
  });

  test('cho() đang đợi lượt A thì đợi luôn lượt B vừa vào hàng trước nó', () async {
    final l = LuotKhongNgatDuoc();
    final a = Completer<void>(), b = Completer<void>();
    unawaited(l.chay(() => a.future));
    unawaited(l.chay(() => b.future));
    var daCho = false;
    unawaited(l.cho().then((_) => daCho = true));
    a.complete();
    await pumpEventQueue();
    expect(daCho, isFalse, reason: 'B đã vào chạy sau A — cho() phải đợi cả B');
    b.complete();
    await pumpEventQueue();
    expect(daCho, isTrue);
  });

  // Vùng `flutter test` mù: `SlmRuntimeThat` gọi `flutter_gemma` thật, không dựng được trên x86. Canh nối dây bằng đọc mã
  // (khuôn các `*_noi_day_test`): năm lối SINH chờ / chạy qua `_luotAnh`; `huy` và `dong` thì KHÔNG — `huy` chờ là Huỷ kẹt
  // tới khi lượt cũ xong, `dong` chờ là khoá chết (`docAnh` → `_boNap.can` → `dong`).
  group('nối dây trong slm_runtime.dart', () {
    final nguon = File('lib/features/ai_edge/data/datasources/slm_runtime.dart').readAsStringSync();
    final lop = nguon.substring(nguon.indexOf('class SlmRuntimeThat'), nguon.indexOf('class _PhienThat'));

    String than(String chuKy) {
      final i = lop.indexOf(chuKy);
      expect(i, isNonNegative, reason: 'không thấy "$chuKy" trong SlmRuntimeThat');
      final j = lop.indexOf('@override', i);
      return lop.substring(i, j < 0 ? lop.length : j);
    }

    for (final chuKy in [
      'Future<String> sinh(',
      'Stream<String> sinhDan(',
      'Future<PhienCongCu> moPhien(',
      'Future<String> chepLoi(',
    ]) {
      test('$chuKy chờ lượt đọc ảnh cũ', () => expect(than(chuKy), contains('await _luotAnh.cho()')));
    }
    test('docAnh chạy qua _luotAnh.chay', () => expect(than('Future<String> docAnh('), contains('_luotAnh.chay(')));
    for (final chuKy in ['Future<void> huy()', 'Future<void> dong()']) {
      test('$chuKy KHÔNG chờ', () => expect(than(chuKy), isNot(contains('_luotAnh'))));
    }
  });
}
