/// Phần MỤC TIÊU của lịch lượt nền tự chuyển tiền (spec `2026-10-10-tu-chuyen-tien-chay-nen-design.md` mục 3.1) — tách khỏi
/// `core/nen/lich_nen.dart` 2026-10-15 (G88 gạch 4); `core/nen` chỉ gộp các phần (`gopLichNen`).
///
/// Mục tiêu bật trích, chưa xong, còn thiếu: `kyKeTiep` — hàm sẵn có, chỉ trả mốc SAU `now`; không chép lại phép tính kỳ.
///
/// ⚠️ Kỳ đã tới hạn mà chưa xong (ví không đủ) KHÔNG được hẹn "ngay" — cùng lý do với phần hoá đơn; `coTuDong` vẫn `true`.
///
/// Quyền gói (`coQuyenNen(MaQuyen.goalAutoDeposit)`) xét ở DI: không quyền thì không gọi hàm này.
library;

import '../data/models/goal_entity.dart';
import 'goal_auto_deposit.dart';

({DateTime? moc, bool coTuDong}) mocTrichNen(List<GoalEntity> goals, {required DateTime now}) {
  DateTime? moc;
  var coTuDong = false;
  void xet(DateTime m) {
    final cu = moc;
    if (m.isAfter(now) && (cu == null || m.isBefore(cu))) moc = m;
  }

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
  return (moc: moc, coTuDong: coTuDong);
}
