/// Cổng "ví bị giữ vì trùng tên" (G63) của `SyncEngine` (G88 gạch 4, spec 2026-10-15 mục 3.1). Hạ tầng `core` không biết mảng
/// ví: bản thi hành là `ViBiGiuDongBo` (`features/wallet/data/vi_bi_giu_dong_bo.dart`), DI truyền vào engine (tham số BẮT
/// BUỘC). `ThuGomThaoTacDay` (`thu_gom_day.dart`) gọi hai phương thức theo ĐÚNG thứ tự: [CongViBiGiu.thaViKhongConCap] → đọc hàng chờ đẩy →
/// [CongViBiGiu.banGhiGiuKhoiDay] — thả làm mới giờ sửa của hàng đang chờ, nên phải chạy TRƯỚC khi đọc chúng.
library;

import '../database/app_database.dart';

/// Id các bản ghi `ThuGomThaoTacDay.collectPendingOps` phải bỏ khỏi lô đẩy (bảng 4.4 spec G63) — record để `core` không cần kiểu
/// `BanGhiBiGiu` của `features/wallet/domain`.
typedef BanGhiGiuKhoiDay = ({
  Set<String> vi,
  Set<String> hoaDon,
  Set<String> mucTieu,
  Set<String> giaoDich
});

abstract interface class CongViBiGiu {
  /// Thả mọi ví mang cờ trùng tên mà KHÔNG còn ví cùng tên (ví kia bị xoá / đổi tên ở máy khác): gỡ cờ + mốc chặn, làm mới
  /// giờ sửa của ví và của bản ghi đang chờ từng bị giữ vì nó.
  Future<void> thaViKhongConCap(int idaccount);

  /// Id bản ghi phải giữ khỏi lô đẩy, tính trên đúng các hàng ĐANG CHỜ mà engine vừa đọc.
  Future<BanGhiGiuKhoiDay> banGhiGiuKhoiDay(
    int idaccount, {
    required Iterable<Bill> hoaDon,
    required Iterable<Goal> mucTieu,
    required Iterable<Transaction> giaoDich,
  });
}
