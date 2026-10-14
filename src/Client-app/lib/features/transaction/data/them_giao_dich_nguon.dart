// lib/features/transaction/data/them_giao_dich_nguon.dart
/// Mọi lần đọc / ghi dữ liệu của form Thêm / Sửa giao dịch (spec `2026-10-11-tach-trang-them-giao-dich-cubit-design.md`
/// mục 4.3). Trang và `ThemGiaoDichCubit` không cầm repository hay store nào khác.
///
/// Bản thật dựng từ các tham số khởi tạo của trang: tham số tiêm có thì dùng, không thì `sl<…>()` LÚC CẦN (không lúc
/// dựng) — y như trang làm trước đợt tách, để 24 tệp test dựng trang chạy lại không đổi. Hàm mỏng: lỗi bắt ở chỗ gọi
/// (Cubit) như trước, trừ bốn hàm vốn tự nuốt lỗi ở trang ([napDanhMucVaTuKhoa], [xoaHangBienDong], [xoaAnhBienLai],
/// [ghiPhanHoi]).
///
/// ⚠️ `sl<WalletRepository>().getActive(` và `sl<TransactionRepository>().getAll(` phải nằm TRÊN MỘT DÒNG:
/// `wallet_picker_sources_test` nhận diện lối đọc ví theo chuỗi.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/notification_dao.dart' show kKindBienDongSoDu;
import '../../../core/di/injection_container.dart';
import '../../../core/notification/kho_bien_lai.dart';
import '../../../core/notification/thong_bao_nguon.dart';
import '../../../core/ocr/kho_anh_quet.dart';
import '../../budget/data/models/budget_entity.dart';
import '../../budget/data/repositories/budget_repository.dart';
import '../../category/data/goi_y_phan_hoi_store.dart';
import '../../category/data/models/category_suggestion.dart';
import '../../category/data/repositories/category_management_repository.dart';
import '../../category/domain/phan_loai_ghi_chu.dart';
import '../../category/domain/phan_loai_so_tien.dart';
import '../../wallet/data/repositories/wallet_repository.dart';
import '../../wallet/data/models/wallet_entity.dart';
import '../domain/dien_san_bien_dong.dart';
import '../domain/doc_mon_hang.dart';
import '../domain/vi_hay_dung.dart';
import 'doc_cau_bang_ai.dart';
import 'repositories/transaction_repository.dart';
import 'vi_theo_nguon_store.dart';

/// Tra ngân sách đang chạy của một danh mục. Dời từ `add_transaction_page.dart` (trang `export` lại tên này).
typedef BudgetLookup = Future<BudgetView?> Function(int idaccount, String categoryId);

/// Kết quả MỘT lần đọc sổ lúc mở form: bảng ví hay dùng (chặng 1.2) + hai mô hình gợi ý (B1, dự án C) + mẫu đề xuất
/// từ khoá của đường sửa (bỏ chính giao dịch đang sửa). `null` ở mô hình = chưa có / học lỗi.
typedef LichSuHoc = ({
  Map<String, String> viHayDung,
  BoPhanLoaiGhiChu? boPhanLoai,
  BoPhanLoaiSoTien? boSoTien,
  List<MauGhiChu>? mauDeXuat,
});

abstract class ThemGiaoDichNguon {
  /// Ví đang dùng (bộ chọn ví — không ví lưu trữ). ĐỒNG BỘ khi ví tiêm sẵn hoặc không phiên.
  FutureOr<List<WalletEntity>> napViDangDung(int? idaccount);

  /// ĐỒNG BỘ khi tiêm sẵn bảng ví hay dùng / tiêm ví / không phiên.
  FutureOr<LichSuHoc> napLichSu(int? idaccount, {String? dangSua});

  /// `null` = không có store phản hồi (không ghi, không thôi gợi ý).
  Future<List<PhanHoiGoiY>?> docPhanHoi(int idaccount);

  /// Bắn rồi quên — phản hồi hỏng không được chặn việc chọn hay lưu.
  void ghiPhanHoi({required int idaccount, required CategorySuggestion goiY, required String ketQua, String? chon});

  Future<List<Category>> danhMucChonDuoc(int idaccount);
  Future<Map<String, List<String>>> tuKhoa(int idaccount);

  /// Danh mục chọn được + từ khoá; lỗi hoặc không phiên → rỗng.
  Future<(List<Category>, Map<String, List<String>>)> napDanhMucVaTuKhoa(int? idaccount);
  Future<void> luuTuKhoa({required int idaccount, required String categoryId, required List<String> tuKhoa});

  DocCauBangAi? get docAi;

