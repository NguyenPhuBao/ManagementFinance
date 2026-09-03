import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';

/// Chu kỳ lặp của ngân sách — dùng đúng tập giá trị backend nhận ở cột
/// `Time_recurrence` (`VarChar(7)`).
class BudgetRecurrence {
  static const week = 'Week';
  static const month = 'Month';
  static const quarter = 'Quarter';
  static const year = 'Year';

  static const all = [week, month, quarter, year];

  static String label(String value) => switch (value) {
        week => 'Hàng tuần',
        quarter => 'Hàng quý',
        year => 'Hàng năm',
        _ => 'Hàng tháng',
      };
}

/// Hành vi khi tiêu vượt hạn mức — cột `OverSpending` (`VarChar(7)`).
class BudgetOverSpending {
  /// Vẫn cho tiêu tiếp, chỉ cảnh báo.
  static const over = 'Over';

  /// Chặn không cho tiêu thêm.
  static const stop = 'Stop';
}

/// Một hạn mức chi tiêu cho một danh mục trong một chu kỳ.
///
/// `categoryId == null` nghĩa là **ngân sách tổng** — áp cho mọi khoản chi,
/// không giới hạn danh mục nào.
///
/// ## Vì sao không có trường `name`
///
/// Backend không có cột tên cho ngân sách (xem `model budget` trong
/// `schema.prisma`). Danh tính của một ngân sách là **danh mục + chu kỳ**, còn
/// `note` là ghi chú tự do. Thêm một trường `name` chỉ tồn tại ở client sẽ
/// không bao giờ đồng bộ được, và người dùng sẽ mất nó khi đổi máy.
class BudgetEntity {
  final String id;
  final int idaccount;

  /// null = ngân sách tổng, áp cho mọi danh mục chi.
  final String? categoryId;

  /// Hạn mức đặt ra — cột `TotalAmount` phía backend.
  final double amount;

  /// Số đã chi trong chu kỳ hiện tại.
  ///
  /// Giá trị này được **tính lại ở client** từ bảng giao dịch chứ không tin
  /// vào cột `Spent` của backend: người dùng ghi giao dịch khi offline nên
  /// server không thể biết trước, mà cam kết của ứng dụng là offline-first.
  final double spent;

  /// Cảnh báo khi số tiền **còn lại** xuống dưới mức này.
  final double? thresholdWarningAmount;

  /// Cảnh báo khi **tỉ lệ đã tiêu** vượt mức này, đơn vị **phần trăm 0–100**
  /// (không phải 0.0–1.0) — khớp cột `Threshold_Warning_Percent` bên backend.
  final double? thresholdWarningPercent;

  /// `Over` = cảnh báo rồi cho tiêu tiếp; `Stop` = chặn.
  final String overSpending;

  final DateTime startDate;

  /// null = không có hạn kết thúc; chu kỳ suy ra từ [recurrence].
  final DateTime? endDate;

  final bool recurrence;

  /// `Week` | `Month` | `Quarter` | `Year`.
  final String timeRecurrence;

  final DateTime? nextTimeRecurrence;
  final String note;

  final bool isDeleted;
  final String syncStatus;
  final DateTime updatedAt;

  const BudgetEntity({
    required this.id,
    required this.idaccount,
    this.categoryId,
    required this.amount,
    this.spent = 0.0,
    this.thresholdWarningAmount,
    this.thresholdWarningPercent,
    this.overSpending = BudgetOverSpending.over,
    required this.startDate,
    this.endDate,
    this.recurrence = false,
    this.timeRecurrence = BudgetRecurrence.month,
    this.nextTimeRecurrence,
    this.note = '',
    this.isDeleted = false,
    this.syncStatus = 'pending',
    required this.updatedAt,
  });

  // ── Giá trị suy ra ──────────────────────────────────────────────────────────

  /// Còn lại. Âm khi đã tiêu vượt.
  double get remaining => amount - spent;

  /// Tỉ lệ đã tiêu, 0.0–1.0 và **cắt trần ở 1.0** để thanh tiến trình không
  /// tràn ra ngoài khung khi tiêu vượt. Muốn biết vượt bao nhiêu thì đọc
  /// [overAmount], đừng đọc giá trị này.
  double get percentSpent {
    if (amount <= 0) return 0.0;
    final ratio = spent / amount;
    return ratio > 1.0 ? 1.0 : ratio;
  }

