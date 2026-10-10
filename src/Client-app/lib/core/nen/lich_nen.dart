/// Mốc lượt nền kế tiếp của hai bộ tự chuyển tiền — tự trả hoá đơn, trích mục tiêu (spec
/// `2026-10-10-tu-chuyen-tien-chay-nen-design.md` mục 3.1).
library;

import '../../features/bill/domain/bill_pay_status.dart';
import '../../features/goal/data/models/goal_entity.dart';
import '../../features/goal/domain/goal_auto_deposit.dart';
import '../database/app_database.dart' show Bill;
import 'kenh_tu_chuyen_tien.dart';

/// `moc` — mốc **ở tương lai** gần nhất cho lượt một-lần (`null` = không hẹn).
/// `coTuDong` — còn thứ gì bật tự động → giữ lượt định kỳ 6 giờ.
typedef LichNenKeTiep = ({DateTime? moc, bool coTuDong});

/// Tính lịch lượt nền.
///
/// - Hoá đơn (bật tự trả, còn phải trả, có ví và danh mục, chưa xoá — các điều kiện của `denLuotTuTra` trừ phép so
///   ngày): ngày đến hạn lúc **giờ nhắc chung** [gioNhac]:[phutNhac].
/// - Mục tiêu (bật trích, chưa xong, còn thiếu): `kyKeTiep` — hàm sẵn có, chỉ trả mốc SAU `now`; không chép lại phép
///   tính kỳ.
///
/// ⚠️ Kỳ đã tới hạn mà chưa xong (ví không đủ) KHÔNG được hẹn "ngay": lượt một-lần sẽ tự hẹn lại ngay — vòng lặp tốn
/// pin. Nó chờ lượt định kỳ hoặc lần mở app; `coTuDong` vẫn `true` để giữ lượt định kỳ.
///
/// [traDuoc] / [trichDuoc] — quyền gói (`coQuyenNen`): không có thì loại khỏi cả hai vế, Basic không cần đánh thức máy.
LichNenKeTiep lichNenKeTiep({
  required List<Bill> bills,
  required List<GoalEntity> goals,
  required DateTime now,
  required int gioNhac,
  required int phutNhac,
  bool traDuoc = true,
  bool trichDuoc = true,
}) {
  DateTime? moc;
  var coTuDong = false;
  void xet(DateTime m) {
    final cu = moc;
    if (m.isAfter(now) && (cu == null || m.isBefore(cu))) moc = m;
  }

  if (traDuoc) {
    for (final b in bills) {
      if (!b.autoPayEnabled || b.isDeleted || !conPhaiTra(b)) continue;
      if (b.walletId == null || b.categoryId == null) continue;
      coTuDong = true;
      xet(DateTime(b.dueDate.year, b.dueDate.month, b.dueDate.day, gioNhac, phutNhac));
    }
  }
  if (trichDuoc) {
    for (final g in goals) {
      if (g.isDeleted || !g.autoDepositEnabled || g.isCompleted || g.remainingAmount <= 0) continue;
      coTuDong = true;
      final k = kyKeTiep(
        mocNeo: g.timeCycleTakeMoney,
        lanChayGanNhat: g.autoDepositLastRun,
        chuKy: g.cycleTakeMoney,
        now: now,
      );
      if (k != null) xet(k);
    }
  }
  return (moc: moc, coTuDong: coTuDong);
}

/// Hẹn lượt nền qua kênh Kotlin — **chỉ engine của app** dùng. Lượt nền trả mốc qua `nenXong` thay vì gọi đây: tự
/// `REPLACE` công việc đang chạy là WorkManager huỷ nó giữa chừng.
class LichNen {
  LichNen({required this.tinh, required this.kenh});

  final Future<LichNenKeTiep> Function(int idaccount, DateTime now) tinh;
  final KenhTuChuyenTien kenh;

  /// Lịch đã gửi lần trước — chỉ gửi lại khi đổi.
  LichNenKeTiep? _daHen;

  Future<LichNenKeTiep> tinhCho(int idaccount, {DateTime? now}) => tinh(idaccount, now ?? DateTime.now());

  /// Gửi kênh chỉ khi lịch ĐỔI — `resync` chạy sau mọi chu kỳ đồng bộ 15 phút.
  Future<void> henNeuDoi(int idaccount, {DateTime? now}) async {
    final l = await tinhCho(idaccount, now: now);
    if (l == _daHen) return;
    await kenh.henNen(l);
    _daHen = l;
  }

  /// Đăng xuất / phiên chết: không ai đăng nhập thì không ai uỷ quyền chuyển tiền.
  Future<void> huy() async {
    await kenh.henNen((moc: null, coTuDong: false));
    _daHen = null;
  }
}
