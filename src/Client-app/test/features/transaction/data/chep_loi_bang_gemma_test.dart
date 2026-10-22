// test/features/transaction/data/chep_loi_bang_gemma_test.dart
/// C4 — chỗ duy nhất gọi Gemma chép lời. Mọi hỏng hóc → `null` (màn báo "không nghe rõ"), không ném.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flowmoney/features/ai_edge/data/datasources/slm_runtime.dart';
import 'package:flowmoney/features/ai_edge/data/huy_luot.dart';
import 'package:flowmoney/features/transaction/data/chep_loi_bang_gemma.dart';
import 'package:flowmoney/features/transaction/domain/chep_loi.dart';
import 'package:flutter_test/flutter_test.dart';

class _MoHinhGia implements SlmChepLoi {
  String tra = ' Hôm qua ăn phở 45.000. ';
  Object? nem;
  Completer<String>? treo;
  Completer<void>? huyTreo;
  String? prompt;
  final List<HuyLuot?> the = [];
  int soLanGoi = 0, soLanHuy = 0;
  @override
  Future<String> chepLoi(String duongTep, String prompt, Uint8List wav, {HuyLuot? huyLuot}) async {
    soLanGoi++;
    this.prompt = prompt;
    the.add(huyLuot);
    if (nem != null) throw nem!;
    if (treo != null) return treo!.future;
    return tra;
  }

  @override
  Future<void> huy() async {
    soLanHuy++;
    if (huyTreo != null) await huyTreo!.future;
  }
}

void main() {
  final wav = Uint8List(4);
  ChepLoiBangGemma tao(_MoHinhGia m, {bool san = true, Duration thoiHan = const Duration(seconds: 5)}) =>
      ChepLoiBangGemma(moHinh: m, sanSang: () async => san, duongTep: () async => '/m.litertlm', thoiHan: thoiHan);

  test('trả câu đã làm sạch, prompt là kPromptChepLoi', () async {
    final m = _MoHinhGia();
    expect(await tao(m).chep(wav), 'Hôm qua ăn phở 45.000');
    expect(m.prompt, kPromptChepLoi);
    expect(m.the.single, isNotNull, reason: 'mỗi lượt mang thẻ huỷ riêng');
    expect(m.the.single!.daHuy, isFalse);
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
  test('⭐ quá hạn → null, dừng đúng lượt của nó (thẻ huỷ), KHÔNG gọi huy() toàn cục', () async {
    final m = _MoHinhGia()..treo = Completer<String>();
    expect(await tao(m, thoiHan: const Duration(milliseconds: 20)).chep(wav), isNull);
    expect(m.the.single!.daHuy, isTrue);
    expect(m.soLanHuy, 0, reason: 'huy() toàn cục bỏ oan lượt khác đang chờ với moc (bẫy 4.60)');
  });
  test('I1: stopGeneration treo vẫn không kẹt hàng đợi — lượt quá hạn trả null, lượt kế tiếp gọi được mô hình', () async {
    final m = _MoHinhGia()
      ..treo = Completer<String>()
      ..huyTreo = Completer<void>();
    final c = tao(m, thoiHan: const Duration(milliseconds: 20));
    expect(await c.chep(wav).timeout(const Duration(seconds: 2)), isNull);
    m.treo = null;
    expect(await c.chep(wav).timeout(const Duration(seconds: 2)), 'Hôm qua ăn phở 45.000');
    expect(m.soLanGoi, 2);
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
  test('Q2: lượt hai chưa gọi mô hình cho tới khi lượt đầu xong (mô hình là singleton)', () async {
    final m = _MoHinhGia()..treo = Completer<String>();
    final c = tao(m);
    final f1 = c.chep(wav);
    await pumpEventQueue();
    final f2 = c.chep(wav);
    await pumpEventQueue();
    expect(m.soLanGoi, 1, reason: 'lượt hai phải xếp hàng sau lượt đầu');
    final dau = m.treo!;
    m.treo = null;
    dau.complete('một');
    expect(await f1, 'một');
    expect(await f2, 'Hôm qua ăn phở 45.000');
    expect(m.soLanGoi, 2);
  });
  test('Q1: huy() khi lượt hai đang xếp hàng → lượt hai null, mô hình chỉ được gọi 1 lần', () async {
    final m = _MoHinhGia()..treo = Completer<String>();
    final c = tao(m);
    final f1 = c.chep(wav);
    await pumpEventQueue();
    final f2 = c.chep(wav);
    await pumpEventQueue();
    await c.huy();
    m.treo!.complete('một');
    expect(await f1, isNull);
    expect(await f2, isNull);
    expect(m.soLanGoi, 1);
  });
  test('lượt mới sau huy() vẫn chờ lượt cũ và chạy bình thường', () async {
    final m = _MoHinhGia()..treo = Completer<String>();
    final c = tao(m);
    final f1 = c.chep(wav);
    await pumpEventQueue();
    await c.huy();
    final dau = m.treo!;
    m.treo = null;
    final f3 = c.chep(wav);
    await pumpEventQueue();
    expect(m.soLanGoi, 1);
    dau.complete('x');
    expect(await f1, isNull);
    expect(await f3, 'Hôm qua ăn phở 45.000');
  });
  test('sanSangChua: hàm ném → false', () async {
    final c =
        ChepLoiBangGemma(moHinh: _MoHinhGia(), sanSang: () async => throw StateError('x'), duongTep: () async => '/m');
    expect(await c.sanSangChua(), isFalse);
  });
}
