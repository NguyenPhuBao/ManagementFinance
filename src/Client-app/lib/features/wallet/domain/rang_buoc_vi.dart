/// Ràng buộc PostgreSQL thi hành trên bảng `wallet` — **định nghĩa duy nhất**
/// phía client, dùng chung cho datasource (chốt chặn) và màn Thêm ví (báo sớm).
///
/// Đo `pg_indexes` ngày 2026-09-10 (đây là *partial unique index*, KHÔNG hiện
/// ở `pg_constraint` — nên phép đo 2026-09-09 từng kết luận sai là "không có
/// unique index nào ở phía server"):
///
/// ```
/// uq_wallet_account_name_active  ("Idaccount", "Name") WHERE "Delete_at" IS NULL
/// ```
///
/// Vi phạm là server trả 23505 → `WALLET_NAME_DUPLICATE` hoặc `UNIQUE_VIOLATION`
/// → `SyncEngine` xếp bản ghi **vĩnh viễn**: ví không bao giờ lên server, và mọi
/// giao dịch trong ví ấy vỡ `fk_transaction_wallet` rồi thử lại ở mọi chu kỳ —
/// không lỗi, không log, không gì trên màn hình. Cùng lớp lỗi với
/// `ewallet`/`debt` (đóng 2026-09-09).
///
/// Ba điều luật này theo, vì index phía server theo đúng thế:
/// - Chỉ nhìn hàng **chưa xoá mềm**. Ví đã xoá không giữ chỗ.
/// - **Không** nhìn `status`: ví lưu trữ vẫn còn `Delete_at IS NULL` nên vẫn
///   nằm trong index.
/// - Chỉ trong **một tài khoản** — nơi gọi phải đưa vào danh sách ví của đúng
///   tài khoản ấy.
///
/// Từng có luật thứ hai, "một ví Tiết kiệm mỗi tài khoản"
/// (`uq_wallet_saving_active`), chỉ tồn tại ở SQL. Backend bỏ index ấy ở
/// `database/12` (CSDL dev áp 2026-09-11), và client gỡ chốt tạm cùng ngày
/// (G30). ⚠️ Máy chủ nào chưa áp tệp 12 vẫn từ chối ví Tiết kiệm thứ hai — bản
/// ghi ấy kẹt vĩnh viễn như trên.
library;

import '../../../core/category/category_name.dart';
import '../data/models/wallet_entity.dart';

/// Chuẩn hoá tên ví để so trùng: NFC → chữ thường → trim → gom khoảng trắng.
///
/// Server so khớp **chính xác từng ký tự** (`"Name"` trần trong index), nên
/// client siết hơn là an toàn — và siết bằng đúng phép của tên danh mục để dự
/// án chỉ có **một** định nghĩa "hai tên là một".
String chuanHoaTenVi(String ten) => normalizeCategoryName(ten);

/// Ví đang tồn tại (chưa xoá mềm) mang tên trùng với [ten], hoặc `null`.
///
/// [boQuaId] là ví đang được sửa — không tự trùng với chính mình.
WalletEntity? viTrungTen(
  Iterable<WalletEntity> viHienCo,
  String ten, {
  String? boQuaId,
}) {
  final khoa = chuanHoaTenVi(ten);
  for (final w in viHienCo) {
    if (w.isDeleted || w.id == boQuaId) continue;
    if (chuanHoaTenVi(w.name) == khoa) return w;
  }
  return null;
}

String thongBaoTrungTen(String ten) =>
    'Đã có ví tên "$ten". Hãy đặt tên khác.';
