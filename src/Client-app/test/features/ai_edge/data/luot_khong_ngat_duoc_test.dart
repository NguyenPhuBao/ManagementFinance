/// A5 — Huỷ ở pha AI đóng màn Quét NGAY (người dùng duyệt 2026-10-22): lượt đọc ảnh native không ngắt được tức thì
/// (Realme CPU: huỷ 14:23:53, native trả 14:23:58) nên nó chạy nốt ở nền; lời gọi mô hình kế tiếp phải CHỜ nó — một bản
/// mô hình, hai lượt chồng nhau trên engine là vùng chưa đo.
library;

import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flowmoney/features/ai_edge/data/luot_khong_ngat_duoc.dart';
import 'package:flowmoney/features/transaction/data/chep_loi_bang_gemma.dart';
import 'package:flowmoney/features/transaction/data/doc_anh_bang_gemma.dart';
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

  // ⚠️ Chỉ đúng khi B vào hàng TRƯỚC lời gọi cho(): ai đợi trước thì chạy tiếp trước (thứ tự microtask). Gọi cho() trước
  // rồi mới chay(B) thì cho() có thể xong ngay khi A xong, chạy song song với B — giới hạn ghi ở bẫy 4.60.
  test('cho() đang đợi lượt A thì đợi luôn lượt B đã vào hàng TRƯỚC nó', () async {
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

  // Trần chờ (phát hiện code-review 2026-10-22): lượt native TREO thì năm lối sinh không được treo theo — hết trần, lượt
  // mới ném để người gọi rơi về luật / mẫu câu như khi mô hình hỏng. Chạy dưới FakeAsync: không bao giờ treo, chỉ đỏ.
  group('trần chờ lượt cũ', () {
    const motGiay = Duration(seconds: 1);

    test('⭐ lượt cũ không xong trong kTranChoLuotCu → cho() ném LuotCuChuaXong, không đợi mãi', () {
      fakeAsync((fa) {
        final l = LuotKhongNgatDuoc();
        unawaited(l.chay(() => Completer<void>().future));
        final cho = _theoDoi(l.cho());
        fa.elapse(kTranChoLuotCu - motGiay);
        expect((cho.xong, cho.loi), (false, null), reason: 'chưa tới trần — còn đợi');
        fa.elapse(motGiay);
        expect(cho.loi, isA<LuotCuChuaXong>(), reason: 'lượt native treo thì Trợ lý / Nhập nhanh / Nói kẹt mãi');
        expect(cho.xong, isFalse);
      });
    });

    test('⭐ chay() của lượt sau cũng có trần — và KHÔNG chạy lượt của nó khi lượt cũ còn giữ chỗ', () {
      fakeAsync((fa) {
        final l = LuotKhongNgatDuoc();
        unawaited(l.chay(() => Completer<void>().future));
        var daChay = false;
        final sau = _theoDoi(l.chay(() async => daChay = true));
        fa.elapse(kTranChoLuotCu);
        expect(sau.loi, isA<LuotCuChuaXong>(), reason: 'docAnh thứ hai sau lượt treo cũng phải rơi về luật');
        expect(daChay, isFalse, reason: 'quá trần KHÔNG giải phóng chỗ — chạy là hai lượt chồng nhau trên engine');
      });
    });

    test('lượt đã quá trần một lần → lời gọi sau ném NGAY; lượt ấy xong thì về bình thường', () {
      fakeAsync((fa) {
        final l = LuotKhongNgatDuoc();
        final treo = Completer<void>();
        unawaited(l.chay(() => treo.future));
        _theoDoi(l.cho());
        fa.elapse(kTranChoLuotCu);

        final sau = _theoDoi(l.cho());
        fa.flushMicrotasks();
        expect(sau.loi, isA<LuotCuChuaXong>(), reason: 'mỗi lời gọi đợi thêm một trần nữa là mỗi câu hỏi chờ trọn một trần');

        treo.complete();
        fa.flushMicrotasks();
        final cho = _theoDoi(l.cho());
        var daChay = false;
        _theoDoi(l.chay(() async => daChay = true));
        fa.flushMicrotasks();
        expect((cho.xong, daChay), (true, true), reason: 'lượt treo đã trả — không được kẹt ở trạng thái "quá trần"');
      });
    });

    test('trần tính từ lúc BẮT ĐẦU đợi, cộng dồn qua lượt nối sau', () {
      fakeAsync((fa) {
        final l = LuotKhongNgatDuoc();
        final a = Completer<void>();
        unawaited(l.chay(() => a.future));
        unawaited(l.chay(() => Completer<void>().future));
        final cho = _theoDoi(l.cho());
        fa.elapse(kTranChoLuotCu - motGiay * 5);
        a.complete();
        fa.elapse(motGiay * 5);
        expect(cho.loi, isA<LuotCuChuaXong>(), reason: 'mỗi lượt nối sau một trần mới là đợi không giới hạn');
      });
    });

    test('lượt cũ xong trước trần → cho() xong, không còn hẹn giờ treo lại', () {
      fakeAsync((fa) {
        final l = LuotKhongNgatDuoc();
        final a = Completer<void>();
        unawaited(l.chay(() => a.future));
        final cho = _theoDoi(l.cho());
        fa.elapse(motGiay);
        a.complete();
        fa.flushMicrotasks();
        expect(cho.xong, isTrue);
        expect(fa.pendingTimers, isEmpty, reason: 'hẹn giờ sót lại làm widget test đỏ "Timer is still pending"');
      });
    });

    test('không phải đợi → không dựng hẹn giờ', () {
      fakeAsync((fa) {
        final l = LuotKhongNgatDuoc();
        _theoDoi(l.cho());
        _theoDoi(l.chay<void>(() async {}));
        fa.flushMicrotasks();
        expect(fa.pendingTimers, isEmpty);
      });
    });

    test('⭐ trần chờ ≥ gấp đôi lúc lượt bị Huỷ còn giữ chỗ, ≤ 20 s (người dùng chốt), NGẮN HƠN trần hai lớp bọc', () {
      // Ngắn hơn: lượt đang chờ tự ném trước khi `.timeout` của lớp bọc tới — lớp bọc không cắt một lượt còn đứng trong
      // `cho()` (thẻ `HuyLuot` của lượt chỉ được xét sau pha nạp, nên cắt lúc ấy có thể nạp mô hình vô ích).
      expect(kTranChoLuotCu, lessThan(kThoiHanChepLoi));
      expect(kTranChoLuotCu, lessThan(kThoiHanDocAnhGemma));
      // Ca THƯỜNG: lượt đọc ảnh bị Huỷ còn giữ chỗ tới hết pha nạp (nạp lạnh Realme CPU 1,3–9,2 s) hoặc hết prefill ảnh
      // (Realme 2026-10-22: chạy nốt 5–7 s sau Huỷ, cả lượt ≤ 8,7 s). Trần ngắn hơn là Huỷ rồi Quét / Nói ngay rơi về luật oan.
      expect(kTranChoLuotCu, greaterThanOrEqualTo(const Duration(milliseconds: 2 * 9200)),
          reason: 'trần phải che ca thường với biên gấp đôi');
      // Trần chạm khi lượt cũ chạy TRỌN (lệnh dừng hỏng — đo 55,9 s một lượt) hoặc Huỷ giữa lần nạp CPU đầu tiên sau cài đặt
      // (27,2 s) — người dùng chốt 2026-10-22 không bắt chờ tới đó, rơi về luật sau 20 s.
      expect(kTranChoLuotCu, lessThanOrEqualTo(const Duration(seconds: 20)),
          reason: 'người dùng chốt: ca lệnh dừng hỏng chờ tối đa 20 s');
    });
  });

  // Vùng `flutter test` mù: `SlmRuntimeThat` gọi `flutter_gemma` thật, không dựng được trên x86. Canh nối dây bằng đọc mã
  // (khuôn các `*_noi_day_test`): năm lối SINH chờ / chạy qua `_luotAnh`; `huy`, `dong`, `moHinhSan` thì KHÔNG — `huy` chờ
  // là Huỷ kẹt tới khi lượt cũ xong, `dong` / `moHinhSan` chờ là khoá chết (`docAnh` → `_boNap.can` → `dong`).
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
    /// [a] có mặt và đứng TRƯỚC [b] trong [t].
    void truoc(String t, String a, String b, String lyDo) {
      expect(t.indexOf(a), isNonNegative, reason: 'không thấy "$a"');
      expect(t.indexOf(b), isNonNegative, reason: 'không thấy "$b"');
      expect(t.indexOf(a), lessThan(t.indexOf(b)), reason: lyDo);
    }

    // `moc` ghi SAU khi chờ thì Huỷ bấm lúc đang chờ lượt cũ không bỏ được lượt này: nó nạp / sinh như chưa từng bị huỷ.
    for (final chuKy in [
      'Future<String> docAnh(',
      'Future<String> chepLoi(',
      'Future<String> sinh(',
      'Stream<String> sinhDan(',
      'Future<PhienCongCu> moPhien(',
    ]) {
      test('$chuKy ghi moc TRƯỚC khi chờ lượt cũ', () {
        truoc(than(chuKy), 'final moc = _boNap.moc;', '_luotAnh.', 'moc phải ghi trước lời chờ _luotAnh');
      });
    }
    // Ba lối chữ không qua `_boNap.can(moc:)` — tự kiểm ngay sau khi chờ (Huỷ của Nhập nhanh / C3 / danh mục quét tới qua
    // `PhienMotLoiGoi.huy` → `huy()` toàn cục).
    for (final chuKy in ['Future<String> sinh(', 'Stream<String> sinhDan(', 'Future<PhienCongCu> moPhien(']) {
      test('$chuKy bỏ lượt khi bị huỷ lúc đang chờ — không tạo chat', () {
        final t = than(chuKy);
        truoc(t, 'await _luotAnh.cho();', 'if (_boNap.moc != moc) throw const LuotNapBiHuy();', 'kiểm sau khi chờ');
        truoc(t, 'if (_boNap.moc != moc) throw const LuotNapBiHuy();', 'createChat(', 'kiểm trước khi tạo chat');
      });
    }
    // Hết giờ của lớp bọc đi bằng thẻ của lượt: sau pha nạp không tạo chat, sau khi tạo chat thì dừng CHÍNH chat ấy.
    for (final chuKy in ['Future<String> docAnh(', 'Future<String> chepLoi(']) {
      test('$chuKy theo thẻ huỷ của lượt — bỏ sau pha nạp, dừng đúng chat của mình', () {
        final t = than(chuKy);
        truoc(t, '_boNap.can(', 'if (huyLuot?.daHuy ?? false) throw const LuotNapBiHuy();', 'kiểm thẻ sau pha nạp');
        truoc(t, 'if (huyLuot?.daHuy ?? false) throw const LuotNapBiHuy();', 'createChat(', 'kiểm thẻ trước khi tạo chat');
        truoc(t, 'createChat(', 'huyLuot?.tin.then((_) => _dungChat(chat))', 'nghe thẻ sau khi có chat');
      });
    }
    // Khe Huỷ (2026-10-22, người dùng chọn vá): `huy()` chỉ dừng được chat đã gán vào `_chatDangSinh` — Huỷ tới trong lúc
    // `createChat` đang chạy thì không có gì để dừng, lượt chạy TRỌN (đọc ảnh 23–56 s trên Realme CPU) và giữ chỗ tới hết.
    // Xét lại ngay khi có chat: trước khi gửi ảnh / câu (gửi rồi là prefill đã chạy) và trước khi gán `_chatDangSinh`.
    for (final chuKy in [
      'Future<String> docAnh(',
      'Future<String> chepLoi(',
      'Future<String> sinh(',
      'Stream<String> sinhDan(',
      'Future<PhienCongCu> moPhien(',
    ]) {
      test('$chuKy xét lại Huỷ SAU khi tạo chat, trước khi gửi', () {
        final t = than(chuKy);
        final tao = t.indexOf('createChat(');
        final gui = t.indexOf('addQueryChunk(');
        final kiem = t.indexOf('_boNap.moc != moc', tao);
        expect(tao, isNonNegative);
        expect(kiem, greaterThan(tao), reason: 'thiếu phép xét bộ đếm Huỷ sau createChat — Huỷ lúc đang tạo chat bị nuốt');
        expect(kiem, lessThan(gui), reason: 'xét sau khi đã gửi thì prefill đã chạy');
        final gan = t.indexOf('_chatDangSinh = chat');
        if (gan >= 0) expect(kiem, lessThan(gan), reason: 'gán rồi mới ném là để lại chat chết trong _chatDangSinh');
      });
    }
    for (final chuKy in ['Future<String> docAnh(', 'Future<String> chepLoi(']) {
      test('$chuKy xét lại thẻ HuyLuot SAU khi tạo chat, trước khi gửi', () {
        final t = than(chuKy);
        final tao = t.indexOf('createChat(');
        final kiem = t.indexOf('huyLuot?.daHuy', tao);
        expect(kiem, greaterThan(tao), reason: 'hết giờ lúc đang tạo chat thì đừng gửi ảnh / âm rồi mới dừng');
        expect(kiem, lessThan(t.indexOf('addQueryChunk(')));
      });
    }
    // Lối A (người dùng chốt 2026-10-22): Huỷ pha AI màn Quét gọi `huy()` hai lần song song trên cùng chat đọc ảnh — native
    // chỉ được nhận một `stopGeneration` mỗi lúc (`GopLuotDung`, test hành vi ở `gop_luot_dung_test`).
    test('_dungChat gộp lời dừng trùng — stopGeneration chỉ gọi bên trong _gopDung.dung', () {
      final t = than('Future<void> _dungChat(');
      truoc(t, '_gopDung.dung(chat,', 'chat.stopGeneration()', 'stopGeneration phải nằm trong lời gọi gộp');
      expect('.stopGeneration('.allMatches(lop).length, 1,
          reason: 'SlmRuntimeThat chỉ dừng chat qua _dungChat — lời stopGeneration thứ hai là lối đi vòng qua lớp gộp');
      expect(t, contains("'[SLM] gộp lời dừng trùng"), reason: 'logcat cần một dòng CÓ MẶT khi gộp (debugPrint bị tiết lưu)');
    });
    for (final chuKy in ['Future<void> huy()', 'Future<void> dong()', 'Future<void> moHinhSan(']) {
      test('$chuKy KHÔNG chờ', () => expect(than(chuKy), isNot(contains('_luotAnh'))));
    }
  });
}

/// Kết quả của một Future dưới FakeAsync — đọc được giữa chừng, và lỗi được bắt (không lọt thành lỗi chưa xử lý của zone).
class _KetQua {
  var xong = false;
  Object? loi;
}

_KetQua _theoDoi(Future<Object?> f) {
  final k = _KetQua();
  f.then((_) {
    k.xong = true;
  }, onError: (Object e) {
    k.loi = e;
  });
  return k;
}
