/// Nguồn dữ liệu của form Thêm / Sửa giao dịch ở CHẾ ĐỘ NHÀ (gia đình 1A, spec 2026-11-01 mục 9).
///
/// Chỉ ví chung đang hoạt động và danh mục của nhà. Mọi thứ còn lại của form cá nhân đều là của MỘT tài khoản và không có
/// nghĩa ở nhà: gợi ý học từ lịch sử cá nhân, từ khoá, phản hồi gợi ý, dấu danh mục AI, ví theo nguồn tin, biên động /
/// biên lai / ảnh quét, ngân sách riêng, trợ lý AI. Chúng trả rỗng / `null` và các phép ghi KHÔNG làm gì — để khoản của
/// nhà không dạy mô hình cá nhân và không đẻ hàng vào bảng cục bộ của ai.
///
/// Không đăng ký DI: kế hoạch 1B dựng theo `idNha` của trang.
library;

import 'dart:async';

import '../../../core/database/daos/category_dao.dart';
import '../../budget/data/models/budget_entity.dart';
import '../../category/data/models/category_entity.dart';
import '../../category/data/models/category_suggestion.dart';
import '../../category/domain/phan_loai_ghi_chu.dart' show PhanHoiGoiY;
import '../../transaction/data/doc_cau_bang_ai.dart';
import '../../transaction/data/them_giao_dich_nguon.dart';
import '../../transaction/domain/dien_san_bien_dong.dart';
import '../../transaction/domain/doc_mon_hang.dart';
import '../../transaction/domain/vi_hay_dung.dart';
import '../../wallet/data/models/wallet_entity.dart';
import 'repositories/du_lieu_nha_repository.dart';

class ThemGiaoDichNguonNha implements ThemGiaoDichNguon {
  ThemGiaoDichNguonNha({required this.idNha, required DuLieuNhaRepository duLieu, required CategoryDao categoryDao})
      : _duLieu = duLieu,
        _categoryDao = categoryDao;

  final int idNha;
  final DuLieuNhaRepository _duLieu;
  final CategoryDao _categoryDao;

  @override
  Future<List<WalletEntity>> napViDangDung(int? idaccount) => _duLieu.viChungDangDung(idNha);

  // Không học từ khoản của nhà: `LichSuHoc` rỗng (bảng ví hay dùng rỗng, không mô hình).
  @override
  LichSuHoc napLichSu(int? idaccount, {String? dangSua}) =>
      (viHayDung: const <String, String>{}, boPhanLoai: null, boSoTien: null, mauDeXuat: null);

  @override
  Future<List<PhanHoiGoiY>?> docPhanHoi(int idaccount) async => null;

  @override
  void ghiPhanHoi({required int idaccount, required CategorySuggestion goiY, required String ketQua, String? chon}) {}

  @override
  void danhDauDanhMucAi({required int idaccount, required String transactionId, required String categoryId}) {}

  @override
  void goDanhDauDanhMucAi({required int idaccount, required String transactionId}) {}

  /// Danh mục SỐNG của nhà, bỏ nhóm (bộ chọn chỉ nhận danh mục con). Không qua cửa quét 40: luật ẩn theo khuôn là của
  /// danh mục cá nhân, danh mục nhà không có khuôn.
  @override
  Future<List<CategoryEntity>> danhMucChonDuoc(int idaccount) async => [
        for (final c in await _categoryDao.getCuaNha(idNha))
          if (!c.isGroup) CategoryEntity.fromDrift(c),
      ];

  @override
  Future<Map<String, List<String>>> tuKhoa(int idaccount) async => const <String, List<String>>{};

  @override
  Future<(List<CategoryEntity>, Map<String, List<String>>)> napDanhMucVaTuKhoa(int? idaccount) async =>
      (await danhMucChonDuoc(idaccount ?? 0), const <String, List<String>>{});

  @override
  Future<void> luuTuKhoa({required int idaccount, required String categoryId, required List<String> tuKhoa}) async {}

  @override
  DocCauBangAi? get docAi => null;

  @override
  Future<String?> viTheoNguon(int idaccount, String nguon, String? duoi) async => null;

  @override
  Future<String?> viTheoNguonChung(int idaccount, String nguon) async => null;

  @override
  Future<void> nhoViTheoNguon(int idaccount, String nguon, String? duoi, String walletId) async {}

  @override
  Future<List<DienSanBienDong>> hangBienDongCho(int idaccount) async => const <DienSanBienDong>[];

  @override
  Future<List<KhoanSo>> khoanTrongSo(int idaccount) async => const <KhoanSo>[];

  @override
  Future<void> xoaHangBienDong(int idaccount, String khoa) async {}

  @override
  Future<String?> duongDanAnh(DienSanBienDong d) async => null;

  @override
  Future<List<MonHang>> docMonQuet(String anh) async => const <MonHang>[];

  @override
  Future<void> xoaAnhBienLai(String? anh) async {}

  @override
  Future<void> xoaAnhQuet(String? anh) async {}

  @override
  Future<BudgetView?> traNganSach(int idaccount, String categoryId) async => null;
}
