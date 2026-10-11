// test/features/transaction/data/them_giao_dich_nguon_test.dart

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/category/data/repositories/category_management_repository.dart';
import 'package:flowmoney/features/category/domain/phan_loai_ghi_chu.dart';
import 'package:flowmoney/features/transaction/data/repositories/transaction_repository.dart';
import 'package:flowmoney/features/transaction/data/them_giao_dich_nguon.dart';
import 'package:flowmoney/features/transaction/data/vi_theo_nguon_store.dart';
import 'package:flowmoney/features/wallet/data/repositories/wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../category/presentation/category_test_fakes.dart';

/// Sổ giả đếm số lần đọc — `napLichSu` phải đọc sổ đúng MỘT lần cho cả bảng ví hay dùng lẫn hai mô hình.
class _SoGia implements TransactionRepository {
  _SoGia(this.hang);
  final List<Transaction> hang;
  int soLanDoc = 0;
  @override
  Future<List<Transaction>> getAllRows(int idaccount) async {
    soLanDoc++;
    return hang;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _ViGia implements WalletRepository {
  _ViGia(this.hang);
  final List<Wallet> hang;
  @override
  Future<List<Wallet>> getActiveRows(int idaccount) async => hang;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Mọi lời gọi đều ném — đường "đọc danh mục lỗi thì rỗng".
class _DanhMucNem implements CategoryManagementRepository {
  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('hỏng');
}

Transaction _gd(String id, String cat, String wallet, String note) => Transaction(
      id: id,
      walletId: wallet,
      idaccount: 1,
      categoryId: cat,
      amount: 30000,
      type: 'chi',
      status: 'completed',
      provider: 'Manual',
      note: note,
      date: DateTime(2026, 9, 1),
      images: '',
      syncStatus: 'synced',
      syncRetryCount: 0,
      updatedAt: DateTime(2026, 9, 1),
      isDeleted: false,
    );

void main() {
  tearDown(() async {
    if (sl.isRegistered<TransactionRepository>()) await sl.unregister<TransactionRepository>();
    if (sl.isRegistered<WalletRepository>()) await sl.unregister<WalletRepository>();
  });

  group('napViDangDung', () {
    test('ví TIÊM SẴN trả về ĐỒNG BỘ — trang dựng khung đầu đã có ví, như trước đợt tách', () {
      final vi = [makeWallet()];
      final r = ThemGiaoDichNguonThat(viTiem: vi).napViDangDung(1);
      expect(r, isA<List<Wallet>>(), reason: 'trả Future là khung đầu hiện "Đang tải ví..." — đổi hành vi');
      expect(r, same(vi));
    });

    test('không phiên và không tiêm → rỗng, KHÔNG đọc ví của ai (G38)', () {
      sl.registerSingleton<WalletRepository>(_ViGia([makeWallet()]));
      final r = ThemGiaoDichNguonThat().napViDangDung(null);
      expect(r, isA<List<Wallet>>());
      expect(r as List<Wallet>, isEmpty);
    });

    test('có phiên → đọc ví đang dùng của phiên', () async {
      sl.registerSingleton<WalletRepository>(_ViGia([makeWallet(id: 'w1')]));
      final r = await ThemGiaoDichNguonThat().napViDangDung(7);
      expect(r.map((w) => w.id), ['w1']);
    });
  });

  group('napLichSu', () {
    test('tiêm sẵn bảng ví hay dùng → trả ĐỒNG BỘ kèm mô hình tiêm, không đụng sổ', () {
      final bo = BoPhanLoaiGhiChu.hoc(const []);
      final r = ThemGiaoDichNguonThat(viHayDungTiem: const {'food': 'w1'}, boPhanLoaiTiem: bo).napLichSu(1);
      expect(r, isA<LichSuHoc>());
      final ls = r as LichSuHoc;
      expect(ls.viHayDung, {'food': 'w1'});
      expect(ls.boPhanLoai, same(bo));
      expect(ls.mauDeXuat, isNull);
    });

    test('tiêm sẵn ví mà không tiêm bảng → bảng rỗng, không đụng sổ', () {
      final r = ThemGiaoDichNguonThat(viTiem: [makeWallet()]).napLichSu(1);
      expect((r as LichSuHoc).viHayDung, isEmpty);
    });

    test('đọc sổ ĐÚNG MỘT lần cho bảng ví hay dùng và hai mô hình', () async {
      final so = _SoGia([for (var i = 0; i < 5; i++) _gd('t$i', 'food', 'w2', 'cafe')]);
      sl.registerSingleton<TransactionRepository>(so);
      final ls = await ThemGiaoDichNguonThat().napLichSu(1);
      expect(so.soLanDoc, 1);
      expect(ls.viHayDung['food'], 'w2');
      expect(ls.boPhanLoai, isNotNull);
      expect(ls.boSoTien, isNotNull);
    });

    test('đường SỬA: mẫu đề xuất bỏ chính giao dịch đang sửa', () async {
      sl.registerSingleton<TransactionRepository>(_SoGia([_gd('a', 'food', 'w', 'cafe'), _gd('b', 'food', 'w', 'cafe')]));
      final ls = await ThemGiaoDichNguonThat().napLichSu(1, dangSua: 'a');
      expect(ls.mauDeXuat, hasLength(1));
      final moi = await ThemGiaoDichNguonThat().napLichSu(1);
      expect(moi.mauDeXuat, isNull, reason: 'đường tạo mới dùng mẫu của mô hình, không mẫu riêng');
    });
  });

  test('napDanhMucVaTuKhoa: đọc lỗi → rỗng, không ném (ô Nhập nhanh vẫn điền được ô khác)', () async {
    final (ds, tk) = await ThemGiaoDichNguonThat(danhMuc: _DanhMucNem()).napDanhMucVaTuKhoa(1);
    expect(ds, isEmpty);
    expect(tk, isEmpty);
  });

  test('napDanhMucVaTuKhoa: không phiên → rỗng, không đọc', () async {
    final (ds, _) = await ThemGiaoDichNguonThat(danhMuc: _DanhMucNem()).napDanhMucVaTuKhoa(null);
    expect(ds, isEmpty);
  });

  test('ví theo nguồn: không store → null / không ném; có store → đọc lại được thứ đã ghi', () async {
    final khong = ThemGiaoDichNguonThat();
    expect(await khong.viTheoNguon(1, 'MB Bank', '7777'), isNull);
    await khong.nhoViTheoNguon(1, 'MB Bank', '7777', 'w1');
    final store = InMemoryViTheoNguonStore();
    final co = ThemGiaoDichNguonThat(viTheoNguon: store);
    await co.nhoViTheoNguon(1, 'MB Bank', '7777', 'w1');
    expect(await co.viTheoNguon(1, 'MB Bank', '7777'), 'w1');
  });

  test('tra ngân sách đi qua hàm tiêm', () async {
    var goi = 0;
    final n = ThemGiaoDichNguonThat(traNganSach: (_, __) async {
      goi++;
      return null;
    });
    await n.traNganSach(1, 'food');
    expect(goi, 1);
  });

  test('xoaHangBienDong: hàm tiêm ném → nuốt, không ném', () async {
    final n = ThemGiaoDichNguonThat(xoaBienDong: (_, __) async => throw StateError('hỏng'));
    await expectLater(n.xoaHangBienDong(1, 'bienDong:x'), completes);
  });
}
