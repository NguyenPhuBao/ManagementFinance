/// `GopLuotDung` — gộp các lời dừng CÙNG LÚC vào một chat thành một lời gọi `stopGeneration` native (bẫy 4.60, lối A
/// người dùng chốt 2026-10-22): Huỷ pha AI màn Quét gọi cả `_docGemma.huy()` lẫn `_docDanhMuc.huy()` → hai lần
/// `runtime.huy()` → hai lần dừng song song trên cùng chat đọc ảnh, mà OnePlus GPU từng sập ở lời gọi native lặp.
library;

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flowmoney/features/ai_edge/data/gop_luot_dung.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('⭐ hai lời dừng cùng lúc → MỘT lời gọi; cả hai xong khi lời gọi ấy xong', () {
    fakeAsync((fa) {
      final g = GopLuotDung<Object>();
      final chat = Object();
      final native = Completer<void>();
      var soLan = 0;
      Future<void> goi() {
        soLan++;
        return native.future;
      }

      final a = _theoDoi(g.dung(chat, goi));
      final b = _theoDoi(g.dung(chat, goi));
      fa.flushMicrotasks();
      expect(soLan, 1, reason: 'lời dừng thứ hai phải dùng chung lượt đang dừng, không gọi native lần hai');
      expect((a.xong, b.xong), (false, false), reason: 'chưa ai xong khi native chưa trả');
      native.complete();
      fa.flushMicrotasks();
      expect((a.xong, b.xong), (true, true));
    });
  });

  test('dangDung đúng trong lúc dừng, hết sau khi xong', () {
    fakeAsync((fa) {
      final g = GopLuotDung<Object>();
      final chat = Object();
      final native = Completer<void>();
      expect(g.dangDung(chat), isFalse);
      _theoDoi(g.dung(chat, () => native.future));
      expect(g.dangDung(chat), isTrue);
      native.complete();
      fa.flushMicrotasks();
      expect(g.dangDung(chat), isFalse);
    });
  });

  test('⭐ lời dừng SAU khi lượt trước đã xong → gọi lại (bấm Huỷ lần nữa vẫn thử dừng)', () {
    fakeAsync((fa) {
      final g = GopLuotDung<Object>();
      final chat = Object();
      var soLan = 0;
      _theoDoi(g.dung(chat, () async => soLan++));
      fa.flushMicrotasks();
      _theoDoi(g.dung(chat, () async => soLan++));
      fa.flushMicrotasks();
      expect(soLan, 2, reason: 'chỉ gộp lời dừng CÙNG LÚC — giữ lượt đã xong là lần dừng hỏng không bao giờ thử lại');
    });
  });

  test('lỗi tới MỌI người chờ, và lượt hỏng không giữ chỗ', () {
    fakeAsync((fa) {
      final g = GopLuotDung<Object>();
      final chat = Object();
      final native = Completer<void>();
      final a = _theoDoi(g.dung(chat, () => native.future));
      final b = _theoDoi(g.dung(chat, () => native.future));
      native.completeError(StateError('hỏng'));
      fa.flushMicrotasks();
      expect(a.loi, isA<StateError>());
      expect(b.loi, isA<StateError>(), reason: 'người gộp vào cũng phải thấy lỗi');
      expect(g.dangDung(chat), isFalse);
    });
  });

  test('lời gọi ném ĐỒNG BỘ vẫn tới mọi người chờ và không giữ chỗ', () {
    fakeAsync((fa) {
      final g = GopLuotDung<Object>();
      final chat = Object();
      final a = _theoDoi(g.dung(chat, () => throw StateError('ném ngay')));
      fa.flushMicrotasks();
      expect(a.loi, isA<StateError>());
      expect(g.dangDung(chat), isFalse);
    });
  });

  test('hai chat khác nhau không gộp', () {
    fakeAsync((fa) {
      final g = GopLuotDung<Object>();
      final native = Completer<void>();
      var soLan = 0;
      Future<void> goi() {
        soLan++;
        return native.future;
      }

      _theoDoi(g.dung(Object(), goi));
      _theoDoi(g.dung(Object(), goi));
      fa.flushMicrotasks();
      expect(soLan, 2);
    });
  });

  test('so khoá theo ĐỊNH DANH, không theo ==', () {
    fakeAsync((fa) {
      final g = GopLuotDung<_BangNhau>();
      final native = Completer<void>();
      var soLan = 0;
      Future<void> goi() {
        soLan++;
        return native.future;
      }

      _theoDoi(g.dung(_BangNhau(), goi));
      _theoDoi(g.dung(_BangNhau(), goi));
      fa.flushMicrotasks();
      expect(soLan, 2, reason: 'hai chat native khác nhau mà == bằng nhau vẫn phải dừng riêng');
    });
  });
}

/// Mọi bản đều `==` nhau — canh việc so khoá theo định danh.
class _BangNhau {
  @override
  bool operator ==(Object other) => other is _BangNhau;

  @override
  int get hashCode => 0;
}

/// Kết quả của một Future dưới FakeAsync — đọc được giữa chừng, và lỗi được bắt (không lọt thành lỗi chưa xử lý của zone).
class _KetQua {
  var xong = false;
  Object? loi;
}

_KetQua _theoDoi(Future<void> f) {
  final k = _KetQua();
  f.then((_) {
    k.xong = true;
  }, onError: (Object e) {
    k.loi = e;
  });
  return k;
}
