/// A5 mục 5.4 — `DocAnhBangAi`: chỗ DUY NHẤT ảnh quét gọi mô hình. Mọi đường hỏng trả `null` (màn dùng luật).
library;

import 'package:flowmoney/features/ai_edge/data/phien_cong_cu.dart';
import 'package:flowmoney/features/ai_edge/data/slm_runtime.dart';
import 'package:flowmoney/features/ai_edge/domain/cong_cu.dart';
import 'package:flowmoney/features/transaction/data/doc_anh_bang_ai.dart';
import 'package:flowmoney/features/transaction/domain/doc_anh_quet.dart';
import 'package:flutter_test/flutter_test.dart';

class _RuntimeGia implements SlmRuntime {
  _RuntimeGia(this.taoPhien);
  final PhienCongCu Function() taoPhien;
  bool _san = false;
  int soLanNap = 0;
  final List<({String heThong, String cauHoi, List<KhaiBaoCongCu> congCu})> daMo = [];

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
    daMo.add((heThong: heThong, cauHoi: cauHoi, congCu: congCu));
    return taoPhien();
  }

  @override
  Future<String> sinh(String prompt, {int tranToken = 0}) => throw UnimplementedError();
  @override
  Stream<String> sinhDan(String prompt, {int tranToken = 0}) => throw UnimplementedError();
  @override
  Future<void> huy() async {}
  @override
  Future<void> dong() async {}
}

void main() {
  final now = DateTime(2026, 10, 8, 10);
  const vanBan = 'Pho Hung\nKhong so o day\nDia chi 12 Le Loi\nPho tai 45.000\nTong cong 90.000';

  DocAnhBangAi ai(_RuntimeGia r, {bool sanSang = true}) =>
      DocAnhBangAi(runtime: r, sanSang: () async => sanSang, duongTep: () async => '/gia/gemma.litertlm');

  test('⭐ mô hình gọi dien_anh_quet → KetQuaAiAnh thô; một tool, ba tham số, KHÔNG danh mục; gửi chuGuiMoHinh', () async {
    final phien = PhienCongCuGia([
      [const GoiCongCu(kTenCongCuDienAnhQuet, {'so_tien': 90000, 'ngay': '05/10/2026', 'noi_dung': 'Pho Hung'})],
    ]);
    final r = _RuntimeGia(() => phien);
    final kq = await ai(r).doc(vanBan, now: now);
    expect(kq, isNotNull);
    expect(kq!.soTien, 90000);
    expect(kq.ngay, '05/10/2026');
    expect(kq.noiDung, 'Pho Hung');
    final khai = r.daMo.single.congCu.single;
    expect(khai.ten, kTenCongCuDienAnhQuet);
    expect((khai.thamSo['properties'] as Map).keys, unorderedEquals(['so_tien', 'ngay', 'noi_dung']),
        reason: 'không có danh mục — form tự gợi ý trên ghi chú (spec 5.4)');
    expect(r.daMo.single.cauHoi, chuGuiMoHinh(vanBan));
    expect(r.daMo.single.heThong, contains('08/10/2026'));
    expect(phien.daDong, isTrue);
  });

  test('máy chưa sẵn sàng → null, KHÔNG nạp, KHÔNG mở phiên', () async {
    final r = _RuntimeGia(() => PhienCongCuGia(const []));
    expect(await ai(r, sanSang: false).doc(vanBan, now: now), isNull);
    expect(r.soLanNap, 0);
    expect(r.daMo, isEmpty);
  });

  test('mô hình không gọi tool → null', () async {
    final r = _RuntimeGia(() => PhienCongCuGia([
          [const Chu('Tôi không đọc được.')],
        ]));
    expect(await ai(r).doc(vanBan, now: now), isNull);
  });
}
