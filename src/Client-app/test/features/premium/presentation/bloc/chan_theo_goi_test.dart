/// `chanTheoGoi` — phần async của cửa chặn trần gói hiệu lực (spec Premium 7.1; B1: cả trần cột Premium):
/// trần hiệu lực không giới hạn → qua, KHÔNG đếm; có số (Basic, hoặc Premium có trần) → đếm → `conTaoDuoc` →
/// `chuyenHuongTheoGoi`; đếm ném → qua (một lỗi đọc CSDL không được biến thành
/// một màn Nâng cấp sai chỗ); chưa có phiên → qua.
library;

import 'dart:async';

import 'package:flowmoney/features/premium/presentation/bloc/chan_theo_goi.dart';
import 'package:flowmoney/features/premium/data/dem_dang_hoat_dong.dart';
import 'package:flowmoney/features/premium/data/repositories/goi_repository.dart';
import 'package:flowmoney/features/premium/data/goi_store.dart';
import 'package:flowmoney/features/premium/data/datasources/payment_api.dart';
import 'package:flowmoney/features/premium/domain/quyen_tinh_nang.dart';
import 'package:flowmoney/features/premium/domain/tran_goi.dart';
import 'package:flowmoney/features/premium/domain/hang_goi.dart';
import 'package:flowmoney/features/premium/data/models/tran_goi.dart';
import 'package:flowmoney/features/premium/data/models/trang_thai_goi.dart';
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
  @override
  Future<Map<String, Object?>> xacNhanNangCap({required int orderCode, required bool accept}) =>
      throw UnimplementedError();
}

/// Kho mà lượt `doc` treo tới khi test gọi [tra] — dựng lại khoảnh khắc khởi động nguội: `noiPhien` đã gán tài khoản,
/// secure storage chưa trả lời.
class KhoCho implements GoiStore {
  final _cho = Completer<TrangThaiGoi?>();
  void tra(TrangThaiGoi? t) => _cho.complete(t);

  @override
  Future<TrangThaiGoi?> doc(int idaccount) => _cho.future;
  @override
  Future<void> ghi(int idaccount, TrangThaiGoi trangThai) async {}
  @override
  Future<void> xoa(int idaccount) async {}
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


  test('⭐ B1: Premium có trần cột Premium 10 ví → 10/10 chặn (/premium?tran=vi), 9/10 qua', () async {
    final kho = InMemoryGoiStore();
    await kho.ghi(
        10,
        TrangThaiGoi(
            loai: LoaiGoi.premium, hetHan: DateTime(2026, 11, 5), nhanLuc: now, tran: const TranGoi(vi: 10)));
    final r = GoiRepository(api: ApiIm(), kho: kho, clock: () => now);
    addTearDown(r.dispose);
    await r.datTaiKhoan(10);
    expect(await chanTheoGoi(Uri.parse('/wallets/add'), LoaiTran.vi, goi: r, dem: DemGia(10), clock: () => now),
        '/premium?tran=vi');
    expect(await chanTheoGoi(Uri.parse('/wallets/add'), LoaiTran.vi, goi: r, dem: DemGia(9), clock: () => now),
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
    final r =
        GoiRepository(api: ApiIm(), kho: InMemoryGoiStore(), clock: () => now);
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
      await kho.ghi(10,
          TrangThaiGoi(loai: LoaiGoi.basic, nhanLuc: now, quyenTinhNang: q));
      final r = GoiRepository(api: ApiIm(), kho: kho, clock: () => now);
      await r.datTaiKhoan(10);
      return r;
    }

    test('Basic bị tắt → /premium?quyen=export_reports', () async {
      final r = await repoBasic(const {'export_reports': false});
      expect(
          await chanTheoQuyen(MaQuyen.exportReports, goi: r, clock: () => now),
          '/premium?quyen=export_reports');
    });

    test('Basic thiếu khoá → qua (mặc định mở)', () async {
      final r = await repoBasic(const {});
      expect(
          await chanTheoQuyen(MaQuyen.exportReports, goi: r, clock: () => now),
          isNull);
    });

    test('Premium → qua', () async {
      final r = await repo(premium: true);
      expect(
          await chanTheoQuyen(MaQuyen.exportReports, goi: r, clock: () => now),
          isNull);
    });

    test('chưa có phiên → qua', () async {
      final r = GoiRepository(
          api: ApiIm(), kho: InMemoryGoiStore(), clock: () => now);
      expect(
          await chanTheoQuyen(MaQuyen.exportReports, goi: r, clock: () => now),
          isNull);
    });
  });

