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

  test('⭐ bảy khai báo: tim_giao_dich đứng ĐẦU, tổng kết ngay sau (định tuyến, lần đo 9); mô tả nói khi nào gọi', () {
    // Trước lần đo 9 tim_giao_dich đứng CUỐI (bốn tool 4b rồi ba tool bước 2) và
    // mô hình chọn tool có một tham số đứng trước nó cho sáu câu có điều kiện.
    expect(bo.khaiBao.map((k) => k.ten).toList(), [
      kTenCongCuGiaoDich, kTenCongCuTongKet, kTenCongCuNganSach, kTenCongCuHoaDon,
      kTenCongCuVi, kTenCongCuMucTieu, kTenCongCuGoiYHanMuc,
    ]);
    for (final k in bo.khaiBao) {
      expect(k.moTa, contains('Gọi khi'), reason: k.ten);
      expect(k.thamSo['type'], 'object', reason: k.ten);
    }
    expect(bo.tenCacCongCu, bo.khaiBao.map((k) => k.ten).toList());
  });

  test('⭐ tool cạnh tranh chỉ đường cho nhau (cổng D lần 1: 7/20 câu gọi nhầm tool)', () {
    String moTa(String ten) => bo.khaiBao.firstWhere((k) => k.ten == ten).moTa;
    expect(moTa(kTenCongCuTongKet), contains(kTenCongCuGiaoDich),
        reason: 'C1, C7, C10, C13, C14, C18 gọi tong_ket_thu_chi_ky cho câu hỏi từng khoản');
    expect(moTa(kTenCongCuGiaoDich), contains(kTenCongCuTongKet));
    expect(moTa(kTenCongCuMucTieu), contains(kTenCongCuGiaoDich),
        reason: 'C20: hỏi lần nạp gần nhất mà gọi danh_sach_muc_tieu');
    expect(moTa(kTenCongCuGoiYHanMuc), contains(kTenCongCuMucTieu),
        reason: 'B2: hỏi để dành cho mục tiêu mà gọi goi_y_han_muc');
  });

  test('⭐ mô tả thu hẹp (lần đo 9): tổng kết CHỈ khi câu không có điều kiện; tim_giao_dich mở đầu bằng "Gọi khi"', () {
    String moTa(String ten) => bo.khaiBao.firstWhere((k) => k.ten == ten).moTa;
    expect(moTa(kTenCongCuTongKet), contains('KHÔNG có điều kiện'),
        reason: 'C1 C7 C10 C13 C14 C18 gọi tổng kết bốn lần liền cho câu có điều kiện');
    expect(moTa(kTenCongCuGiaoDich), startsWith('Gọi khi'),
        reason: 'câu đầu tiên của mô tả là thứ mô hình đọc trước');
    expect(moTa(kTenCongCuGiaoDich), contains('BẤT KỲ điều kiện'));
  });

  test('⭐ tool tổng kết mang tên nói rõ "tổng", không còn "chi_tieu" (đòn bẩy spec 2b mục 1.2 hàng 10, 2026-09-24)', () {
    expect(kTenCongCuTongKet, 'tong_ket_thu_chi_ky');
    expect(bo.khaiBao.map((k) => k.ten), contains('tong_ket_thu_chi_ky'));
    expect(bo.khaiBao.map((k) => k.ten).any((t) => t.contains('chi_tieu')), isFalse,
        reason: 'cổng D lần 2 và 3: 9 câu "tiêu gì / chi những gì" đều gọi tool có chữ "chi_tieu" trong tên');
    expect(cauDangTraCuu(kTenCongCuTongKet), 'Đang tổng kết thu chi…');
  });

  // Bẫy 4.39: `maxTokens` 4096 là trần TỔNG — khai báo tool, kết quả tool và câu
  // trả lời cùng chia. Số dưới là độ dài đã chạy qua các phiên dài nhất trên
  // Realme (spike bước 2b, task 8: 5431; đo lại 2026-09-24 14:33 sau khi đổi tên
  // tool `tong_ket_thu_chi_ky`: 5437, S1 3 lời gọi · S2 2 · S3 2, 0
  // FAILED_PRECONDITION; đo lại 2026-09-25 00:40 sau lát định tuyến lần đo 9 — mô tả
  // thu hẹp + lời hệ thống 1.318 ký tự: 5491, S1 3 · S2 2 · S3 2, 0 FAILED_PRECONDITION).
  // Dài hơn → đo lại S1 / S2 / S3 trên máy rồi mới nâng số này.
  const kTranToolsJsonDaDo = 5491;
  test('⭐ tools_json của bảy tool không dài hơn con số đã đo trên máy (bẫy 4.39)', () {
    final n = toolsJsonCua(bo.khaiBao).length;
    expect(n, lessThanOrEqualTo(kTranToolsJsonDaDo),
        reason: 'tools_json nay $n ký tự, vượt con số đã đo trên Realme. Đo lại phiên '
            'dài nhất (S1 / S2 / S3, không được có FAILED_PRECONDITION) rồi mới nâng.');
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
    final kq = (await bo.chay(kTenCongCuTongKet, {'ky': 'thang_truoc'}, idaccount: 10, now: now))!;
    expect(phanTich.kyDaHoi!.from, DateTime(2026, 8, 1));
    expect(kq.chuThem, {'ky': 'tháng trước'});
    expect(kq.hang.single.ten, 'Ăn uống');
  });

  test('chi tiêu: mã lạ → từ chối mà KHÔNG hỏi repository', () async {
    final kq = (await bo.chay(kTenCongCuTongKet, {'ky': 'hom_kia'}, idaccount: 10, now: now))!;
    expect(kq.loi, contains('hom_kia'));
    expect(phanTich.kyDaHoi, isNull, reason: 'không đoán kỳ rồi đi đọc dữ liệu của kỳ đoán');
  });

  test('⭐ tong_ket_thu_chi_ky giữ TÁM mã: moi_luc là mã riêng của tim_giao_dich — nhận thì từ chối, không đọc repository', () async {
    final khai = bo.khaiBao.firstWhere((k) => k.ten == kTenCongCuTongKet);
    // ⚠️ Không so với `kMaKy.keys` — bản sai đưa `moi_luc` vào `kMaKy` đổi cả hai
    // vế cùng lúc, phép so tự đúng (lượt thi công bước 2b đo được). Đòi kết quả
    // độc lập: đúng tám mã, không có `moi_luc`.
    final enumKy = ((khai.thamSo['properties'] as Map)['ky'] as Map)['enum'] as List;
    expect(enumKy, hasLength(8));
    expect(enumKy, isNot(contains(kMaKyMoiLuc)),
        reason: 'khai moi_luc cho tong_ket_thu_chi_ky là mời mô hình gọi một mã sẽ bị từ chối');
    final kq = (await bo.chay(kTenCongCuTongKet, {'ky': 'moi_luc'}, idaccount: 10, now: now))!;
    expect(kq.loi, isNotNull);
    expect(phanTich.kyDaHoi, isNull);
  });
}
