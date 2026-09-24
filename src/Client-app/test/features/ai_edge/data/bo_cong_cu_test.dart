/// Bộ bảy tool (4b + bước 2): khai báo đúng tên/thứ tự, tra theo tên, và mỗi adapter
/// đọc đúng repository rồi giao cho hàm dựng hàng. Fake ghi đè `noSuchMethod`
/// để một hàm mới lỡ gọi thêm sẽ ném thay vì im lặng (nếp `nguon_goi_so_test`).
library;

import 'package:flowmoney/core/bill/bill_recurrence.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/ai_edge/data/bo_cong_cu.dart';
import 'package:flowmoney/features/ai_edge/domain/cong_cu.dart';
import 'package:flowmoney/features/ai_edge/domain/hang_chi_tieu.dart';
import 'package:flowmoney/features/analytics/data/analytics_repository.dart';
import 'package:flowmoney/features/analytics/data/bao_cao_repository.dart';
import 'package:flowmoney/features/analytics/domain/bao_cao_xuat.dart';
import 'package:flowmoney/features/analytics/domain/pham_vi_ky.dart';
import 'package:flowmoney/features/analytics/domain/thong_ke_thang.dart';
import 'package:flowmoney/features/analytics/domain/tong_tai_san.dart';
import 'package:flowmoney/features/analytics/domain/vai_vay_no.dart';
import 'package:flowmoney/features/bill/data/repositories/bill_repository.dart';
import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/data/repositories/budget_repository.dart';
import 'package:flowmoney/features/goal/data/repositories/goal_repository.dart';
import 'package:flowmoney/features/transaction/data/repositories/transaction_repository.dart';
import 'package:flowmoney/features/wallet/data/models/wallet_entity.dart';
import 'package:flowmoney/features/wallet/data/repositories/wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';

ThongKeKy _tk(Ky ky) {
  final chuoi = chuoiTheoKy(const [], ky: ky);
  return ThongKeKy(
    ky: ky,
    tong: const TongThuChi(thu: 9000000, chi: 1200000),
    tongTruoc: const TongThuChi(thu: 0, chi: 0),
    tongNamTruoc: const TongThuChi(thu: 0, chi: 0),
    chiTheoDanhMuc: const [],
    danhMuc: const [
      DongDanhMuc(categoryId: 'c1', ten: 'Ăn uống', icon: null, mauHex: null, soTien: 800000, tiLeTongChi: 0),
    ],
    chuoi: chuoi,
    latPhanLoai: const [],
    danhMucTheoLat: const {},
    chuoiDanhMuc: const {},
    soLieu: const SoLieuNhanh(chiMoiNgay: 0, ngayChiNhieuNhat: null, chiNgayNhieuNhat: 0, khoanChiLonNhat: null),
    theoVi: const [],
    topChi: const [],
    lichChiTieu: const {},
    dongTien: null,
    duBao: null,
    taiSan: tongTaiSanCua(const [], const [], ky: ky, now: DateTime(2026, 9, 8)),
    giaoDichDauTien: null,
    chuoiVayNo: [for (final d in chuoi) DiemVayNo(ky: d.ky)],
  );
}

