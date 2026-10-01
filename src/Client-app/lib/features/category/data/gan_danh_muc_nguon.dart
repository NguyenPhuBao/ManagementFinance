/// C1 — nguồn dữ liệu và đường ghi mặc định của màn *Gắn danh mục nhanh* (spec
/// `2026-09-28-c1-gan-danh-muc-hang-loat-design.md` §4–§5). Tách khỏi trang để thử được bằng CSDL bộ nhớ; trang nhận
/// chúng qua tham số tiêm, đúng khuôn `viHayDung` / `boPhanLoai` của màn Thêm giao dịch.
library;

import 'package:flutter/foundation.dart' show debugPrint;

import '../../../core/database/app_database.dart';
import '../../transaction/data/models/transaction_entity.dart';
import '../../transaction/data/repositories/transaction_repository.dart';
import '../domain/gan_hang_loat.dart';
import '../domain/phan_loai_ghi_chu.dart';
import 'goi_y_phan_hoi_store.dart';
import 'models/category_suggestion.dart';
import 'repositories/category_management_repository.dart';

/// Thứ màn duyệt cần để dựng: các dòng, danh mục chọn được (cho chip và bảng chọn), và tên ví (dòng phụ).
class DuLieuGanDanhMuc {
  final List<DongGanDanhMuc> dong;
  final List<Category> chonDuoc;
  final Map<String, String> tenVi;
  const DuLieuGanDanhMuc({required this.dong, required this.chonDuoc, required this.tenVi});
}

/// Đọc sổ, học mô hình B1 từ CHÍNH sổ ấy (cùng phép với màn Thêm giao dịch), nạp cặp đang bị thôi gợi ý, rồi dựng
/// danh sách qua `dungDanhSachGan`.
///
/// Học lỗi hoặc đọc phản hồi lỗi thì vẫn dựng màn — chỉ là không có dự đoán / không thôi gợi ý: màn thành công cụ gắn
/// tay hàng loạt, vẫn có ích (spec §6).
Future<DuLieuGanDanhMuc> taiDuLieuGan({
  required AppDatabase db,
  required CategoryManagementRepository danhMuc,
  required GoiYPhanHoiStore? phanHoi,
  required int idaccount,
}) async {
  final txs = await db.transactionDao.getAll(idaccount);
  final chonDuoc = await danhMuc.selectableChildrenAll(accountId: idaccount);
  BoPhanLoaiGhiChu? mo;
  try {
    mo = BoPhanLoaiGhiChu.hoc(mauHocTu([
      for (final t in txs) (loai: t.type, categoryId: t.categoryId, ghiChu: t.note, ngay: t.date),
    ]));
  } catch (e) {
    debugPrint('[GanDanhMuc] học mô hình lỗi: $e');
  }
  var tatCap = <(String, String)>{};
  if (mo != null && phanHoi != null) {
    try {
      tatCap = tatCapTu(await phanHoi.doc(idaccount), mo.mau);
    } catch (e) {
      debugPrint('[GanDanhMuc] đọc phản hồi lỗi: $e');
    }
  }
  // Bảng tra TÊN ví (dòng phụ "ngày · ví"): giao dịch cũ có thể nằm ở ví nay đã lưu trữ → `getAll`, không `getActive`.
  final vi = await db.walletDao.getAll(idaccount);
  return DuLieuGanDanhMuc(
    dong: dungDanhSachGan(giaoDich: txs, chonDuoc: chonDuoc, mo: mo, tatCap: tatCap),
    chonDuoc: chonDuoc,
    tenVi: {for (final w in vi) w.id: w.name},
  );
}

/// Ghi một dòng: đổi `categoryId` qua `TransactionRepository.updateTransaction` — đường ấy lo đồng bộ (`pending`,
/// mốc `updatedAt` mới) và số dư (không đổi, vì chỉ danh mục đổi). Không ghi thẳng DAO.
///
/// ⚠️ Đọc lại hàng TƯƠI trước khi ghi: `updateTransaction` ghi đủ mọi cột của entity, nên ghi từ ảnh chụp lúc mở màn
/// là đè mất một lần sửa số tiền / ghi chú vừa kéo về từ máy khác — rồi mốc `updatedAt` mới làm bản cũ ấy THẮNG trên
/// server (LWW). Hàng đã đổi đến mức không còn "cần gắn" (đã có danh mục, đã xoá) thì từ chối — dòng ấy tính là chưa
/// lưu được.
Future<void> apDungGan({
  required AppDatabase db,
  required TransactionRepository repo,
  required DongGanDanhMuc dong,
  required String categoryId,
}) async {
  final hienTai = await db.transactionDao.getById(dong.giaoDich.id);
  if (hienTai == null || !xetGan(hienTai)) {
    throw StateError('Giao dịch ${dong.giaoDich.id} đã đổi từ lúc mở màn');
  }
  final before = TransactionEntity.fromDrift(hienTai);
  await repo.updateTransaction(before, before.copyWith(categoryId: categoryId));
}

/// Ghi phản hồi của một dòng có dự đoán vào bảng B1 (`nguon = hoc`) — cùng khoá (cụm, danh mục đoán) mà thẻ gợi ý ở
/// màn Thêm giao dịch ghi, nên luật thôi gợi ý của B1 đọc được cả hai nguồn.
Future<void> ghiPhanHoiGan({
  required GoiYPhanHoiStore store,
  required int idaccount,
  required DongGanDanhMuc dong,
  required Category duDoan,
  required String ketQua,
  required String chonCategoryId,
}) {
  final d = dong.doan!;
  return store.ghi(
    idaccount: idaccount,
    goiY: CategorySuggestion(
      category: duDoan,
      matchedKeyword: d.cumBoDau,
      nguon: kNguonGoiYHoc,
      amTietChinh: d.cumBoDau,
    ),
    ketQua: ketQua,
    chonCategoryId: chonCategoryId,
  );
}