  Future<String?> viTheoNguon(int idaccount, String nguon, String? duoi);
  Future<String?> viTheoNguonChung(int idaccount, String nguon);
  Future<void> nhoViTheoNguon(int idaccount, String nguon, String? duoi, String walletId);

  Future<List<DienSanBienDong>> hangBienDongCho(int idaccount);
  Future<List<KhoanSo>> khoanTrongSo(int idaccount);

  /// Xoá cứng hàng loại 20 (ngoại lệ có chủ ý — spec D1 §3.3). Không bao giờ ném.
  Future<void> xoaHangBienDong(int idaccount, String khoa);

  /// Ảnh của hàng đang mở: ảnh quét ở `KhoAnhQuet`, biên lai ở `KhoBienLai`. `null` = không ảnh / tệp đã mất.
  Future<String?> duongDanAnh(DienSanBienDong d);
  Future<List<MonHang>> docMonQuet(String anh);

  /// Không bao giờ ném.
  Future<void> xoaAnhBienLai(String? anh);
  Future<void> xoaAnhQuet(String? anh);

  Future<BudgetView?> traNganSach(int idaccount, String categoryId);
}

class ThemGiaoDichNguonThat implements ThemGiaoDichNguon {
  ThemGiaoDichNguonThat({
    CategoryManagementRepository? danhMuc,
    List<WalletEntity>? viTiem,
    Map<String, String>? viHayDungTiem,
    BoPhanLoaiGhiChu? boPhanLoaiTiem,
    BoPhanLoaiSoTien? boSoTienTiem,
    GoiYPhanHoiStore? phanHoi,
    DocCauBangAi? docAi,
    ViTheoNguonStore? viTheoNguon,
    Future<void> Function(int idaccount, String khoa)? xoaBienDong,
    Future<List<KhoanSo>> Function(int idaccount)? khoanTrongSo,
    Future<List<DienSanBienDong>> Function(int idaccount)? hangBienDongCho,
    KhoBienLai? khoBienLai,
    KhoAnhQuet? khoAnhQuet,
    BudgetLookup? traNganSach,
  })  : _danhMucTiem = danhMuc,
        _viTiem = viTiem,
        _viHayDungTiem = viHayDungTiem,
        _boPhanLoaiTiem = boPhanLoaiTiem,
        _boSoTienTiem = boSoTienTiem,
        _phanHoiTiem = phanHoi,
        _docAiTiem = docAi,
        _viTheoNguonTiem = viTheoNguon,
        _xoaBienDongTiem = xoaBienDong,
        _khoanTrongSoTiem = khoanTrongSo,
        _hangBienDongChoTiem = hangBienDongCho,
        _khoBienLaiTiem = khoBienLai,
        _khoAnhQuetTiem = khoAnhQuet,
        _traNganSachTiem = traNganSach;

  final CategoryManagementRepository? _danhMucTiem;
  final List<WalletEntity>? _viTiem;
  final Map<String, String>? _viHayDungTiem;
  final BoPhanLoaiGhiChu? _boPhanLoaiTiem;
  final BoPhanLoaiSoTien? _boSoTienTiem;
  final GoiYPhanHoiStore? _phanHoiTiem;
  final DocCauBangAi? _docAiTiem;
  final ViTheoNguonStore? _viTheoNguonTiem;
  final Future<void> Function(int idaccount, String khoa)? _xoaBienDongTiem;
  final Future<List<KhoanSo>> Function(int idaccount)? _khoanTrongSoTiem;
  final Future<List<DienSanBienDong>> Function(int idaccount)? _hangBienDongChoTiem;
  final KhoBienLai? _khoBienLaiTiem;
  final KhoAnhQuet? _khoAnhQuetTiem;
  final BudgetLookup? _traNganSachTiem;

  // Phân giải LÚC CẦN, như các getter của trang cũ — ca test không đăng ký kiểu nào thì không bao giờ chạm `sl` ấy.
  CategoryManagementRepository get _danhMuc => _danhMucTiem ?? sl<CategoryManagementRepository>();
  GoiYPhanHoiStore? get _phanHoi =>
      _phanHoiTiem ?? (sl.isRegistered<GoiYPhanHoiStore>() ? sl<GoiYPhanHoiStore>() : null);
  ViTheoNguonStore? get _viTheoNguon =>
      _viTheoNguonTiem ?? (sl.isRegistered<ViTheoNguonStore>() ? sl<ViTheoNguonStore>() : null);
  KhoBienLai? get _khoBienLai => _khoBienLaiTiem ?? (sl.isRegistered<KhoBienLai>() ? sl<KhoBienLai>() : null);
  KhoAnhQuet? get _khoAnhQuet => _khoAnhQuetTiem ?? (sl.isRegistered<KhoAnhQuet>() ? sl<KhoAnhQuet>() : null);

