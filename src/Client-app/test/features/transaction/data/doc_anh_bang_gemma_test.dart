/// `DocAnhBangGemma` — chỗ DUY NHẤT ảnh quét gọi mô hình nhìn ảnh. Mọi đường hỏng trả `null` (màn dùng luật); không
/// đường nào ném ra màn hay treo màn quá thời hạn.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flowmoney/features/ai_edge/data/datasources/slm_runtime.dart';
import 'package:flowmoney/features/ai_edge/data/huy_luot.dart';
import 'package:flowmoney/features/transaction/data/doc_anh_bang_gemma.dart';
import 'package:flowmoney/features/transaction/domain/doc_anh_gemma.dart';
import 'package:flutter_test/flutter_test.dart';

class _MoHinhGia implements SlmDocAnh {
  _MoHinhGia(this.tra);
  final Future<String> Function() tra;
  final List<String> prompt = [];
  final List<HuyLuot?> the = [];
  int soLanHuy = 0;

  @override
  Future<String> docAnh(String duongTep, String p, Uint8List anh, {HuyLuot? huyLuot}) {
    prompt.add(p);
    the.add(huyLuot);
    return tra();
  }

  @override
  Future<void> huy() async => soLanHuy++;
}

void main() {
  final anh = Uint8List.fromList([1, 2, 3]);
  DocAnhBangGemma gemma(_MoHinhGia m, {bool sanSang = true, Duration thoiHan = const Duration(seconds: 5)}) =>
      DocAnhBangGemma(
        moHinh: m,
        sanSang: () async => sanSang,
        duongTep: () async => '/gia/gemma.litertlm',
        thoiHan: thoiHan,
      );

  test('đọc được → tổng + món; câu hỏi gửi đi là kPromptMonTong', () async {
    final m = _MoHinhGia(() async => '```json {"mon": [{"ten": "A", "tien": "5,000"}], "tong": "75,700"} ```');
    final kq = await gemma(m).doc(anh);
    expect(kq!.tong, 75700);
    expect(kq.mon.single.soTien, 5000);
    expect(m.prompt, [kPromptMonTong]);
    expect(m.the.single, isNotNull, reason: 'mỗi lượt mang thẻ huỷ riêng — hết giờ mới có chỗ dừng đúng lượt');
    expect(m.the.single!.daHuy, isFalse, reason: 'lượt trả bình thường thì thẻ không bị huỷ');
  });

  test('chưa sẵn sàng (chưa tải mô hình / tắt công tắc) → null, không gọi mô hình', () async {
    final m = _MoHinhGia(() async => '{"tong": 1000}');
    expect(await gemma(m, sanSang: false).doc(anh), isNull);
    expect(m.prompt, isEmpty);
  });

  test('mô hình ném (máy không chạy được) → null', () async {
    expect(await gemma(_MoHinhGia(() async => throw StateError('arm64'))).doc(anh), isNull);
  });

  test('chữ không phải JSON → null', () async {
    expect(await gemma(_MoHinhGia(() async => 'không đọc được')).doc(anh), isNull);
  });

  test('⭐ quá thời hạn → null, DỪNG đúng lượt của nó (thẻ huỷ), KHÔNG gọi huy() toàn cục', () async {
    final m = _MoHinhGia(() => Completer<String>().future);
    expect(await gemma(m, thoiHan: const Duration(milliseconds: 20)).doc(anh), isNull);
    expect(m.the.single!.daHuy, isTrue);
    expect(m.soLanHuy, 0,
        reason: 'huy() toàn cục tăng bộ đếm chung của BoNapMoHinh — bỏ oan lượt khác đang chờ với moc (bẫy 4.60)');
  });

  test('⭐ bấm Huỷ giữa chừng → null kể cả khi mô hình trả chữ hợp lệ sau đó', () async {
    final xong = Completer<String>();
    final m = _MoHinhGia(() => xong.future);
    final g = gemma(m);
    final f = g.doc(anh);
    await g.huy();
    xong.complete('{"mon": [], "tong": 50000}');
    expect(await f, isNull);
    expect(m.soLanHuy, 1);
  });
}
