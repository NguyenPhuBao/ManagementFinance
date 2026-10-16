import '../../../../core/database/app_database.dart';

/// Hoá đơn — kiểu DUY NHẤT từ repository trở lên (spec Entity Hoá đơn 2026-10-14, mục 4.1; G88 gạch 3).
///
/// 25 trường = 28 cột của bảng `Bills` trừ ba cột lỗi đồng bộ (`syncRetryCount`, `syncError`, `syncBlockedUntil` — chỉ
/// `core/sync` đọc). Tên trường **đúng** tên cột Drift để thân hàm domain / widget không đổi khi đổi kiểu. Giá trị mặc
/// định khớp mặc định của bảng (`other_tables.dart`) để fixture test dựng gọn. Không có `toCompanion`: đường ghi đi qua
/// `BillDraft` (`bill_draft_companion.dart`); `copyWith` cho kỳ CHIẾU (`cacKyChieuCua`, `hang_hoa_don`) — chỉ gán giá
/// trị, không đặt về null.
class BillEntity {
  const BillEntity({
    required this.id,
    required this.idaccount,
    this.walletId,
    this.categoryId,
    required this.name,
    required this.amount,
    this.startDate,
    required this.dueDate,
    this.payStatus = 'Pending',
    this.isPaid = false,
    this.timeNotification,
    this.isRecurrence = false,
    this.timeRecurrence = 'Month',
    this.recurrence = 'monthly',
    this.icon = 'receipt',
    this.colour = '#4CAF50',
    this.note = '',
    this.generatedFromBillId,
    this.periodEnd,
    this.autoPayEnabled = false,
    this.anchorDay,
    this.deletedAt,
    this.isDeleted = false,
    this.syncStatus = 'pending',
    required this.updatedAt,
  });

  final String id;
  final int idaccount;
  final String? walletId;
  final String? categoryId;
  final String name;
  final double amount;
  final DateTime? startDate;
  final DateTime dueDate;
  final String payStatus;
  final bool isPaid;
  final String? timeNotification;
  final bool isRecurrence;
  final String timeRecurrence;
  final String recurrence;
  final String icon;
  final String colour;
  final String note;
  final String? generatedFromBillId;
  final DateTime? periodEnd;
  final bool autoPayEnabled;
  final int? anchorDay;
  final DateTime? deletedAt;
  final bool isDeleted;
  final String syncStatus;
  final DateTime updatedAt;

  factory BillEntity.fromDrift(Bill d) => BillEntity(
        id: d.id,
        idaccount: d.idaccount,
        walletId: d.walletId,
        categoryId: d.categoryId,
        name: d.name,
        amount: d.amount,
        startDate: d.startDate,
        dueDate: d.dueDate,
        payStatus: d.payStatus,
        isPaid: d.isPaid,
        timeNotification: d.timeNotification,
        isRecurrence: d.isRecurrence,
        timeRecurrence: d.timeRecurrence,
        recurrence: d.recurrence,
        icon: d.icon,
        colour: d.colour,
        note: d.note,
        generatedFromBillId: d.generatedFromBillId,
        periodEnd: d.periodEnd,
        autoPayEnabled: d.autoPayEnabled,
        anchorDay: d.anchorDay,
        deletedAt: d.deletedAt,
        isDeleted: d.isDeleted,
        syncStatus: d.syncStatus,
        updatedAt: d.updatedAt,
      );

  BillEntity copyWith({
    String? id,
    int? idaccount,
    String? walletId,
    String? categoryId,
    String? name,
    double? amount,
    DateTime? startDate,
    DateTime? dueDate,
    String? payStatus,
    bool? isPaid,
    String? timeNotification,
    bool? isRecurrence,
    String? timeRecurrence,
    String? recurrence,
    String? icon,
    String? colour,
    String? note,
    String? generatedFromBillId,
    DateTime? periodEnd,
    bool? autoPayEnabled,
    int? anchorDay,
    DateTime? deletedAt,
    bool? isDeleted,
    String? syncStatus,
    DateTime? updatedAt,
  }) =>
      BillEntity(
        id: id ?? this.id,
        idaccount: idaccount ?? this.idaccount,
        walletId: walletId ?? this.walletId,
        categoryId: categoryId ?? this.categoryId,
        name: name ?? this.name,
        amount: amount ?? this.amount,
        startDate: startDate ?? this.startDate,
        dueDate: dueDate ?? this.dueDate,
        payStatus: payStatus ?? this.payStatus,
        isPaid: isPaid ?? this.isPaid,
        timeNotification: timeNotification ?? this.timeNotification,
        isRecurrence: isRecurrence ?? this.isRecurrence,
        timeRecurrence: timeRecurrence ?? this.timeRecurrence,
        recurrence: recurrence ?? this.recurrence,
        icon: icon ?? this.icon,
        colour: colour ?? this.colour,
        note: note ?? this.note,
        generatedFromBillId: generatedFromBillId ?? this.generatedFromBillId,
        periodEnd: periodEnd ?? this.periodEnd,
        autoPayEnabled: autoPayEnabled ?? this.autoPayEnabled,
        anchorDay: anchorDay ?? this.anchorDay,
        deletedAt: deletedAt ?? this.deletedAt,
        isDeleted: isDeleted ?? this.isDeleted,
        syncStatus: syncStatus ?? this.syncStatus,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  List<Object?> get _truong => [
        id,
        idaccount,
        walletId,
        categoryId,
        name,
        amount,
        startDate,
        dueDate,
        payStatus,
        isPaid,
        timeNotification,
        isRecurrence,
        timeRecurrence,
        recurrence,
        icon,
        colour,
        note,
        generatedFromBillId,
        periodEnd,
        autoPayEnabled,
        anchorDay,
        deletedAt,
        isDeleted,
        syncStatus,
        updatedAt,
      ];

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BillEntity) return false;
    final a = _truong, b = other._truong;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_truong);

  @override
  String toString() => 'BillEntity($id, $name, hạn $dueDate, $payStatus)';
}
