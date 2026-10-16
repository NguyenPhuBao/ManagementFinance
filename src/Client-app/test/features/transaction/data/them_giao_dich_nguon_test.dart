// test/features/transaction/data/them_giao_dich_nguon_test.dart

import 'package:flowmoney/features/category/data/danh_muc_ai_doan_store.dart';
import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/category/data/goi_y_phan_hoi_store.dart';
import 'package:flowmoney/features/category/data/models/category_suggestion.dart';
import 'package:flowmoney/features/category/data/repositories/category_management_repository.dart';
import 'package:flowmoney/features/category/domain/phan_loai_ghi_chu.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/data/repositories/transaction_repository.dart';
import 'package:flowmoney/features/transaction/data/them_giao_dich_nguon.dart';
import 'package:flowmoney/features/transaction/data/vi_theo_nguon_store.dart';
import 'package:flowmoney/features/wallet/data/models/wallet_entity.dart';
import 'package:flowmoney/features/wallet/data/repositories/wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../category/presentation/category_test_fakes.dart';

/// Sổ giả đếm số lần đọc — `napLichSu` phải đọc sổ đúng MỘT lần cho cả bảng ví hay dùng lẫn hai mô hình.
class _SoGia implements TransactionRepository {
  _SoGia(this.hang);
  final List<TransactionEntity> hang;
  int soLanDoc = 0;
  @override
  Future<List<TransactionEntity>> getAll(int idaccount) async {
    soLanDoc++;
    return hang;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _ViGia implements WalletRepository {
  _ViGia(this.hang);
  final List<WalletEntity> hang;
  @override
  Future<List<WalletEntity>> getActive(int idaccount) async => hang;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Mọi lời gọi đều ném — đường "đọc danh mục lỗi thì rỗng".
class _DanhMucNem implements CategoryManagementRepository {
  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('hỏng');
}

/// Store phản hồi mà MỌI lần ghi đều thất bại: `ghi` là hàm `async` nên lỗi nằm trong Future trả về (như bản Drift khi
/// SQLite hỏng), không phải ném đồng bộ.
class _PhanHoiNem implements GoiYPhanHoiStore {
  int soLanGhi = 0;
  @override
  Future<void> ghi({
    required int idaccount,
    required CategorySuggestion goiY,
    required String ketQua,
    String? chonCategoryId,
  }) async {
    soLanGhi++;
    throw StateError('ghi hỏng');
  }

  @override
  Future<List<PhanHoiGoiY>> doc(int idaccount) async => const [];
}

/// Giao dịch mà ĐỌC GHI CHÚ thì ném — dựng đường "học mô hình lỗi" của `napLichSu` bằng dữ liệu, không thêm đường tiêm
/// lỗi nào vào mã thật. Mọi thứ khác dùng được bình thường (bảng ví hay dùng chỉ đọc danh mục + ví).
class _GiaoDichNemGhiChu extends TransactionEntity {
  _GiaoDichNemGhiChu(String id)
      : super(
          id: id,
          walletId: 'w',
          idaccount: 1,
          categoryId: 'food',
          amount: 30000,
          type: 'chi',
          note: '',
          date: DateTime(2026, 9, 1),
          syncStatus: 'synced',
          updatedAt: DateTime(2026, 9, 1),
          isDeleted: false,
        );
  @override
  String get note => throw StateError('đọc ghi chú hỏng');
}

/// Bảng dấu "danh mục do AI chọn, lưu nguyên" trong bộ nhớ.
class _AiDoanGia implements DanhMucAiDoanStore {
  _AiDoanGia(this.ids);
  final Set<String> ids;
  @override
  Future<Set<String>> idsCua(int idaccount) async => ids;
  @override
  Future<void> danhDau({required int idaccount, required String transactionId, required String categoryId}) async =>
      ids.add(transactionId);
  @override
  Future<void> go({required int idaccount, required String transactionId}) async => ids.remove(transactionId);
}

TransactionEntity _gd(String id, String cat, String wallet, String note) => TransactionEntity(
      id: id,
      walletId: wallet,
      idaccount: 1,
      categoryId: cat,
      amount: 30000,
      type: 'chi',
      note: note,
      date: DateTime(2026, 9, 1),
      syncStatus: 'synced',
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
      expect(r, isA<List<WalletEntity>>(), reason: 'trả Future là khung đầu hiện "Đang tải ví..." — đổi hành vi');
      expect(r, same(vi));
    });

    test('không phiên và không tiêm → rỗng, KHÔNG đọc ví của ai (G38)', () {
      sl.registerSingleton<WalletRepository>(_ViGia([makeWallet()]));
      final r = ThemGiaoDichNguonThat().napViDangDung(null);
      expect(r, isA<List<WalletEntity>>());
      expect(r as List<WalletEntity>, isEmpty);
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

    test('học mô hình lỗi → mô hình ấy là null, bảng ví hay dùng vẫn có, KHÔNG ném (spec B1 mục 6)', () async {
      sl.registerSingleton<TransactionRepository>(_SoGia([for (var i = 0; i < 5; i++) _GiaoDichNemGhiChu('t$i')]));
      final ls = await ThemGiaoDichNguonThat().napLichSu(1);
      expect(ls.boPhanLoai, isNull, reason: 'B1 học lỗi → rơi về bảng từ khoá, không toast');
      expect(ls.boSoTien, isNull, reason: 'mô hình số tiền học lỗi → thẻ theo số tiền im');
      expect(ls.viHayDung['food'], 'w', reason: 'bảng ví hay dùng không phụ thuộc hai mô hình');
    });

    test('mô hình học lỗi KHÔNG làm mất mô hình kia được tiêm sẵn (hai khối try/catch độc lập)', () async {
      sl.registerSingleton<TransactionRepository>(_SoGia([for (var i = 0; i < 5; i++) _GiaoDichNemGhiChu('t$i')]));
      final bo = BoPhanLoaiGhiChu.hoc(const []);
      final ls = await ThemGiaoDichNguonThat(boPhanLoaiTiem: bo).napLichSu(1);
      expect(ls.boPhanLoai, same(bo), reason: 'đã tiêm thì không học lại, nên không chạm ghi chú lỗi');
      expect(ls.boSoTien, isNull);
    });

    test('⭐ B1 BỎ giao dịch mang dấu "AI chọn, lưu nguyên" (người dùng chốt 2026-10-16)', () async {
      // Gemma đoán "đổ xăng" → Ăn uống sáu lần, người dùng lưu nguyên cả sáu; 12 khoản "grab" → Di chuyển là mẫu thật.
      // Sau khi lọc vẫn còn 12 mẫu (≥ kToiThieuMauTong) — B1 im vì CHƯA từng thấy "xang", không vì sổ mỏng.
      final hang = [
        for (var i = 0; i < 6; i++) _gd('ai$i', 'food', 'w', 'do xang'),
        for (var i = 0; i < 12; i++) _gd('g$i', 'move', 'w', 'grab'),
      ];
      sl.registerSingleton<TransactionRepository>(_SoGia(hang));
      const hopLe = {'food', 'move'};

      final khongDau = await ThemGiaoDichNguonThat(aiDoan: _AiDoanGia({})).napLichSu(1);
      expect(khongDau.boPhanLoai!.doan('do xang', hopLe: hopLe)?.categoryId, 'food',
          reason: 'không lọc: cái sai của AI thành mẫu, B1 nói lại nó — vòng lặp học sai (ca có răng)');

      final coDau = await ThemGiaoDichNguonThat(aiDoan: _AiDoanGia({for (var i = 0; i < 6; i++) 'ai$i'})).napLichSu(1);
      expect(coDau.boPhanLoai!.doan('do xang', hopLe: hopLe), isNull,
          reason: 'mẫu mang dấu ra khỏi phép học — B1 không khoá cái sai của AI lại');
      expect(coDau.boPhanLoai!.doan('grab', hopLe: hopLe)?.categoryId, 'move', reason: 'mẫu thật vẫn học');
      expect(coDau.viHayDung['food'], 'w', reason: 'chỉ B1 bỏ mẫu — bảng ví hay dùng vẫn đếm mọi giao dịch');
    });

    test('đường SỬA: mẫu đề xuất cũng bỏ giao dịch mang dấu AI', () async {
      sl.registerSingleton<TransactionRepository>(_SoGia(
          [_gd('a', 'food', 'w', 'cafe'), _gd('b', 'food', 'w', 'cafe'), _gd('ai', 'food', 'w', 'cafe')]));
      final ls = await ThemGiaoDichNguonThat(aiDoan: _AiDoanGia({'ai'})).napLichSu(1, dangSua: 'a');
      expect(ls.mauDeXuat, hasLength(1), reason: 'bỏ "a" (đang sửa) và "ai" (dấu AI) — còn "b"');
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

  group('bất biến 6 — phản hồi gợi ý ghi unawaited + bắt lỗi', () {
    final goiY = CategorySuggestion(category: makeCategory(id: 'food', name: 'Ăn uống'), matchedKeyword: 'phở');

    test('⭐ ghi phản hồi HỎNG → ghiPhanHoi không ném và lỗi không lọt ra ngoài (chọn / lưu không bị chặn)', () async {
      final store = _PhanHoiNem();
      final n = ThemGiaoDichNguonThat(phanHoi: store);
      expect(() => n.ghiPhanHoi(idaccount: 1, goiY: goiY, ketQua: kKetQuaGoiYChon, chon: 'food'), returnsNormally);
      // Để `catchError` chạy TRONG ca này: Future thất bại không ai bắt thì zone báo lỗi chưa xử lý và ca đỏ.
      await pumpEventQueue();
      expect(store.soLanGhi, 1, reason: 'ca không canh gì nếu store giả chưa từng được gọi');
    });

    test('không có store phản hồi → không làm gì, không ném', () async {
      final n = ThemGiaoDichNguonThat();
      expect(() => n.ghiPhanHoi(idaccount: 1, goiY: goiY, ketQua: kKetQuaGoiYChon), returnsNormally);
      expect(await n.docPhanHoi(1), isNull);
    });
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
