import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/bill_draft.dart';

/// Dựng `BillsCompanion` từ [BillDraft] — chỗ DUY NHẤT ánh xạ form sang hàng Drift (spec Entity Hoá đơn 2026-10-14
/// mục 4.2; trước đó là hai phương thức của `BillDraft`, kéo `drift` vào `domain/`). Thân chép nguyên văn.
///
/// Companion cho đường TẠO: đủ cột, `payStatus` / `isPaid` khởi đầu, `pending`.
BillsCompanion companionTaoTu(
  BillDraft draft, {
  required String id,
  required int idaccount,
  required DateTime now,
}) {
  return BillsCompanion.insert(
    id: id,
    idaccount: idaccount,
    walletId: Value(draft.walletId),
    categoryId: Value(draft.categoryId),
    name: draft.name,
    amount: draft.amount,
    startDate: Value(draft.startDate),
    periodEnd: Value(draft.periodEndHieuLuc),
    dueDate: draft.dueDate,
    payStatus: const Value('Pending'),
    isPaid: const Value(false),
    isRecurrence: Value(draft.isRecurring),
    timeRecurrence: Value(draft.timeRecurrence),
    recurrence: Value(draft.legacyRecurrence),
    timeNotification: Value(draft.timeNotification),
    note: Value(draft.note),
    autoPayEnabled: Value(draft.autoPayEnabled),
    anchorDay: Value(draft.anchorDayHieuLuc),
    syncStatus: const Value('pending'),
    updatedAt: now,
  );
}

/// Companion cho đường SỬA — chỉ những cột form thật sự sở hữu.
///
/// Cố ý KHÔNG đặt `isPaid`/`payStatus`/cờ xoá: form không hỏi gì về chúng, và `BillDao.updateFields` chỉ ghi những cột
/// có mặt, nên vắng mặt ở đây đồng nghĩa với "giữ nguyên". `startDate` thì ngược lại — form nay có ô riêng cho nó nên
/// đường sửa phải ghi được.
///
/// Vẫn ghi ví/danh mục/chu kỳ: hoá đơn do bản client cũ tạo ra mang `walletId = null` và đang kẹt trong hàng đợi đẩy —
/// màn Sửa là đường duy nhất trong app để vá chúng.
BillsCompanion companionSuaTu(
  BillDraft draft, {
  required String id,
  required int idaccount,
  required DateTime now,
}) {
  return BillsCompanion(
    id: Value(id),
    idaccount: Value(idaccount),
    walletId: Value(draft.walletId),
    categoryId: Value(draft.categoryId),
    name: Value(draft.name),
    amount: Value(draft.amount),
    startDate: Value(draft.startDate),
    periodEnd: Value(draft.periodEndHieuLuc),
    dueDate: Value(draft.dueDate),
    isRecurrence: Value(draft.isRecurring),
    timeRecurrence: Value(draft.timeRecurrence),
    recurrence: Value(draft.legacyRecurrence),
    // Value(null) chứ không phải vắng mặt: `updateFields` chỉ ghi những cột
    // CÓ MẶT, nên bỏ trống thì tắt nhắc nhở sẽ không có tác dụng gì.
    timeNotification: Value(draft.timeNotification),
    note: Value(draft.note),
    // Có mặt cả khi tắt: vắng mặt là "giữ nguyên", và tắt công tắc mà app
    // vẫn tiếp tục trừ tiền là lỗi tệ nhất ở vùng này.
    autoPayEnabled: Value(draft.autoPayEnabled),
    anchorDay: Value(draft.anchorDayHieuLuc),
    syncStatus: const Value('pending'),
    updatedAt: Value(now),
  );
}