  /// Tỉ lệ đã tiêu **không cắt trần** — dùng khi cần so với ngưỡng cảnh báo.
  double get rawPercentSpent => amount <= 0 ? 0.0 : spent / amount;

  /// Số tiền đã tiêu vượt hạn mức, 0 khi chưa vượt.
  double get overAmount => spent > amount ? spent - amount : 0.0;

  bool get isOverBudget => spent > amount;

  /// Mốc dùng khi người dùng không đặt ngưỡng nào.
  static const double defaultWarningRatio = 0.9;

  /// Ngưỡng phần trăm quy về tỉ lệ 0.0–1.0, hoặc null nếu chưa đặt.
  ///
  /// Cột lưu **0–100** để khớp `Decimal(15,2)` của backend, còn mọi phép so
  /// sánh trong lớp này chạy trên tỉ lệ — đổi đơn vị đúng một chỗ ở đây thay vì
  /// rải `/ 100` khắp nơi.
  ///
  /// Giá trị vô nghĩa (âm, hoặc quá 100) bị bỏ qua như thể chưa đặt: một hàng
  /// hỏng do đồng bộ không được biến cảnh báo thành luôn-bật hoặc luôn-tắt.
  double? get warningRatio {
    final percent = thresholdWarningPercent;
    if (percent == null || percent <= 0 || percent > 100) return null;
    return percent / 100;
  }

  /// Đã chạm ngưỡng cảnh báo chưa.
  ///
  /// Thứ tự ưu tiên: ngưỡng theo **số tiền còn lại** → ngưỡng theo **phần
  /// trăm** → mốc mặc định 90%.
  ///
  /// Số tiền đứng trước phần trăm vì nó cụ thể hơn: người đặt "báo khi còn
  /// dưới 500k" muốn đúng con số đó, không phải một tỉ lệ suy ra từ hạn mức.
  bool get isNearLimit {
    if (isOverBudget) return false;
    final byAmount = thresholdWarningAmount;
    if (byAmount != null) return remaining <= byAmount;
    return rawPercentSpent >= (warningRatio ?? defaultWarningRatio);
  }

  // ── Chu kỳ hiện tại ─────────────────────────────────────────────────────────

  /// Khoảng thời gian dùng để cộng các khoản chi.
  ///
  /// Ba trường hợp, theo thứ tự ưu tiên:
  /// 1. Có [endDate] → dùng đúng khoảng đó, kể cả khi đã qua.
  /// 2. [recurrence] bật → chu kỳ đang chạy, tính bằng cách nhảy từ
  ///    [startDate] theo [timeRecurrence] cho tới khi trùm được [now].
  /// 3. Còn lại → từ [startDate] tới [now].
  ///
  /// [now] truyền vào được để test không phụ thuộc đồng hồ máy.
  ({DateTime from, DateTime to}) currentPeriod([DateTime? now]) {
    final moment = now ?? DateTime.now();

    if (endDate != null) {
      return (from: startDate, to: endDate!);
    }
    if (!recurrence) {
      // `to` không bao giờ được nhỏ hơn `from`: ngân sách đặt cho tương lai thì
      // khoảng cộng dồn là rỗng chứ không phải đảo ngược.
      return (
        from: startDate,
        to: moment.isBefore(startDate) ? startDate : moment
      );
    }

    var from = startDate;
    var to = _advance(from);
    // Chặn trên 1000 vòng: chu kỳ dữ liệu hỏng (ví dụ startDate năm 1970 kèm
    // chu kỳ tuần) không được treo giao diện.
    var guard = 0;
    while (to.isBefore(moment) && guard++ < 1000) {
      from = to;
      to = _advance(from);
    }
    return (from: from, to: to);
  }

  DateTime _advance(DateTime from) => switch (timeRecurrence) {
        BudgetRecurrence.week => from.add(const Duration(days: 7)),
        BudgetRecurrence.quarter =>
          DateTime(from.year, from.month + 3, from.day),
        BudgetRecurrence.year => DateTime(from.year + 1, from.month, from.day),
        _ => DateTime(from.year, from.month + 1, from.day),
      };

