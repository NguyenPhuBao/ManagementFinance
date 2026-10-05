import 'dart:async';

import '../../../../core/database/app_database.dart';
import '../../../../core/sync/sync_models.dart';

/// Đặt cờ `bi_tu_choi_trung_ten` cho ví bị server từ chối vì **trùng tên** (G63).
///
/// Hai máy cùng tài khoản mỗi máy tạo một ví cùng tên trước khi kịp đồng bộ:
/// máy đẩy sau nhận `WALLET_NAME_DUPLICATE` mãi, kéo về một ví cùng tên, và giao
/// dịch của ví bị từ chối vỡ khoá ngoại ở mọi chu kỳ. Cờ này là nửa đầu của lối
/// chữa: `SyncEngine` giữ ví cùng mọi thứ dính tới nó lại (khi còn cặp trùng —
/// `capViTrungTen`), màn Quản lý ví hỏi Gộp / Đổi tên.
///
/// Cùng khuôn `BillPaymentConflictResolver`: engine chỉ phát
/// `SyncOpFailure.code`, ai muốn phản ứng thì tự nghe. Spec
/// `docs/superpowers/specs/2026-10-05-g63-vi-trung-ten-hai-may-design.md` mục 4.3.
class ViTrungTenResolver {
  ViTrungTenResolver({required AppDatabase db}) : _db = db;

  /// Hai mã server dùng cho 23505 trên ví. `UNIQUE_VIOLATION` là đường dự
  /// phòng: backend nhận diện `WALLET_NAME_DUPLICATE` bằng chuỗi nên có thể rơi
  /// về mã chung (CAN-LAM 18 §2.7). Đặt cờ oan cho một vi phạm không phải tên
  /// thì vô hại — không có ví cùng tên thì `capViTrungTen` không giữ gì.
  static const Set<String> maTrungTen = {
    'WALLET_NAME_DUPLICATE',
    'UNIQUE_VIOLATION',
  };

  final AppDatabase _db;
  StreamSubscription<SyncResult>? _sub;

  /// Bắt đầu nghe kết quả đẩy. Gọi nhiều lần thì lượt sau thay lượt trước.
  void batDauNghe(Stream<SyncResult> pushResults) {
    _sub?.cancel();
    _sub = pushResults.listen(_xuLy);
  }

  Future<void> dung() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> _xuLy(SyncResult ketQua) async {
    for (final f in ketQua.failures) {
      // Mã của thực thể khác không nói gì về tên ví (bẫy 3).
      if (f.entity != SyncEntityType.wallet) continue;
      if (!maTrungTen.contains(f.code)) continue;
      await _db.walletDao.danhDauTrungTen(f.localId);
    }
  }
}
