// test/features/transaction/data/chep_loi_bang_gemma_test.dart
/// C4 — chỗ duy nhất gọi Gemma chép lời. Mọi hỏng hóc → `null` (màn báo "không nghe rõ"), không ném.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flowmoney/features/ai_edge/data/slm_runtime.dart';
import 'package:flowmoney/features/transaction/data/chep_loi_bang_gemma.dart';
import 'package:flowmoney/features/transaction/domain/chep_loi.dart';
import 'package:flutter_test/flutter_test.dart';

class _MoHinhGia implements SlmChepLoi {
  String tra = ' Hôm qua ăn phở 45.000. ';
  Object? nem;
  Completer<String>? treo;
  String? prompt;
  int soLanGoi = 0, soLanHuy = 0;
  @override
  Future<String> chepLoi(String duongTep, String prompt, Uint8List wav) async {
    soLanGoi++;
    this.prompt = prompt;
    if (nem != null) throw nem!;
    if (treo != null) return treo!.future;
    return tra;
  }

  @override
  Future<void> huy() async => soLanHuy++;
}

void main() {
  final wav = Uint8List(4);
  ChepLoiBangGemma tao(_MoHinhGia m, {bool san = true, Duration thoiHan = const Duration(seconds: 5)}) =>
      ChepLoiBangGemma(moHinh: m, sanSang: () async => san, duongTep: () async => '/m.litertlm', thoiHan: thoiHan);

  test('trả câu đã làm sạch, prompt là kPromptChepLoi', () async {
    final m = _MoHinhGia();
    expect(await tao(m).chep(wav), 'Hôm qua ăn phở 45.000');
    expect(m.prompt, kPromptChepLoi);
  });
  test('chưa sẵn sàng → null, không gọi mô hình', () async {
    final m = _MoHinhGia();
    expect(await tao(m, san: false).chep(wav), isNull);
    expect(m.soLanGoi, 0);
  });
  test('mô hình ném → null', () async {
    final m = _MoHinhGia()..nem = StateError('máy không chạy được');
    expect(await tao(m).chep(wav), isNull);
  });
  test('lời rỗng → null', () async {
    final m = _MoHinhGia()..tra = '  ';
    expect(await tao(m).chep(wav), isNull);
  });
  test('quá hạn → null, engine được huỷ', () async {
    final m = _MoHinhGia()..treo = Completer<String>();
    expect(await tao(m, thoiHan: const Duration(milliseconds: 20)).chep(wav), isNull);
    expect(m.soLanHuy, 1);
  });
  test('huỷ giữa chừng → lượt ấy trả null', () async {
    final m = _MoHinhGia()..treo = Completer<String>();
    final c = tao(m);
    final f = c.chep(wav);
    await Future<void>.delayed(Duration.zero);
    await c.huy();
    m.treo!.complete('Ăn phở 45.000');
    expect(await f, isNull);
  });
  test('sanSangChua: hàm ném → false', () async {
    final c =
        ChepLoiBangGemma(moHinh: _MoHinhGia(), sanSang: () async => throw StateError('x'), duongTep: () async => '/m');
    expect(await c.sanSangChua(), isFalse);
  });
}
