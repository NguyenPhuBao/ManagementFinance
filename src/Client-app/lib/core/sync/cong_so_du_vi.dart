/// Cổng số dư ví của `SyncEngine` (G88 gạch 4, spec 2026-10-15 mục 3.1) — đúng hai phép engine gọi khi kéo về. Hạ tầng `core`
/// không biết mảng ví: bản thi hành là `SoDuViService` (`features/wallet/data/so_du_vi_service.dart` — nơi DUY NHẤT ghi
/// `wallets.balance`, quét 6), DI truyền vào engine (tham số BẮT BUỘC — thiếu là lỗi biên dịch, không phải "bỏ bước").
library;

abstract interface class CongSoDuVi {
  /// Đặt neo cho các ví sắp bị một giao dịch kéo về chạm tới — engine gọi **trước** khi ghi giao dịch kéo về (G85).
  Future<void> datNeoNhieuVi(Iterable<String> walletIds);

  /// Tính lại số dư từ sổ cho các ví vừa bị lượt kéo về chạm tới.
  Future<void> tinhLaiNhieuVi(Iterable<String> walletIds);
}
