/// `PhienMotLoiGoi` — vòng đời phiên của Nhập nhanh (C2) và lệnh tạo (C3).
library;

import 'dart:async';

import 'package:flowmoney/features/ai_edge/data/datasources/phien_cong_cu.dart';
import 'package:flowmoney/features/ai_edge/data/phien_mot_loi_goi.dart';
import 'package:flowmoney/features/ai_edge/data/datasources/slm_runtime.dart';
import 'package:flowmoney/features/ai_edge/domain/cong_cu.dart';
import 'package:flutter_test/flutter_test.dart';

class _RuntimeGia implements SlmRuntime {
  bool _san = false;
  int soLanNap = 0;
  int soLanHuy = 0;

  @override
  bool get dangSan => _san;

  @override
  Future<void> moHinhSan(String duongTep) async {
    soLanNap++;
    _san = true;
  }

  @override
  Future<PhienCongCu> moPhien({
    required String heThong,
    required String cauHoi,
    required List<KhaiBaoCongCu> congCu,
  }) async {
    if (!_san) throw StateError('Mô hình chưa nạp');
    return PhienCongCuGia([
      [const GoiCongCu('dien', {'a': 1})],
    ]);
  }

  @override
  Future<String> sinh(String prompt, {int tranToken = 0}) => throw UnimplementedError();
  @override
  Stream<String> sinhDan(String prompt, {int tranToken = 0}) => throw UnimplementedError();
  @override
  Future<void> huy() async => soLanHuy++;
  @override
  Future<void> dong() async => _san = false;
}

void main() {
  test('⭐ mô hình bị ĐÓNG giữa hai lượt (màn Quét đọc ảnh xong thì đóng) → lượt sau nạp lại, không im lặng trả null',
      () async {
    final rt = _RuntimeGia();
    final p = PhienMotLoiGoi(
      runtime: rt,
      sanSang: () async => true,
      duongTep: () async => '/gia/gemma.litertlm',
      thoiHan: const Duration(seconds: 5),
      nhan: '[test]',
    );
    Future<GoiCongCu?> goi() =>
        p.goiDauTien(heThong: 'h', cauHoi: 'c', congCu: const [], laDich: (g) => g.ten == 'dien');

    expect(await goi(), isNotNull);
    await rt.dong();
    expect(await goi(), isNotNull, reason: 'trước đây chuanBi nhớ "đã nạp" mãi → moPhien ném StateError → luật');
    expect(rt.soLanNap, 2);
  });

  // Bẫy 4.60: lượt mở phiên có thể đang ĐỨNG CHỜ lượt đọc ảnh bị bỏ trong runtime (`_phien` còn null) — Huỷ phải tới
  // runtime thì lượt ấy mới bỏ được (moc), không thì mô hình mở một phiên vô ích khi lượt cũ xong. Và phải tới NGAY: micro
  // gọi Huỷ lượt Điền rồi mới mở lượt chép lời — bộ đếm tăng muộn là bỏ oan chính lượt chép lời.
  test('⭐ huy() gọi runtime.huy() ĐỒNG BỘ, trước khi chờ phiên dừng', () {
    final rt = _RuntimeGia();
    final p = PhienMotLoiGoi(
      runtime: rt,
      sanSang: () async => true,
      duongTep: () async => '/gia/gemma.litertlm',
      thoiHan: const Duration(seconds: 5),
      nhan: '[test]',
    );
    unawaited(p.huy());
    expect(rt.soLanHuy, 1);
  });
}
