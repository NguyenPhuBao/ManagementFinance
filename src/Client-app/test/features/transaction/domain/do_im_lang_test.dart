// test/features/transaction/domain/do_im_lang_test.dart
/// C4 §2.1 — lối Gemma ghi âm tự dừng khi người dùng im ~2 giây (sau khi đã nói), hoặc chưa nói gì sau 6 giây, hoặc đủ
/// 20 giây. ⚠️ Ngưỡng dBFS chưa đo trên máy (spec mục 9).
library;

import 'package:flowmoney/features/transaction/domain/do_im_lang.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  bool chay(List<double> mau) {
    final b = BoDoIm();
    for (var i = 0; i < mau.length; i++) {
      if (b.them(mau[i], kNhipBienDo * (i + 1))) return true;
    }
    return false;
  }

  test('nói rồi im đủ 2 giây → dừng', () {
    expect(chay([...List.filled(5, -20.0), ...List.filled(20, -50.0)]), isTrue);
  });
  test('nói rồi im 1,9 giây → chưa dừng', () {
    expect(chay([...List.filled(5, -20.0), ...List.filled(19, -50.0)]), isFalse);
  });
  test('im giữa hai đoạn nói (ngắn hơn 2 giây) → chưa dừng', () {
    expect(chay([...List.filled(5, -20.0), ...List.filled(10, -50.0), ...List.filled(5, -20.0)]), isFalse);
  });
  test('chưa nói gì: dừng ở giây thứ 6, không trước', () {
    expect(chay(List.filled(59, -60.0)), isFalse);
    expect(chay(List.filled(60, -60.0)), isTrue);
  });
  test('nói liên tục: dừng ở giây thứ 20', () {
    expect(chay(List.filled(199, -20.0)), isFalse);
    expect(chay(List.filled(200, -20.0)), isTrue);
  });
}