  @override
  DocCauBangAi? get docAi => _docAiTiem ?? (sl.isRegistered<DocCauBangAi>() ? sl<DocCauBangAi>() : null);

  /// Từ `_loadWallets` của trang.
  @override
  FutureOr<List<WalletEntity>> napViDangDung(int? idaccount) {
    final tiem = _viTiem;
    if (tiem != null) return tiem;
    // Chưa có phiên: không đọc ví của ai cả. Danh sách rỗng làm chốt "Vui lòng chọn ví thanh toán" chặn lưu, nên không
    // có đường nào ghi giao dịch dưới danh nghĩa admin qua ngả này.
    if (idaccount == null) return const <WalletEntity>[];
    return sl<WalletRepository>().getActive(idaccount);
  }

  /// Từ `_loadViHayDung` của trang.
  @override
  FutureOr<LichSuHoc> napLichSu(int? idaccount, {String? dangSua}) {
    final coSan = (
      viHayDung: _viHayDungTiem ?? const <String, String>{},
      boPhanLoai: _boPhanLoaiTiem,
      boSoTien: _boSoTienTiem,
      mauDeXuat: null,
    );
    // Ca test tiêm sẵn bảng hoặc tiêm `wallets`: không đụng SQLite, đúng như đường ví.
    if (_viHayDungTiem != null || _viTiem != null || idaccount == null) return coSan;
    return _hocTuSo(idaccount, dangSua);
  }

  Future<LichSuHoc> _hocTuSo(int idaccount, String? dangSua) async {
    final txs = await sl<TransactionRepository>().getAll(idaccount);
    final bang = viHayDungTheoDanhMuc(demViTheoDanhMuc([
      for (final t in txs) (categoryId: t.categoryId, walletId: t.walletId),
    ]));
    BoPhanLoaiGhiChu? bo = _boPhanLoaiTiem;
    if (bo == null) {
      try {
        bo = BoPhanLoaiGhiChu.hoc(mauHocTu([
          for (final t in txs) (loai: t.type, categoryId: t.categoryId, ghiChu: t.note, ngay: t.date),
        ]));
      } catch (e) {
        // Học lỗi → rơi về bảng từ khoá, không toast (spec B1 mục 6).
        debugPrint('[GoiYDanhMuc] học mô hình lỗi: $e');
        bo = null;
      }
    }
    // Dự án C: mô hình theo số tiền, học từ CÙNG lượt đọc sổ. `getAll` đã bỏ hàng có `deletedAt`; `isDeleted` là cờ
    // xoá mềm thứ hai của bảng — mẫu học không được chứa khoản người dùng đã bỏ.
    BoPhanLoaiSoTien? boTien = _boSoTienTiem;
    if (boTien == null) {
      try {
        boTien = BoPhanLoaiSoTien.hoc(mauSoTienTu([
          for (final t in txs)
            (
              loai: t.type,
              categoryId: t.categoryId,
              ghiChu: t.note,
              soTien: t.amount,
              walletId: t.walletId,
              ngay: t.date,
              daXoa: t.isDeleted,
            ),
        ]));
      } catch (e) {
        debugPrint('[GoiYDanhMuc] học mô hình số tiền lỗi: $e');
        boTien = null;
      }
    }
    return (
      viHayDung: bang,
      boPhanLoai: bo,
      boSoTien: boTien,
      // Đường sửa: mẫu của CHÍNH giao dịch đang sửa phải ra khỏi phép đếm — hàm đề xuất cộng bản đang gõ vào.
      mauDeXuat: dangSua == null
          ? null
          : mauHocTu([
              for (final t in txs)
                if (t.id != dangSua) (loai: t.type, categoryId: t.categoryId, ghiChu: t.note, ngay: t.date),
            ]),
    );
  }

  @override
  Future<List<PhanHoiGoiY>?> docPhanHoi(int idaccount) async {
    final store = _phanHoi;
    if (store == null) return null;
    return store.doc(idaccount);
  }

  /// Từ `_ghiPhanHoi` của trang.
  @override
  void ghiPhanHoi({required int idaccount, required CategorySuggestion goiY, required String ketQua, String? chon}) {
    final store = _phanHoi;
    if (store == null) return;
    unawaited(store
        .ghi(idaccount: idaccount, goiY: goiY, ketQua: ketQua, chonCategoryId: chon)
        .catchError((Object e) => debugPrint('[GoiYDanhMuc] ghi phản hồi lỗi: $e')));
  }

  @override
  Future<List<Category>> danhMucChonDuoc(int idaccount) => _danhMuc.selectableChildrenAll(accountId: idaccount);