  // G92: router chạy lại `redirect` khi `AuthSuccess` tới — cùng lúc `noiPhien` gán tài khoản rồi mới đọc kho. Cửa đọc
  // `hienTai` ngay thì thấy Basic mặc định: Premium mở lạnh deeplink `/goals/add` rơi vào `/premium`.
  group('G92 — kho gói chưa nạp xong lúc cửa chặn chạy', () {
    final premium = TrangThaiGoi(
        loai: LoaiGoi.premium, hetHan: DateTime(2026, 11, 5), nhanLuc: now);
    final basicTatXuat = TrangThaiGoi(
        loai: LoaiGoi.basic,
        nhanLuc: now,
        quyenTinhNang: const {'export_reports': false});

    GoiRepository dangNap(KhoCho kho) {
      final r = GoiRepository(api: ApiIm(), kho: kho, clock: () => now);
      unawaited(r.datTaiKhoan(
          10)); // như `noiPhien`: tài khoản có ngay, kho còn đang đọc
      return r;
    }

    test('⭐ chanTheoGoi: kho là Premium → chờ nạp xong rồi cho qua, KHÔNG đếm',
        () async {
      final kho = KhoCho();
      final r = dangNap(kho);
      final d = DemGia(3);
      final ketQua = chanTheoGoi(Uri.parse('/goals/add'), LoaiTran.mucTieu,
          goi: r, dem: d, clock: () => now);
      kho.tra(premium);
      expect(await ketQua, isNull,
          reason:
              'G92: đọc hienTai trước khi kho nạp xong là đọc Basic mặc định — Premium bị đẩy sang /premium');
      expect(d.lanGoi, 0);
    });

    test(
        'chanTheoGoi: kho là Basic chạm trần → vẫn chặn (không "cho qua lúc đang nạp")',
        () async {
      final kho = KhoCho();
      final r = dangNap(kho);
      final ketQua = chanTheoGoi(Uri.parse('/goals/add'), LoaiTran.mucTieu,
          goi: r, dem: DemGia(3), clock: () => now);
      kho.tra(null); // kho trống, phiên không nói Premium → Basic
      expect(await ketQua, '/premium?tran=${maTran(LoaiTran.mucTieu)}');
    });

    test(
        'chanTheoGoi: đăng xuất trong lúc chờ kho → coi như chưa có phiên, cho qua, KHÔNG đếm',
        () async {
      final kho = KhoCho();
      final r = dangNap(kho);
      final d = DemGia(3);
      final ketQua = chanTheoGoi(Uri.parse('/goals/add'), LoaiTran.mucTieu,
          goi: r, dem: d, clock: () => now);
      r.xoaPhien();
      kho.tra(premium);
      expect(await ketQua, isNull);
      expect(d.lanGoi, 0);
    });

    test('⭐ chanTheoQuyen: kho là Basic TẮT quyền → chờ nạp xong rồi chặn',
        () async {
      final kho = KhoCho();
      final r = dangNap(kho);
      final ketQua =
          chanTheoQuyen(MaQuyen.exportReports, goi: r, clock: () => now);
      kho.tra(basicTatXuat);
      expect(await ketQua, '/premium?quyen=export_reports',
          reason:
              'G92, cùng gốc nhưng chiều NGƯỢC: Basic mặc định không mang khoá `export_reports` nên rơi về '
              'macDinhKhiThieu = mở — Basic bị tắt quyền lọt vào Xuất báo cáo khi mở lạnh deeplink');
    });

    test('chanTheoQuyen: kho là Premium → chờ nạp xong rồi cho qua', () async {
      final kho = KhoCho();
      final r = dangNap(kho);
      final ketQua =
          chanTheoQuyen(MaQuyen.exportReports, goi: r, clock: () => now);
      kho.tra(premium);
      expect(await ketQua, isNull);
    });
  });
}
