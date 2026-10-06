library;

import 'package:flowmoney/features/analytics/data/thu_tu_khoi_nguon.dart';
import 'package:flowmoney/features/analytics/domain/thu_tu_khoi.dart';
import 'package:flowmoney/features/analytics/presentation/bloc/thu_tu_khoi_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class NguonThuTuGia implements ThuTuKhoiNguon {
  NguonThuTuGia({this.deXuat});
  CumKhoi? deXuat;
  final phanHoi = <PhanHoiThuTu>[];
  final ghi = <(DateTime, Map<CumKhoi, int>)>[];
  var soLanDoc = 0;

  @override
  Future<KetQuaThuTu> doc(int idaccount, DateTime now) async {
    soLanDoc++;
    return KetQuaThuTu(thuTu: thuTuTu(phanHoi), deXuat: deXuat);
  }

  @override
  Future<void> ghiPhanHoi(int idaccount, String ketQua, CumKhoi? cum, DateTime luc) async =>
      phanHoi.add(PhanHoiThuTu(ketQua: ketQua, cum: cum, luc: luc));

  @override
  Future<void> congGiay(int idaccount, DateTime ngay, Map<CumKhoi, int> giay) async =>
      ghi.add((ngay, giay));
}

void main() {
  final now = DateTime(2026, 10, 20, 9);

  test('nap phát thứ tự + đề xuất', () async {
    final c = ThuTuKhoiCubit(nguon: NguonThuTuGia(deXuat: CumKhoi.coCau), clock: () => now);
    addTearDown(c.close);
    await c.nap(7);
    expect(c.state.deXuat, CumKhoi.coCau);
    expect(c.state.thuTu, kThuTuCumMacDinh);
  });

  test('nap(null) → mặc định, không đọc nguồn', () async {
    final n = NguonThuTuGia(deXuat: CumKhoi.coCau);
    final c = ThuTuKhoiCubit(nguon: n, clock: () => now);
    addTearDown(c.close);
    await c.nap(null);
    expect(c.state, const ThuTuKhoiState());
    expect(n.soLanDoc, 0);
  });

  test('⚠️ Đưa lên: thứ tự đổi và thẻ TẮT, kể cả khi nguồn còn đề xuất cụm khác', () async {
    final n = NguonThuTuGia(deXuat: CumKhoi.coCau);
    final c = ThuTuKhoiCubit(nguon: n, clock: () => now);
    addTearDown(c.close);
    await c.nap(7);
    n.deXuat = CumKhoi.topChi; // giả lập cụm khác vừa đủ điều kiện
    await c.duaLen(CumKhoi.coCau);
    expect(c.state.thuTu.first, CumKhoi.coCau);
    expect(c.state.deXuat, isNull, reason: 'kế hoạch, làm rõ 1');
    expect(n.phanHoi.single.ketQua, kThuTuDuaLen);
    await c.napLai();
    expect(c.state.deXuat, CumKhoi.topChi, reason: 'trang hiện lại thì mới tính');
  });

  test('Bỏ qua và Về mặc định ghi đúng mã', () async {
    final n = NguonThuTuGia(deXuat: CumKhoi.coCau);
    final c = ThuTuKhoiCubit(nguon: n, clock: () => now);
    addTearDown(c.close);
    await c.nap(7);
    await c.boQua(CumKhoi.coCau);
    await c.veMacDinh();
    expect(n.phanHoi.map((p) => (p.ketQua, p.cum)),
        [(kThuTuBoQua, CumKhoi.coCau), (kThuTuVeMacDinh, null)]);
    expect(c.state.deXuat, isNull);
  });

  test('ghiGiay chuyển thẳng xuống nguồn; chưa có tài khoản hoặc rỗng thì bỏ', () async {
    final n = NguonThuTuGia();
    final c = ThuTuKhoiCubit(nguon: n, clock: () => now);
    addTearDown(c.close);
    await c.ghiGiay(DateTime(2026, 10, 20), {CumKhoi.tong: 3});
    expect(n.ghi, isEmpty, reason: 'chưa nap — không có idaccount');
    await c.nap(7);
    await c.ghiGiay(DateTime(2026, 10, 20), const {});
    await c.ghiGiay(DateTime(2026, 10, 20), {CumKhoi.tong: 3});
    expect(n.ghi.single.$2, {CumKhoi.tong: 3});
  });
}
