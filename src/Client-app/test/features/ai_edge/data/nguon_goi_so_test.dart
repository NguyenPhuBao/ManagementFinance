/// `NguonGoiSo` gom gói số cho màn Trợ lý AI. Từ 2026-09-22 (việc số 1) nó
/// gom **sáu** gói — thêm hoá đơn và ví — vì hai gói ấy đã có cho khối Nhận
/// xét mà màn Trợ lý AI không thấy: hỏi về hoá đơn là mô hình lấy số của gói
/// khác trả lời thay.
///
/// Fake ở đây ghi đè `noSuchMethod`: chỉ dựng đúng hàm `NguonGoiSo` gọi, để
/// một hàm mới lỡ gọi thêm sẽ ném thay vì im lặng trả rỗng.
library;

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/ai_edge/data/nguon_goi_so.dart';
import 'package:flowmoney/features/analytics/data/analytics_repository.dart';
import 'package:flowmoney/features/analytics/domain/bao_cao_xuat.dart';
import 'package:flowmoney/features/analytics/domain/pham_vi_ky.dart';
import 'package:flowmoney/features/analytics/domain/thong_ke_thang.dart';
import 'package:flowmoney/features/analytics/domain/tong_tai_san.dart';
import 'package:flowmoney/features/analytics/domain/vai_vay_no.dart';
import 'package:flowmoney/features/bill/data/repositories/bill_repository.dart';
import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/data/repositories/budget_repository.dart';
import 'package:flowmoney/features/goal/data/models/goal_entity.dart';
import 'package:flowmoney/features/goal/data/repositories/goal_repository.dart';
import 'package:flowmoney/features/wallet/data/models/wallet_entity.dart';
import 'package:flowmoney/features/wallet/data/repositories/wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';

ThongKeKy _tk() {
  final ky = Ky.thang(2026, 9);
  final chuoi = chuoiTheoKy(const [], ky: ky);
  return ThongKeKy(
    ky: ky,
    tong: const TongThuChi(thu: 9000000, chi: 1200000),
    tongTruoc: const TongThuChi(thu: 0, chi: 0),
    tongNamTruoc: const TongThuChi(thu: 0, chi: 0),
    chiTheoDanhMuc: const [],
    danhMuc: const [],
    chuoi: chuoi,
    latPhanLoai: const [],
    danhMucTheoLat: const {},
    chuoiDanhMuc: const {},
    soLieu: const SoLieuNhanh(
      chiMoiNgay: 0,
      ngayChiNhieuNhat: null,
      chiNgayNhieuNhat: 0,
      khoanChiLonNhat: null,
    ),
    theoVi: const [],
    topChi: const [],
    lichChiTieu: const {},
    dongTien: null,
    duBao: null,
    taiSan:
        tongTaiSanCua(const [], const [], ky: ky, now: DateTime(2026, 9, 8)),
    giaoDichDauTien: null,
    chuoiVayNo: [for (final d in chuoi) DiemVayNo(ky: d.ky)],
  );
}

class _PhanTich implements AnalyticsRepository {
  @override
  Stream<ThongKeKy> watchKy(int idaccount, {required Ky ky, DateTime? now}) =>
      Stream.value(_tk());
}

class _NganSach implements BudgetRepository {
  @override
  Stream<List<BudgetView>> watchBudgets(int idaccount, {DateTime? now}) =>
      Stream.value(const []);
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

class _MucTieu implements GoalRepository {
  @override
  Stream<List<GoalEntity>> watchGoals(int idaccount) => Stream.value(const []);
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

class _Vi implements WalletRepository {
  int soLanDoc = 0;
  @override
  Stream<List<WalletEntity>> watchAll(int idaccount) {
    soLanDoc++;
    return Stream.value([
      WalletEntity(
        id: 'w1',
        idaccount: idaccount,
        name: 'Tiền mặt',
        type: 'cash',
        balance: 500000,
        status: 'active',
        includeInTotal: true,
        allowNegative: false,
        updatedAt: DateTime(2026, 9, 10),
      ),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

class _HoaDon implements BillRepository {
  final daHoi = <int>[];
  @override
  Stream<List<Bill>> watchBills(int idaccount) {
    daHoi.add(idaccount);
    return Stream.value(const []);
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

void main() {
  late _Vi vi;
  late _HoaDon hoaDon;
  late NguonGoiSo nguon;

  setUp(() {
    vi = _Vi();
    hoaDon = _HoaDon();
    nguon = NguonGoiSo(
      phanTich: _PhanTich(),
      nganSach: _NganSach(),
      mucTieu: _MucTieu(),
      vi: vi,
      hoaDon: hoaDon,
    );
  });

  test('trả SÁU gói theo thứ tự cố định', () async {
    final goi = await nguon.tatCa(10, now: DateTime(2026, 9, 22));
    expect(
      [for (final g in goi) g.man],
      ['phan_tich', 'ngan_sach', 'muc_tieu', 'hoa_don', 'vi', 'trang_chu'],
    );
  });

  test('hoá đơn được hỏi với đúng mã tài khoản', () async {
    await nguon.tatCa(10, now: DateTime(2026, 9, 22));
    expect(hoaDon.daHoi, [10]);
  });

  test('ví đọc MỘT lần cho cả gói ví lẫn tổng số dư của trang chủ', () async {
    // Đọc hai lần là hai ảnh chụp khác nhau của cùng dữ liệu — cùng bẫy mà
    // `KeHoachTaiPhanBoLoader` phải nhận `budgets` đã nạp.
    final goi = await nguon.tatCa(10, now: DateTime(2026, 9, 22));
    expect(vi.soLanDoc, 1);
    final goiVi = goi.firstWhere((g) => g.man == 'vi');
    expect(goiVi.soLieu.map((s) => s.chuoi), contains('500.000 đ'));
  });
}