  @override
  Future<Map<String, List<String>>> tuKhoa(int idaccount) => _danhMuc.loadAllKeywords(accountId: idaccount);

  /// Từ `_napDanhMucVaTuKhoa` của trang.
  @override
  Future<(List<Category>, Map<String, List<String>>)> napDanhMucVaTuKhoa(int? idaccount) async {
    if (idaccount == null) return (const <Category>[], const <String, List<String>>{});
    try {
      return (
        await _danhMuc.selectableChildrenAll(accountId: idaccount),
        await _danhMuc.loadAllKeywords(accountId: idaccount),
      );
    } catch (e) {
      debugPrint('[NhapNhanh] đọc danh mục / từ khoá lỗi: $e');
      return (const <Category>[], const <String, List<String>>{});
    }
  }

  @override
  Future<void> luuTuKhoa({required int idaccount, required String categoryId, required List<String> tuKhoa}) =>
      _danhMuc.saveKeywords(accountId: idaccount, categoryId: categoryId, keywords: tuKhoa);

  @override
  Future<String?> viTheoNguon(int idaccount, String nguon, String? duoi) async =>
      _viTheoNguon?.doc(idaccount, nguon, duoi);

  @override
  Future<String?> viTheoNguonChung(int idaccount, String nguon) async => _viTheoNguon?.docTheoNguon(idaccount, nguon);

  @override
  Future<void> nhoViTheoNguon(int idaccount, String nguon, String? duoi, String walletId) async =>
      _viTheoNguon?.ghi(idaccount, nguon, duoi, walletId);

  /// Từ `_hangChoMacDinh` của trang.
  @override
  Future<List<DienSanBienDong>> hangBienDongCho(int idaccount) async {
    final tiem = _hangBienDongChoTiem;
    if (tiem != null) return tiem(idaccount);
    final ds = <DienSanBienDong>[];
    for (final n in await sl<ThongBaoNguon>().getAll(idaccount)) {
      final link = n.deeplink;
      if (n.kind != kKindBienDongSoDu || n.dismissedAt != null || link == null) continue;
      final h = dienSanBienDongTuQuery(Uri.tryParse(link)?.queryParameters ?? const {});
      if (h != null) ds.add(h);
    }
    return ds;
  }

  /// Từ `_khoanTrongSoMacDinh` của trang.
  @override
  Future<List<KhoanSo>> khoanTrongSo(int idaccount) async {
    final tiem = _khoanTrongSoTiem;
    if (tiem != null) return tiem(idaccount);
    return [
      for (final t in await sl<TransactionRepository>().getAll(idaccount))
        (id: t.id, soTien: t.amount, loai: t.type, ngay: t.date, ghiChu: t.note),
    ];
  }

  /// Từ `_xoaHangBienDong` của trang.
  @override
  Future<void> xoaHangBienDong(int idaccount, String khoa) async {
    final xoa = _xoaBienDongTiem ?? (sl.isRegistered<ThongBaoNguon>() ? sl<ThongBaoNguon>().xoaCung : null);
    try {
      await xoa?.call(idaccount, khoa);
    } catch (e) {
      debugPrint('[BienDong] xoá hàng biến động lỗi: $e');
    }
  }

  @override
  Future<String?> duongDanAnh(DienSanBienDong d) async {
    final anh = d.anh;
    if (anh == null) return null;
    // A5: ảnh quét nằm ở kho RIÊNG (`anh_quet/`), kèm danh sách món (mục 11.2b).
    return d.laQuet ? _khoAnhQuet?.duongDan(anh) : _khoBienLai?.duongDan(anh);
  }

  @override
  Future<List<MonHang>> docMonQuet(String anh) async => await _khoAnhQuet?.docMon(anh) ?? const [];

  /// Từ `_xoaAnhBienLai` của trang.
  @override
  Future<void> xoaAnhBienLai(String? anh) async {
    try {
      await _khoBienLai?.xoa(anh);
    } catch (e) {
      debugPrint('[BienLai] xoá ảnh lỗi: ${e.runtimeType}');
    }
  }

  @override
  Future<void> xoaAnhQuet(String? anh) async => _khoAnhQuet?.xoa(anh);

  /// Từ `_lookupBudget` của trang.
  @override
  Future<BudgetView?> traNganSach(int idaccount, String categoryId) {
    final tiem = _traNganSachTiem;
    if (tiem != null) return tiem(idaccount, categoryId);
    if (!sl.isRegistered<BudgetRepository>()) return Future.value(null);
    return sl<BudgetRepository>().activeBudgetForCategory(idaccount, categoryId);
  }
}
