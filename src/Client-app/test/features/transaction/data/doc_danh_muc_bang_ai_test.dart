/// `DocDanhMucBangAi` — ảnh quét hoá đơn: Gemma chọn MỘT danh mục chi từ tên cửa hàng + các món (người dùng chốt
/// 2026-10-08: "AI chọn danh mục, gọi Gemma lần hai"). Mọi đường hỏng trả `null` — form đoán bằng từ khoá như cũ.
library;

import 'package:flowmoney/features/ai_edge/data/phien_cong_cu.dart';
import 'package:flowmoney/features/ai_edge/data/slm_runtime.dart';
import 'package:flowmoney/features/ai_edge/domain/cong_cu.dart';
import 'package:flowmoney/features/transaction/data/doc_danh_muc_bang_ai.dart';
import 'package:flutter_test/flutter_test.dart';

class _RuntimeGia implements SlmRuntime {
  _RuntimeGia(this.kichBan);
  final List<SuKienLuot> kichBan;
  bool _san = false;
  final List<({String heThong, String cauHoi, List<KhaiBaoCongCu> congCu})> daMo = [];

  @override
  bool get dangSan => _san;
  @override
  Future<void> moHinhSan(String duongTep) async => _san = true;
  @override
  Future<PhienCongCu> moPhien({
    required String heThong,
    required String cauHoi,
    required List<KhaiBaoCongCu> congCu,
  }) async {
    daMo.add((heThong: heThong, cauHoi: cauHoi, congCu: congCu));
    return PhienCongCuGia([kichBan]);
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
  const ten = ['Ăn uống', 'Di chuyển', 'Mua sắm'];
  DocDanhMucBangAi ai(_RuntimeGia r, {bool sanSang = true}) => DocDanhMucBangAi(
        runtime: r,
        sanSang: () async => sanSang,
        duongTep: () async => '/gia/gemma.litertlm',
      );

  test('⭐ một tool, tên danh mục là enum; câu hỏi mang tên cửa hàng + các món; trả tên mô hình chọn', () async {
    final r = _RuntimeGia(const [GoiCongCu(kTenCongCuChonDanhMuc, {'danh_muc': 'Ăn uống'})]);
    final kq = await ai(r).chon(cuaHang: 'ỦA TEA', mon: const ['HỒNG TRÀ SỮA', 'CAFE COCO CLOUD'], tenDanhMuc: ten);
    expect(kq, 'Ăn uống');
    final m = r.daMo.single;
    expect(m.congCu.single.ten, kTenCongCuChonDanhMuc);
    expect((m.congCu.single.thamSo['properties'] as Map)['danh_muc']['enum'], ten);
    expect(m.cauHoi, contains('ỦA TEA'));
    expect(m.cauHoi, contains('HỒNG TRÀ SỮA'));
  });

  test('tên KHÔNG có trong danh sách → null (lưới kiểm, dù engine đã ép enum)', () async {
    final r = _RuntimeGia(const [GoiCongCu(kTenCongCuChonDanhMuc, {'danh_muc': 'Cà phê'})]);
    expect(await ai(r).chon(cuaHang: 'A', mon: const ['x'], tenDanhMuc: ten), isNull);
  });

  test('tên khớp sau chuẩn hoá (hoa thường, khoảng trắng) → trả đúng tên trong danh sách', () async {
    final r = _RuntimeGia(const [GoiCongCu(kTenCongCuChonDanhMuc, {'danh_muc': ' ăn  UỐNG '})]);
    expect(await ai(r).chon(cuaHang: 'A', mon: const ['x'], tenDanhMuc: ten), 'Ăn uống');
  });

  test('chưa sẵn sàng / không danh mục / không cửa hàng lẫn món → null, KHÔNG mở phiên', () async {
    final r = _RuntimeGia(const []);
    expect(await ai(r, sanSang: false).chon(cuaHang: 'A', mon: const ['x'], tenDanhMuc: ten), isNull);
    expect(await ai(r).chon(cuaHang: 'A', mon: const ['x'], tenDanhMuc: const []), isNull);
    expect(await ai(r).chon(cuaHang: '', mon: const [], tenDanhMuc: ten), isNull);
    expect(r.daMo, isEmpty);
  });

  test('mô hình không gọi tool → null', () async {
    final r = _RuntimeGia(const [Chu('Không biết')]);
    expect(await ai(r).chon(cuaHang: 'A', mon: const ['x'], tenDanhMuc: ten), isNull);
  });
}