class _PhanTich implements AnalyticsRepository {
  Ky? kyDaHoi;
  @override
  Stream<ThongKeKy> watchKy(int idaccount, {required Ky ky, DateTime? now}) {
    kyDaHoi = ky;
    return Stream.value(_tk(ky));
  }
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

BudgetView _ns(String id, String ten,
    {required double amount, required double spent, DateTime? start, bool lapLai = true}) {
  final s = start ?? DateTime(2026, 9, 1);
  return BudgetView(
    budget: BudgetEntity(
      id: id, idaccount: 10, categoryId: 'c-$id', amount: amount, spent: spent,
      startDate: s, recurrence: lapLai, timeRecurrence: BudgetRecurrence.month, updatedAt: s,
    ),
    categoryName: ten,
  );
}

class _NganSach implements BudgetRepository {
  @override
  Stream<List<BudgetView>> watchBudgets(int idaccount, {DateTime? now}) => Stream.value([
        _ns('gd', 'Giáo dục', amount: 50000, spent: 45000),
        // KHÔNG lặp lại, kỳ tháng 8 → hết hạn 01/09; now = 22/09 → isExpired →
        // phải bị lọc. ⚠️ Phải `lapLai: false`: ngân sách lặp lại mà không đặt
        // ngày kết thúc thì không bao giờ hết hạn (`expiresAt` null), nên bản
        // đầu của fixture này — `recurrence: true` — không canh gì cả.
        _ns('cu', 'Cũ', amount: 100000, spent: 10000, start: DateTime(2026, 8, 1), lapLai: false),
      ]);
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

class _Vi implements WalletRepository {
  @override
  Stream<List<WalletEntity>> watchAll(int idaccount) => Stream.value([
        WalletEntity(id: 'w1', idaccount: idaccount, name: 'Tiền mặt', type: 'cash', balance: 500000, status: 'active', includeInTotal: true, allowNegative: false, updatedAt: DateTime(2026, 9, 10)),
        WalletEntity(id: 'w2', idaccount: idaccount, name: 'test', type: 'cash', balance: -100000, status: 'active', includeInTotal: true, allowNegative: false, updatedAt: DateTime(2026, 9, 10)),
      ]);
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

Bill _bill(String ten, DateTime dueDate) => Bill(
      id: ten, idaccount: 10, walletId: 'w1', categoryId: 'c1', name: ten, amount: 45000,
      startDate: dueDate.subtract(const Duration(days: 30)), dueDate: dueDate,
      payStatus: 'Pending', isPaid: false, autoPayEnabled: false, timeNotification: '3',
      isRecurrence: true, timeRecurrence: kBillCycleMonth, recurrence: 'monthly',
      icon: 'receipt', colour: '#4CAF50', note: '', isDeleted: false, syncStatus: 'synced',
      syncRetryCount: 0, updatedAt: DateTime(2026, 9, 1),
    );

// Ba fake cho ba tool bước 2 — tệp này chỉ kiểm khai báo, không chạy chúng,
// nên `noSuchMethod` là đủ: gọi tới là ném, không im lặng.
class _MucTieu implements GoalRepository {
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

class _GiaoDich implements TransactionRepository {
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

class _BaoCao implements BaoCaoRepository {
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

class _HoaDon implements BillRepository {
  final daHoi = <int>[];
  @override
  Stream<List<Bill>> watchBills(int idaccount) {
    daHoi.add(idaccount);
    return Stream.value([_bill('Kiem', DateTime(2026, 9, 1)), _bill('Điện', DateTime(2026, 9, 25))]);
  }
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

void main() {
  final now = DateTime(2026, 9, 22, 10);
  late _PhanTich phanTich;
  late _HoaDon hoaDon;
  late BoCongCu bo;

  setUp(() {
    phanTich = _PhanTich();
    hoaDon = _HoaDon();
    bo = BoCongCu.macDinh(
      phanTich: phanTich,
      nganSach: _NganSach(),
      vi: _Vi(),
      hoaDon: hoaDon,
      mucTieu: _MucTieu(),
      giaoDich: _GiaoDich(),
      baoCao: _BaoCao(),
    );
  });

  test('bảy khai báo: bốn tool 4b rồi ba tool bước 2, mô tả tiếng Việt nói khi nào gọi', () {
    expect(bo.khaiBao.map((k) => k.ten).toList(), [
      kTenCongCuNganSach, kTenCongCuHoaDon, kTenCongCuVi, kTenCongCuChiTieu,
      kTenCongCuMucTieu, kTenCongCuGoiYHanMuc, kTenCongCuGiaoDich,
    ]);
    for (final k in bo.khaiBao) {
      expect(k.moTa, contains('Gọi khi'), reason: k.ten);
      expect(k.thamSo['type'], 'object', reason: k.ten);
    }
    expect(bo.tenCacCongCu, bo.khaiBao.map((k) => k.ten).toList());
  });

  test('tên lạ → null (mô hình bịa tên)', () async {
    expect(await bo.chay('bay_gio_may_gio', {}, idaccount: 10, now: now), isNull);
  });

  test('hoá đơn: đọc watchBills đúng tài khoản, mặc định chua_tra', () async {
    final kq = (await bo.chay(kTenCongCuHoaDon, {}, idaccount: 10, now: now))!;
    expect(hoaDon.daHoi, [10]);
    expect(kq.hang.map((h) => h.ten).toList(), ['Kiem', 'Điện']);
    expect(kq.hang.first.trangThai, 'đã quá hạn');
  });

  test('hoá đơn: tham số trang_thai đi tới hàm dựng hàng', () async {
    final kq = (await bo.chay(kTenCongCuHoaDon, {'trang_thai': 'qua_han'}, idaccount: 10, now: now))!;
    expect(kq.hang.map((h) => h.ten).toList(), ['Kiem']);
  });

  test('ví: chép qua viChoGoiSoTu — ví âm đứng đầu', () async {
    final kq = (await bo.chay(kTenCongCuVi, {}, idaccount: 10, now: now))!;
    expect(kq.hang.map((h) => h.ten).toList(), ['test', 'Tiền mặt']);
    expect(kq.hang.first.trangThai, 'đang âm');
  });

  test('ngân sách: chỉ ngân sách ĐANG CHẠY (nganSachDangChay lọc isExpired)', () async {
    final kq = (await bo.chay(kTenCongCuNganSach, {}, idaccount: 10, now: now))!;
    expect(kq.hang.map((h) => h.ten).toList(), ['Giáo dục']);
    expect(kq.tongHop[1].chuoi, '1');
  });

  test('chi tiêu: mã kỳ → đúng Ky cho watchKy; chữ kỳ về cho mô hình', () async {
    final kq = (await bo.chay(kTenCongCuChiTieu, {'ky': 'thang_truoc'}, idaccount: 10, now: now))!;
    expect(phanTich.kyDaHoi!.from, DateTime(2026, 8, 1));
    expect(kq.chuThem, {'ky': 'tháng trước'});
    expect(kq.hang.single.ten, 'Ăn uống');
  });

  test('chi tiêu: mã lạ → từ chối mà KHÔNG hỏi repository', () async {
    final kq = (await bo.chay(kTenCongCuChiTieu, {'ky': 'hom_kia'}, idaccount: 10, now: now))!;
    expect(kq.loi, contains('hom_kia'));
    expect(phanTich.kyDaHoi, isNull, reason: 'không đoán kỳ rồi đi đọc dữ liệu của kỳ đoán');
  });

  test('⭐ chi_tieu_theo_ky giữ TÁM mã: moi_luc là mã riêng của tim_giao_dich — nhận thì từ chối, không đọc repository', () async {
    final khai = bo.khaiBao.firstWhere((k) => k.ten == kTenCongCuChiTieu);
    // ⚠️ Không so với `kMaKy.keys` — bản sai đưa `moi_luc` vào `kMaKy` đổi cả hai
    // vế cùng lúc, phép so tự đúng (lượt thi công bước 2b đo được). Đòi kết quả
    // độc lập: đúng tám mã, không có `moi_luc`.
    final enumKy = ((khai.thamSo['properties'] as Map)['ky'] as Map)['enum'] as List;
    expect(enumKy, hasLength(8));
    expect(enumKy, isNot(contains(kMaKyMoiLuc)),
        reason: 'khai moi_luc cho chi_tieu_theo_ky là mời mô hình gọi một mã sẽ bị từ chối');
    final kq = (await bo.chay(kTenCongCuChiTieu, {'ky': 'moi_luc'}, idaccount: 10, now: now))!;
    expect(kq.loi, isNotNull);
    expect(phanTich.kyDaHoi, isNull);
  });
}
