/// `LuaChonLoc` — dời nguyên văn từ `data/repositories/bao_cao_repository.dart` 2026-10-15 (quét 28:
/// `transaction/domain/tim_giao_dich.dart` dùng nó). Không `export` lại từ tệp repository.
library;

/// Một lựa chọn của bộ lọc trên trang Xuất báo cáo — dùng chung cho chip ví và
/// danh sách danh mục.
///
/// Cố ý **không** trả hàng Drift lên giao diện: trang chỉ cần id để lọc và tên
/// để hiện, và giữ như vậy thì thay nguồn dữ liệu không phải sửa widget.
class LuaChonLoc {
  final String id;
  final String ten;

  const LuaChonLoc({required this.id, required this.ten});
}
