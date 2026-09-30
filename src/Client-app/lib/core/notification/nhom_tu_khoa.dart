/// Tiền tố `dedupeKey` → loại → nhóm công tắc (B5b, 2026-09-29).
///
/// Nhật ký B5a (`app_notification_events`) chỉ mang **khoá**, không mang loại,
/// nên B5b cần suy loại từ khoá: nhóm để học giờ và xét nhóm bị lờ, còn
/// `luonBao(loại)` để bỏ những thông báo công tắc nhóm không tắt được.
/// `deeplinkTuDedupeKey` đã so cùng những tiền tố ấy để suy **route** — câu hỏi
/// khác (nhiều loại chung một route), nên là hàm khác.
///
/// ⚠️ Đây là bản SAO của tiền tố khoá mà bộ luật đặt, và nó được canh:
/// `notification_deeplink_test.dart` chạy mọi ứng viên của `tatCaUngVien()` rồi
/// đòi `loaiTuKhoa(khoá) == loại`. Thêm loại mới mà quên tiền tố ở đây thì ca
/// ấy đỏ.
///
/// `null` = không ứng với loại nào: khoá nhắc ghi chép (công tắc riêng
/// `nhacGhiChepBat`), khoá lạ của bản app cũ, khoá rỗng.
library;

import 'notification_rules.dart';
import 'prefs/notification_prefs.dart';

NotificationKind? loaiTuKhoa(String dedupeKey) =>
    switch (dedupeKey.split(':').first) {
      'budgetNear' => NotificationKind.budgetNearLimit,
      'budgetOver' => NotificationKind.budgetOverspent,
      'budgetRebalance' => NotificationKind.budgetRebalance,
      'bigSpend' => NotificationKind.largeExpense,
      'billDue' => NotificationKind.billDueSoon,
      'billOverdue' => NotificationKind.billOverdue,
      'billAuto' => NotificationKind.billAutoPaid,
      'billAutoFail' => NotificationKind.billAutoPayFailed,
      'billConflict' => NotificationKind.billPaidOnOtherDevice,
      'goalDone' => NotificationKind.goalCompleted,
      'goalCycle' => NotificationKind.goalCycleReady,
      'goalBehind' => NotificationKind.goalBehind,
      'goalMilestone' => NotificationKind.goalMilestone,
      'goalAuto' => NotificationKind.goalAutoDeposited,
      'goalAutoFail' => NotificationKind.goalAutoDepositFailed,
      'syncFailed' => NotificationKind.syncFailed,
      'walletNeg' => NotificationKind.walletNegative,
      'walletLow' => NotificationKind.walletLowBalance,
      'weekly' => NotificationKind.weeklySummary,
      'bienDong' => NotificationKind.bienDongSoDu,
      _ => null,
    };

/// Nhóm công tắc của khoá — `nhomCua(loaiTuKhoa(khoá))`, không bảng thứ hai.
NotificationGroup? nhomTuKhoa(String dedupeKey) {
  final loai = loaiTuKhoa(dedupeKey);
  return loai == null ? null : nhomCua(loai);
}
