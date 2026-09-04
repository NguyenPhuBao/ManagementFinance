import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';

class GoalEntity {
  final String id;
  final int idaccount;
  final String name;
  final double targetAmount;
  final double currentAmount;

  /// Mốc bắt đầu tính nhịp tiến độ. **Nullable**: mục tiêu tạo bởi bản app cũ
  /// không có nó, và không có nó thì `isBehindSchedule` không đánh giá.
  final DateTime? startDate;

  final DateTime targetDate;
  final String? walletId;
  final String icon;
  final String colour;
  final String note;
  final bool isCompleted;
  final bool isDeleted;
  final String syncStatus;
  final DateTime updatedAt;

  GoalEntity({
    required this.id,
    required this.idaccount,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0.0,
    this.startDate,
    required this.targetDate,
    this.walletId,
    this.icon = 'flag',
    this.colour = '#4CAF50',
    this.note = '',
    this.isCompleted = false,
    this.isDeleted = false,
    this.syncStatus = 'pending',
    required this.updatedAt,
  });

  factory GoalEntity.fromDrift(Goal d) {
    return GoalEntity(
      id: d.id,
      idaccount: d.idaccount,
      name: d.name,
      targetAmount: d.targetAmount,
      currentAmount: d.currentAmount,
      startDate: d.startDate,
      targetDate: d.targetDate,
      walletId: d.walletId,
      icon: d.icon,
      colour: d.colour,
      note: d.note,
      isCompleted: d.isCompleted,
      isDeleted: d.isDeleted,
      syncStatus: d.syncStatus,
      updatedAt: d.updatedAt,
    );
  }

  GoalsCompanion toCompanion() {
    return GoalsCompanion.insert(
      id: id,
      idaccount: idaccount,
      name: name,
      targetAmount: targetAmount,
      currentAmount: Value(currentAmount),
      startDate: Value(startDate),
      targetDate: targetDate,
      walletId: Value(walletId),
      icon: Value(icon),
      colour: Value(colour),
      note: Value(note),
      isCompleted: Value(isCompleted),
      isDeleted: Value(isDeleted),
      syncStatus: Value(syncStatus),
      updatedAt: updatedAt,
    );
  }

  GoalEntity copyWith({
    String? id,
    int? idaccount,
    String? name,
    double? targetAmount,
    double? currentAmount,
    DateTime? startDate,
    DateTime? targetDate,
    String? walletId,
    String? icon,
    String? colour,
    String? note,
    bool? isCompleted,
    bool? isDeleted,
    String? syncStatus,
    DateTime? updatedAt,
  }) {
    return GoalEntity(
      id: id ?? this.id,
      idaccount: idaccount ?? this.idaccount,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      startDate: startDate ?? this.startDate,
      targetDate: targetDate ?? this.targetDate,
      walletId: walletId ?? this.walletId,
      icon: icon ?? this.icon,
      colour: colour ?? this.colour,
      note: note ?? this.note,
      isCompleted: isCompleted ?? this.isCompleted,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ── Thuộc tính suy ra ─────────────────────────────────────────────────────
  //
  // Đặt ở đây chứ không trong bộ luật thông báo: trang mục tiêu cũng cần đúng
  // những con số này, và hai nơi tự tính theo hai cách là thẻ mục tiêu nói
  // "đúng tiến độ" trong khi thông báo nói "đang trễ".

  /// Tỉ lệ đã tích được, **luôn nằm trong [0, 1]**.
  ///
  /// Kẹp hai đầu vì thanh tiến độ vẽ thẳng theo giá trị này. `targetAmount = 0`
  /// tạo được từ giao diện, và Dart chia cho 0 ra `Infinity` chứ **không ném** —
  /// giá trị hỏng sẽ trôi thẳng tới màn hình.
  double get progress {
    if (targetAmount <= 0) return 1.0;
    final tyLe = currentAmount / targetAmount;
    if (tyLe.isNaN) return 0.0;
    return tyLe.clamp(0.0, 1.0);
  }

  /// Số ngày còn lại tới hạn. Âm nghĩa là đã quá hạn.
  ///
  /// So theo **ngày**, không theo thời điểm: trừ `DateTime` thô thì cùng một
  /// mục tiêu ra 4 hay 5 ngày tuỳ giờ người dùng mở app.
  int daysLeft(DateTime now) {
    final den = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final homNay = DateTime(now.year, now.month, now.day);
    return den.difference(homNay).inDays;
  }

  /// Tiến độ tiền có đang tụt sau nhịp thời gian không.
  ///
  /// Trả `false` khi **không đủ căn cứ** — chưa có `startDate`, chưa tới ngày
  /// bắt đầu, hoặc kỳ dài 0 ngày. Im lặng đúng hơn là báo bừa: một thông báo
  /// "trễ tiến độ" sai làm người dùng mất tin vào mọi thông báo khác.
  bool isBehindSchedule(DateTime now) {
    if (isCompleted || progress >= 1.0) return false;

    final batDau = startDate;
    if (batDau == null) return false;

    final tuNgay = DateTime(batDau.year, batDau.month, batDau.day);
    final denNgay =
        DateTime(targetDate.year, targetDate.month, targetDate.day);
    final homNay = DateTime(now.year, now.month, now.day);

    if (homNay.isBefore(tuNgay)) return false;

    // Quá hạn mà chưa đạt thì chắc chắn trễ — và cũng là nhánh tránh chia 0
    // khi kỳ dài 0 ngày.
    if (!homNay.isBefore(denNgay)) return true;

    final tongNgay = denNgay.difference(tuNgay).inDays;
    if (tongNgay <= 0) return true;

    final daQua = homNay.difference(tuNgay).inDays;
    return progress < daQua / tongNgay - bienDungSai;
  }

  /// Biên dung sai của [isBehindSchedule].
  ///
  /// Nhịp kỳ vọng là tuyến tính theo ngày, còn người dùng thì nhận lương theo
  /// tháng — nên tiến độ thật luôn dao động quanh đường thẳng ấy. Không có
  /// biên thì một mục tiêu đi đúng hướng vẫn bị báo "chậm tiến độ" chỉ vì lệch
  /// dưới một phần trăm, và người dùng học được rằng thông báo của app không
  /// đáng tin.
  static const double bienDungSai = 0.05;
}
