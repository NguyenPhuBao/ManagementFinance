import '../../features/bill/data/services/bill_payment_conflict_resolver.dart';
import '../../features/wallet/data/services/vi_trung_ten_resolver.dart';
import '../di/injection_container.dart';
import 'sync_engine.dart';

/// Nối các bộ nghe kết quả đẩy vào `SyncEngine.pushResultStream` — gọi ĐÚNG MỘT LẦN cho mỗi engine Dart:
/// `main.dart` (engine của app) và `core/nen/chay_nen.dart` (engine nền của WorkManager).
///
/// - `BillPaymentConflictResolver` gỡ khoản trả mà server từ chối bằng `BILL_ALREADY_PAID` / `BILL_PERIOD_ALREADY_PAID`
///   (máy khác trả trước). Lượt nền đẩy mà không nối thì khoản chi lỗi vĩnh viễn, không ai gỡ (spec tự chuyển tiền
///   chạy nền mục 4).
/// - `ViTrungTenResolver` (G63): ví bị từ chối vì trùng tên thì đặt cờ — engine giữ nó lại.
///
/// `pushResultStream` là broadcast và singleton, nên nối hai lần trong CÙNG engine là hoàn tác chạy hai lượt cho cùng
/// một khoản chi.
void noiBoNgheKetQuaDay() {
  sl<BillPaymentConflictResolver>().batDauNghe(sl<SyncEngine>().pushResultStream);
  sl<ViTrungTenResolver>().batDauNghe(sl<SyncEngine>().pushResultStream);
}
