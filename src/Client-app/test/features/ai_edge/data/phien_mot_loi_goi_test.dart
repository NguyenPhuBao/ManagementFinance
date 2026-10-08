/// `PhienMotLoiGoi` — vòng đời phiên của Nhập nhanh (C2) và lệnh tạo (C3).
library;

import 'package:flowmoney/features/ai_edge/data/phien_cong_cu.dart';
import 'package:flowmoney/features/ai_edge/data/phien_mot_loi_goi.dart';
import 'package:flowmoney/features/ai_edge/data/slm_runtime.dart';
import 'package:flowmoney/features/ai_edge/domain/cong_cu.dart';
import 'package:flutter_test/flutter_test.dart';

class _RuntimeGia implements SlmRuntime {
  bool _san = false;
  int soLanNap = 0;

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
  Future<void> huy() async {}
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
}
