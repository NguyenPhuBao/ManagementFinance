import 'package:drift/drift.dart';
import '../../../core/bill/bill_recurrence.dart';
import '../../../core/database/app_database.dart';

/// Giá trị người dùng nhập trên form hoá đơn.
///
/// Tách khỏi widget để phần dựng `BillsCompanion` — nơi từng đánh rơi
/// `walletId`/`categoryId` và ghi chu kỳ vào sai cột — kiểm thử được mà không
/// cần dựng cả cây widget.
class BillDraft {
  final String name;
  final double amount;

  /// Ngày bắt đầu kỳ hoá đơn. Người dùng chọn trên form, ngay phía trên ngày
  /// đến hạn. Trước đây cột này bị đặt cứng bằng thời điểm bấm Lưu.
  final DateTime startDate;

  final DateTime dueDate;

  /// Ví thanh toán. `bill.Idwallet` là NOT NULL phía backend.
  final String walletId;

  /// Danh mục chi. `bill.Idcategory` là NOT NULL phía backend.
  final String categoryId;

  final bool isRecurring;

  /// Một trong `kBillCycle*`. Chỉ có nghĩa khi [isRecurring].
  final String timeRecurrence;

  final String note;

  const BillDraft({
    required this.name,
    required this.amount,
    required this.startDate,
    required this.dueDate,
    required this.walletId,
    required this.categoryId,
    required this.isRecurring,
    required this.timeRecurrence,
    required this.note,
  });

  /// Chuỗi chu kỳ cũ, suy ra từ [isRecurring] + [timeRecurrence].
  ///
  /// Hai cách biểu diễn phải được ghi CÙNG LÚC và khớp nhau: nhánh đẩy đọc cờ
  /// `isRecurrence`, còn một số đường cũ vẫn đọc chuỗi này.
  String get _legacyRecurrence =>
      isRecurring ? legacyFromTimeRecurrence(timeRecurrence) : 'once';

  /// Lời nhắn lỗi nếu hai mốc ngày không hợp lệ, `null` nếu hợp lệ.
  ///
  /// Kỳ hoá đơn chạy từ [startDate] tới [dueDate], nên [startDate] phải nằm
  /// TRƯỚC — trùng ngày cũng không được: kỳ dài 0 ngày, và vì kỳ kế tiếp bắt
  /// đầu đúng tại ngày đến hạn của kỳ này, chuỗi sẽ giậm chân tại chỗ.
  String? get dateError => startDate.isBefore(dueDate)
      ? null
      : 'Ngày bắt đầu phải trước ngày đến hạn thanh toán';

  BillsCompanion toInsertCompanion({
    required String id,
    required int idaccount,
    required DateTime now,
  }) {
    return BillsCompanion.insert(
      id: id,
      idaccount: idaccount,
      walletId: Value(walletId),
      categoryId: Value(categoryId),
      name: name,
      amount: amount,
      startDate: Value(startDate),
      dueDate: dueDate,
      payStatus: const Value('Pending'),
      isPaid: const Value(false),
      isRecurrence: Value(isRecurring),
      timeRecurrence: Value(timeRecurrence),
      recurrence: Value(_legacyRecurrence),
      note: Value(note),
      syncStatus: const Value('pending'),
      updatedAt: now,
    );
  }

  /// Companion cho đường SỬA — chỉ những cột form thật sự sở hữu.
  ///
  /// Cố ý KHÔNG đặt `isPaid`/`payStatus`/cờ xoá: form không hỏi gì về chúng,
  /// và `BillDao.updateFields` chỉ ghi những cột có mặt, nên vắng mặt ở đây
  /// đồng nghĩa với "giữ nguyên". `startDate` thì ngược lại — form nay có ô
  /// riêng cho nó nên đường sửa phải ghi được.
  ///
  /// Vẫn ghi ví/danh mục/chu kỳ: hoá đơn do bản client cũ tạo ra mang
  /// `walletId = null` và đang kẹt trong hàng đợi đẩy — màn Sửa là đường duy
  /// nhất trong app để vá chúng.
  BillsCompanion toUpdateCompanion({
    required String id,
    required int idaccount,
    required DateTime now,
  }) {
    return BillsCompanion(
      id: Value(id),
      idaccount: Value(idaccount),
      walletId: Value(walletId),
      categoryId: Value(categoryId),
      name: Value(name),
      amount: Value(amount),
      startDate: Value(startDate),
      dueDate: Value(dueDate),
      isRecurrence: Value(isRecurring),
      timeRecurrence: Value(timeRecurrence),
      recurrence: Value(_legacyRecurrence),
      note: Value(note),
      syncStatus: const Value('pending'),
      updatedAt: Value(now),
    );
  }
}
