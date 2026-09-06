import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import 'budget_period.dart';

/// Chu kỳ lặp của ngân sách — dùng đúng tập giá trị backend nhận ở cột
/// `Time_recurrence` (`VarChar(7)`).
class BudgetRecurrence {
  static const week = 'Week';
  static const month = 'Month';
  static const quarter = 'Quarter';
  static const year = 'Year';

  static const all = [week, month, quarter, year];

  /// Nhãn hiển thị. `null` = không theo chu kỳ nào, tức "Ngày cụ thể".
  ///
  /// Nhận null thay vì bắt nơi gọi tự kiểm: cột `time_recurrence` nullable từ
  /// v12, nên mọi chỗ hiển thị đều phải xử lý trường hợp đó — gom về một nhãn
  /// duy nhất ở đây thì không nơi nào quên.
  static String label(String? value) => switch (value) {
        week => 'Hàng tuần',
        quarter => 'Hàng quý',
        year => 'Hàng năm',
        month => 'Hàng tháng',
        _ => 'Ngày cụ thể',
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

  /// null = không có hạn kết thúc do người dùng đặt; khi đó [recurrence] quyết
  /// định ngân sách chạy mãi hay dừng sau kỳ đầu.
  final DateTime? endDate;

  /// true = lặp lại từng chu kỳ cho tới [endDate] (hoặc mãi mãi nếu không có).
  /// false = chạy đúng **một** chu kỳ rồi hết hạn.
  final bool recurrence;

  /// `Week` | `Month` | `Quarter` | `Year`, hoặc **null**.
  ///
  /// null = ngân sách **không theo chu kỳ** nào — người dùng chọn "Ngày cụ thể"
  /// và tự đặt [endDate]. Khi đó cả vòng đời là một kỳ duy nhất.
  final String? timeRecurrence;

  /// Mốc chu kỳ kế tiếp, nếu bản ghi mang sẵn giá trị.
  ///
  /// **Client không ghi cột này.** Chu kỳ neo vào [startDate], nên mốc kế tiếp
  /// suy ra được từ [startDate] và [timeRecurrence] — lưu thêm một bản sao chỉ
  /// tạo ra thứ có thể lệch, đúng lý do `remaining` và `percent_spent` đã bị bỏ
  /// ở lược đồ v11.
  ///
  /// Vẫn đọc và đẩy lại nguyên vẹn vì hàng kéo về từ backend hoặc Admin-web có
  /// thể mang giá trị; khi có, nó được tôn trọng làm mốc gốc.
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

  // ── Chu kỳ và hạn dùng ──────────────────────────────────────────────────────

  /// Mốc gốc để nhảy chu kỳ: cuối kỳ đầu tiên.
  ///
  /// Bình thường là đúng một chu kỳ kể từ ngày bắt đầu. Hàng kéo về từ backend
  /// có thể mang sẵn [nextTimeRecurrence] khác, khi đó nó được tôn trọng.
  ///
  /// Không có chu kỳ ("Ngày cụ thể") thì cả vòng đời là **một kỳ duy nhất**,
  /// đóng ở [endDate].
  ///
  /// Thiếu **cả hai** thì rơi về chu kỳ tháng, tức giá trị mặc định của cột
  /// trước v12. Đó là dữ liệu vô nghĩa mà form không tạo ra được — "Ngày cụ
  /// thể" bắt buộc có ngày kết thúc — nhưng hàng cũ ghi thẳng vào SQLite hoặc
  /// kéo về từ một backend chưa cập nhật thì có. Trả kỳ rỗng ở đây là để số
  /// "đã chi" đứng im ở 0 vĩnh viễn, không exception, không log.
  DateTime get _anchor {
    final cycle = timeRecurrence;
    if (cycle == null) {
      final het = endDate;
      if (het != null) return het;
      return advancePeriod(startDate, BudgetRecurrence.month);
    }
    return nextTimeRecurrence ?? advancePeriod(startDate, cycle);
  }

  /// Thời khắc ngân sách ngừng theo dõi, hoặc null nếu chạy mãi.
  ///
  /// Là **biên mở**: kỳ chạy tới trước thời khắc này. Thứ tự: ngày kết thúc
  /// người dùng đặt và cuối kỳ đầu (khi tắt lặp lại) — cái nào tới trước thì
  /// thắng. Bật lặp lại mà không đặt ngày kết thúc thì không bao giờ hết hạn,
  /// và đó là cấu hình mặc định của mọi ngân sách hiện có.
  DateTime? get expiresAt {
    final byCycle = recurrence ? null : _anchor;
    final byDate = endDate;
    if (byDate == null) return byCycle;
    if (byCycle == null) return byDate;
    return byCycle.isBefore(byDate) ? byCycle : byDate;
  }

  /// Đã qua hạn dùng chưa. [now] truyền vào được để test không phụ thuộc đồng
  /// hồ máy.
  bool isExpired([DateTime? now]) {
    final until = expiresAt;
    if (until == null) return false;
    return !(now ?? DateTime.now()).isBefore(until);
  }

  /// Khoảng thời gian dùng để cộng các khoản chi.
  ///
  /// Kỳ đầu chạy từ [startDate] tới [_anchor]; các kỳ sau nhảy từ chính mốc đó.
  /// Nhảy dồn từ kết quả đã kẹp sẽ làm ngân sách bắt đầu ngày 31 tụt dần về
  /// ngày 28 và không bao giờ quay lại — xem `advancePeriodFrom`.
  ///
  /// Ngân sách **đã hết hạn** chốt ở kỳ cuối thay vì trôi tiếp theo đồng hồ:
  /// nếu không, số "đã chi" của một ngân sách chết vẫn tăng mỗi khi người dùng
  /// ghi giao dịch mới.
  ({DateTime from, DateTime to}) currentPeriod([DateTime? now]) {
    final until = expiresAt;
    var moment = now ?? DateTime.now();

    // `to` không bao giờ được nhỏ hơn `from`: ngân sách đặt cho tương lai thì
    // khoảng cộng dồn là rỗng chứ không phải đảo ngược.
    if (moment.isBefore(startDate)) return (from: startDate, to: startDate);

    if (until != null && !moment.isBefore(until)) {
      moment = until.subtract(const Duration(microseconds: 1));
      if (moment.isBefore(startDate)) moment = startDate;
    }

    final anchor = _anchor;
    final cycle = timeRecurrence;
    var from = startDate;
    var to = anchor;

    // Không có chu kỳ thì không có kỳ thứ hai để nhảy sang — trả luôn kỳ duy
    // nhất. Bỏ nhánh này thì vòng dưới gọi `advancePeriodFrom` với một chu kỳ
    // null và rơi vào nhánh mặc định (tháng), tức tự bịa ra chu kỳ tháng cho
    // một ngân sách người dùng cố ý đặt là "Ngày cụ thể".
    if (cycle != null || endDate == null) {
      // Chặn trên 1000 vòng: dữ liệu hỏng (ví dụ ngày bắt đầu năm 1970 kèm chu
      // kỳ tuần) không được treo giao diện.
      var steps = 0;
      while (!moment.isBefore(to) && steps < 1000) {
        steps++;
        from = to;
        to = advancePeriodFrom(
          anchor: anchor,
          steps: steps,
          timeRecurrence: cycle ?? BudgetRecurrence.month,
        );
      }
    }

    // Ngày kết thúc cắt ngắn kỳ cuối, nếu không thì giao dịch ghi sau ngày
    // người dùng đặt là hết vẫn bị tính vào.
    if (until != null && until.isBefore(to)) to = until;
    return (from: from, to: to);
  }

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
    // Hàm chứ không phải giá trị: "Ngày cụ thể" cần đặt được về null, mà
    // `?? this.timeRecurrence` thì không bao giờ cho phép điều đó.
    String? Function()? timeRecurrence,
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
      timeRecurrence:
          timeRecurrence != null ? timeRecurrence() : this.timeRecurrence,
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
