/// `chanTheoGoi` — phần async của cửa chặn trần Basic (spec Premium 7.1):
/// Premium → qua và KHÔNG đếm; Basic → đếm → `conTaoDuoc` →
/// `chuyenHuongTheoGoi`; đếm ném → qua (một lỗi đọc CSDL không được biến thành
/// một màn Nâng cấp sai chỗ); chưa có phiên → qua.
library;

import 'package:flowmoney/features/premium/data/chan_theo_goi.dart';
import 'package:flowmoney/features/premium/data/dem_dang_hoat_dong.dart';
import 'package:flowmoney/features/premium/data/goi_repository.dart';
import 'package:flowmoney/features/premium/data/goi_store.dart';
import 'package:flowmoney/features/premium/data/payment_api.dart';
import 'package:flowmoney/features/premium/domain/quyen_tinh_nang.dart';
import 'package:flowmoney/features/premium/domain/tran_goi.dart';
import 'package:flowmoney/features/premium/domain/trang_thai_goi.dart';
import 'package:flutter_test/flutter_test.dart';

class DemGia implements NguonDemDangHoatDong {
  DemGia(this.so, {this.nem = false});
  final int so;
  final bool nem;
  int lanGoi = 0;

  @override
  Future<int> dem(LoaiTran loai, int idaccount) async {
    lanGoi++;
    if (nem) throw StateError('db');
    return so;
  }
}

class ApiIm implements PaymentApi {
  @override
  Future<Map<String, Object?>> thongTinGoi() => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> taoDon() => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> trangThaiDon(int orderCode) =>
      throw UnimplementedError();
  @override
  Future<List<Map<String, Object?>>> lichSu({int page = 1, int limit = 20}) =>
      throw UnimplementedError();
}

void main() {
  final now = DateTime(2026, 10, 6);

  Future<GoiRepository> repo({bool premium = false}) async {
    final kho = InMemoryGoiStore();
    if (premium) {
      await kho.ghi(
          10,
          TrangThaiGoi(
              loai: LoaiGoi.premium,
              hetHan: DateTime(2026, 11, 5),
              nhanLuc: now));
    }
    final r = GoiRepository(api: ApiIm(), kho: kho, clock: () => now);
    await r.datTaiKhoan(10);
    return r;
  }

  test('Basic 3/3 → /premium?tran=vi; 2/3 → null', () async {
    final r = await repo();
    expect(
        await chanTheoGoi(Uri.parse('/wallets/add'), LoaiTran.vi,
            goi: r, dem: DemGia(3), clock: () => now),
        '/premium?tran=vi');
    expect(
        await chanTheoGoi(Uri.parse('/wallets/add'), LoaiTran.vi,
            goi: r, dem: DemGia(2), clock: () => now),
        isNull);
  });

  test('Premium → null và KHÔNG đếm', () async {
    final r = await repo(premium: true);
    final d = DemGia(99);
    expect(
        await chanTheoGoi(Uri.parse('/goals/add'), LoaiTran.mucTieu,
            goi: r, dem: d, clock: () => now),
        isNull);
    expect(d.lanGoi, 0);
  });

  test('đếm ném → cho qua (null)', () async {
    final r = await repo();
    expect(
        await chanTheoGoi(Uri.parse('/wallets/add'), LoaiTran.vi,
            goi: r, dem: DemGia(0, nem: true), clock: () => now),
        isNull);
  });

  test('chưa có phiên (idaccount null) → cho qua', () async {
    final r = GoiRepository(
        api: ApiIm(), kho: InMemoryGoiStore(), clock: () => now);
    expect(
        await chanTheoGoi(Uri.parse('/wallets/add'), LoaiTran.vi,
            goi: r, dem: DemGia(9), clock: () => now),
        isNull);
  });

  test('/budget/rules?id= không chặn dù 9/3', () async {
    final r = await repo();
    expect(
        await chanTheoGoi(Uri.parse('/budget/rules?id=b1'), LoaiTran.nganSach,
            goi: r, dem: DemGia(9), clock: () => now),
        isNull);
  });

  group('chanTheoQuyen (spec phân quyền 2026-10-08 mục 4.3)', () {
    Future<GoiRepository> repoBasic(Map<String, bool> q) async {
      final kho = InMemoryGoiStore();
      await kho.ghi(10, TrangThaiGoi(loai: LoaiGoi.basic, nhanLuc: now, quyenTinhNang: q));
      final r = GoiRepository(api: ApiIm(), kho: kho, clock: () => now);
      await r.datTaiKhoan(10);
      return r;
    }

    test('Basic bị tắt → /premium?quyen=export_reports', () async {
      final r = await repoBasic(const {'export_reports': false});
      expect(chanTheoQuyen(MaQuyen.exportReports, goi: r, clock: () => now),
          '/premium?quyen=export_reports');
    });

    test('Basic thiếu khoá → qua (mặc định mở)', () async {
      final r = await repoBasic(const {});
      expect(chanTheoQuyen(MaQuyen.exportReports, goi: r, clock: () => now), isNull);
    });

    test('Premium → qua', () async {
      final r = await repo(premium: true);
      expect(chanTheoQuyen(MaQuyen.exportReports, goi: r, clock: () => now), isNull);
    });

    test('chưa có phiên → qua', () {
      final r = GoiRepository(api: ApiIm(), kho: InMemoryGoiStore(), clock: () => now);
      expect(chanTheoQuyen(MaQuyen.exportReports, goi: r, clock: () => now), isNull);
    });
  });
}