  // ── Chuyển đổi ──────────────────────────────────────────────────────────────

  factory BudgetEntity.fromDrift(Budget d) {
    return BudgetEntity(
      id: d.id,
      idaccount: d.idaccount,
      categoryId: d.categoryId,
      amount: d.amount,
      spent: d.spent,
      thresholdWarningAmount: d.thresholdWarningAmount,
      thresholdWarningPercent: d.thresholdWarningPercent,
      overSpending: d.overSpending,
      startDate: d.startDate,
      endDate: d.endDate,
      recurrence: d.recurrence,
      timeRecurrence: d.timeRecurrence,
      nextTimeRecurrence: d.nextTimeRecurrence,
      note: d.note,
      isDeleted: d.isDeleted,
      syncStatus: d.syncStatus,
      updatedAt: d.updatedAt,
    );
  }

  BudgetsCompanion toCompanion() {
    return BudgetsCompanion.insert(
      id: id,
      idaccount: idaccount,
      categoryId: Value(categoryId),
      amount: amount,
      spent: Value(spent),
      thresholdWarningAmount: Value(thresholdWarningAmount),
      thresholdWarningPercent: Value(thresholdWarningPercent),
      overSpending: Value(overSpending),
      startDate: startDate,
      endDate: Value(endDate),
      recurrence: Value(recurrence),
      timeRecurrence: Value(timeRecurrence),
      nextTimeRecurrence: Value(nextTimeRecurrence),
      note: Value(note),
      isDeleted: Value(isDeleted),
      syncStatus: Value(syncStatus),
      updatedAt: updatedAt,
    );
  }

  BudgetEntity copyWith({
    String? id,
    int? idaccount,
    String? Function()? categoryId,
    double? amount,
    double? spent,
    double? Function()? thresholdWarningAmount,
    double? Function()? thresholdWarningPercent,
    String? overSpending,
    DateTime? startDate,
    DateTime? Function()? endDate,
    bool? recurrence,
    String? timeRecurrence,
    DateTime? Function()? nextTimeRecurrence,
    String? note,
    bool? isDeleted,
    String? syncStatus,
    DateTime? updatedAt,
  }) {
    return BudgetEntity(
      id: id ?? this.id,
      idaccount: idaccount ?? this.idaccount,
      categoryId: categoryId != null ? categoryId() : this.categoryId,
      amount: amount ?? this.amount,
      spent: spent ?? this.spent,
      thresholdWarningAmount: thresholdWarningAmount != null
          ? thresholdWarningAmount()
          : this.thresholdWarningAmount,
      thresholdWarningPercent: thresholdWarningPercent != null
          ? thresholdWarningPercent()
          : this.thresholdWarningPercent,
      overSpending: overSpending ?? this.overSpending,
      startDate: startDate ?? this.startDate,
      endDate: endDate != null ? endDate() : this.endDate,
      recurrence: recurrence ?? this.recurrence,
      timeRecurrence: timeRecurrence ?? this.timeRecurrence,
      nextTimeRecurrence: nextTimeRecurrence != null
          ? nextTimeRecurrence()
          : this.nextTimeRecurrence,
      note: note ?? this.note,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Ngân sách kèm thông tin danh mục để hiển thị.
///
/// Tách khỏi [BudgetEntity] vì tên/biểu tượng danh mục **không** thuộc về ngân
/// sách: chúng ở bảng khác, đổi độc lập, và không được đẩy lên trong payload
/// ngân sách. Gộp chung sẽ dụ người viết mã sau gửi nhầm chúng lên backend.
class BudgetView {
  final BudgetEntity budget;

  /// null khi là ngân sách tổng, hoặc khi danh mục đã bị xoá.
  final String? categoryName;
  final String? categoryIcon;
  final String? categoryColour;

  const BudgetView({
    required this.budget,
    this.categoryName,
    this.categoryIcon,
    this.categoryColour,
  });

  String get displayName => categoryName ?? 'Ngân sách tổng';
}
