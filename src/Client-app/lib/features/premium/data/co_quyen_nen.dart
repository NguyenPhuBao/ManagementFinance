import 'dart:async';

import '../../../core/di/injection_container.dart';
import '../domain/quyen_tinh_nang.dart';
import 'models/trang_thai_goi.dart';
import 'repositories/goi_repository.dart';

/// Cửa quyền của những thứ chạy NỀN, không có `BuildContext` — bộ tự trả hoá đơn, bộ trích tự động, thông báo cân
/// đối ngân sách, nhập biến động số dư / biên lai (spec phân quyền 2026-10-08 mục 4.3 (3)). Không có quyền → người gọi
/// BỎ LƯỢT: không ghi gì, không đổi mốc, cờ của người dùng giữ nguyên (chốt *"dừng chạy, giữ công tắc"*).
///
/// Chưa có phiên (`idaccount == null`) → `true`: không đoán khi chưa biết tài khoản. Vì thế mọi lượt quét phải đặt gói
/// TRƯỚC — đường nền qua `datGoi` của `LuotNen`, đường trong app qua hook `datGoi` của `PhienDieuPhoiThat.moPhienCucBo`
/// (G93: thiếu nó thì lượt quét đầu mỗi phiên, chạy trước `AuthSuccess`, thả Basic qua).
bool coQuyenNen(MaQuyen ma, {GoiRepository? goi, DateTime Function()? clock}) {
  final g = goi ?? sl<GoiRepository>();
  if (g.idaccount == null) return true;
  return duocDung(ma, g.hienTai, (clock ?? DateTime.now)());
}

/// Gọi [khiDoi] với tài khoản đang đăng nhập mỗi khi `duocDung` của MỘT trong [ma] đổi giữa hai lượt phát liên tiếp của
/// [GoiRepository.theoDoi] (B1, spec 2026-10-27 mục 5: admin đổi quyền → socket `account.permissions_updated` → `lamMoi` →
/// lượt phát này → `ReminderScheduler.resync`). Lượt phát không đổi quyền nào trong [ma] (mỗi `lamMoi`, `resumed` giãn 5
/// phút) KHÔNG gọi. Chưa có phiên → bỏ qua. [khiDoi] ném → nuốt (lượt quét kế vẫn `resync`).
StreamSubscription<TrangThaiGoi> noiKhiQuyenDoi(
  GoiRepository goi,
  Set<MaQuyen> ma,
  Future<void> Function(int idaccount) khiDoi, {
  DateTime Function()? clock,
}) {
  final now = clock ?? DateTime.now;
  Map<MaQuyen, bool> doc(TrangThaiGoi t) => {for (final m in ma) m: duocDung(m, t, now())};
  var truoc = doc(goi.hienTai);
  return goi.theoDoi.listen((t) {
    final nay = doc(t);
    final doi = ma.any((m) => nay[m] != truoc[m]);
    truoc = nay;
    final id = goi.idaccount;
    if (!doi || id == null) return;
    unawaited(() async {
      try {
        await khiDoi(id);
      } catch (_) {}
    }());
  });
}
