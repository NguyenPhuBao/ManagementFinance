/// Hai ràng buộc PostgreSQL thi hành trên bảng `wallet` — luật thứ hai đã bỏ ở
/// CSDL ngày 2026-09-11, xem ⚠️ cuối khối — **định nghĩa duy nhất** phía
/// client, dùng chung cho datasource (chốt chặn) và màn Thêm ví (báo sớm).
///
/// Đo `pg_indexes` ngày 2026-09-10 (chúng là *partial unique index*, KHÔNG hiện
/// ở `pg_constraint` — nên phép đo 2026-09-09 từng kết luận sai là "không có
/// unique index nào ở phía server"):
///
/// ```
/// uq_wallet_account_name_active  ("Idaccount", "Name") WHERE "Delete_at" IS NULL
/// uq_wallet_saving_active        ("Idaccount")         WHERE "Type" = 'Saving'
///                                                       AND "Delete_at" IS NULL
/// ```
///
/// Vi phạm là server trả 23505 → `UNIQUE_VIOLATION` → `SyncEngine` xếp bản ghi
/// **vĩnh viễn**: ví không bao giờ lên server, và mọi giao dịch trong ví ấy vỡ
/// `fk_transaction_wallet` rồi thử lại ở mọi chu kỳ — không lỗi, không log,
/// không gì trên màn hình. Cùng lớp lỗi với `ewallet`/`debt` (đóng 2026-09-09).
///
/// Ba điều cả hai luật cùng theo, vì index phía server theo đúng thế:
/// - Chỉ nhìn hàng **chưa xoá mềm**. Ví đã xoá không giữ chỗ.
/// - **Không** nhìn `status`: ví lưu trữ vẫn còn `Delete_at IS NULL` nên vẫn
///   nằm trong index.
/// - Chỉ trong **một tài khoản** — nơi gọi phải đưa vào danh sách ví của đúng
///   tài khoản ấy.
///
/// ⚠️ Luật "một ví Tiết kiệm" là luật **tạm**: nó chỉ tồn tại ở SQL (bản
/// 2026-08-26), không có trong `Rule_project.md`, và app thị trường cho nhiều
/// ví tiết kiệm. Client đã xin backend bỏ index ấy
/// (`docs/superpowers/backend/DA-XONG/WALLET_SAVING_INDEX.md`), và backend đã bỏ
/// ở `database/12` — CSDL dev áp ngày 2026-09-11, đo `pg_indexes`: index không
/// còn. Việc còn lại phía client (G30): gỡ [viTietKiemDaCo] cùng hai chỗ gọi nó
/// và test tương ứng; luật trùng tên thì **ở lại**.
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

/// Ví Tiết kiệm đang tồn tại (chưa xoá mềm) của tài khoản, khác [boQuaId],
/// hoặc `null` nếu chưa có.
WalletEntity? viTietKiemDaCo(
  Iterable<WalletEntity> viHienCo, {
  String? boQuaId,
}) {
  for (final w in viHienCo) {
    if (w.isDeleted || w.id == boQuaId) continue;
    if (w.type == 'saving') return w;
  }
  return null;
}

String thongBaoTrungTen(String ten) =>
    'Đã có ví tên "$ten". Hãy đặt tên khác.';

const String thongBaoMotViTietKiem =
    'Mỗi tài khoản chỉ có một ví Tiết kiệm. Ví tiết kiệm thứ hai hãy tạo với '
    'loại Ngân hàng.';
