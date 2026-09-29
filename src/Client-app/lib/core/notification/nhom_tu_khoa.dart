/// Tiền tố `dedupeKey` → nhóm công tắc (B5b, 2026-09-29).
///
/// Nhật ký B5a (`app_notification_events`) chỉ mang **khoá**, không mang loại,
/// nên B5b cần suy nhóm từ khoá. `deeplinkTuDedupeKey` đã so tiền tố để suy
/// **route**; hàm này so cùng những tiền tố ấy để suy **nhóm** — hai câu hỏi
/// khác nhau (nhiều nhóm chung một route), nên là hai hàm.
///
/// ⚠️ Đây là bản SAO của `nhomCua(kind)` qua tiền tố khoá của bộ luật, và nó
/// được canh: `notification_deeplink_test.dart` chạy mọi ứng viên của
/// `tatCaUngVien()` rồi đòi `nhomTuKhoa(khoá) == nhomCua(loại)`. Thêm loại mới
/// mà quên tiền tố ở đây thì ca ấy đỏ.
///
/// `null` = không thuộc nhóm có công tắc nào: khoá nhắc ghi chép (công tắc riêng
/// `nhacGhiChepBat`), khoá lạ của bản app cũ, khoá rỗng.
library;

import 'prefs/notification_prefs.dart';

NotificationGroup? nhomTuKhoa(String dedupeKey) =>
    switch (dedupeKey.split(':').first) {
      'billDue' ||
      'billOverdue' ||
      'billAuto' ||
      'billAutoFail' ||
      'billConflict' =>
        NotificationGroup.bill,
      'budgetNear' ||
      'budgetOver' ||
      'budgetRebalance' ||
      'bigSpend' =>
        NotificationGroup.budget,
      'goalDone' ||
      'goalCycle' ||
      'goalBehind' ||
      'goalMilestone' ||
      'goalAuto' ||
      'goalAutoFail' =>
        NotificationGroup.goal,
      'syncFailed' || 'walletNeg' || 'walletLow' => NotificationGroup.system,
      'weekly' => NotificationGroup.summary,
      _ => null,
    };
