import 'package:equatable/equatable.dart';

import '../../../../core/database/app_database.dart';

/// Entity thông báo — kiểu **duy nhất** từ repository trở lên (G88 gạch 3, đợt 4/4; spec `2026-10-15-entity-thong-bao-application-design.md` 4.1).
///
/// Ảnh **chỉ đọc** của hàng Drift `AppNotification`: 14 trường = 15 cột − `osScheduledId` (cột chết — 0 chỗ đọc, 0 chỗ ghi từ v13; id hệ
/// điều hành tính lại từ `dedupeKey` qua `osScheduledId()`). `notification_entity_test` đếm cột bảng để canh. Ánh xạ ngược (cho *Hoàn tác*
/// sau khi vuốt xoá cứng hàng D1) là `companionTu` ở `notification_entity_companion.dart` — một chỗ. `fromDrift` ở đây là MỘT định nghĩa.
///
/// `kind` và `severity` giữ `String` (giá trị `.name` của enum) — đổi kiểu không đổi thân: giao diện so `item.kind ==
/// NotificationKind.bienDongSoDu.name`. Bảng này **cục bộ**, không đi qua đồng bộ (quy tắc 9 `CLAUDE.md`) — Entity không đổi điều đó.
class NotificationEntity extends Equatable {
  final String id;
  final int idaccount;

  /// `NotificationKind.<x>.name`.
  final String kind;

  /// Khoá chống trùng — xem chú thích cột ở `notification_table.dart`.
  final String dedupeKey;
  final String title;
  final String body;

  /// `info` | `warning` | `critical`.
  final String severity;
  final String? subjectType;
  final String? subjectId;
  final String? deeplink;

  /// Mốc của **sự kiện**, không phải mốc quét.
  final DateTime createdAt;
  final DateTime? readAt;

  /// Xoá mềm — hàng giữ lại để chặn trùng.
  final DateTime? dismissedAt;

  /// Lúc giao cho hệ điều hành khi quyền đang bật (B5a).
  final DateTime? osDeliveredAt;

  const NotificationEntity({
    required this.id,
    required this.idaccount,
    required this.kind,
    required this.dedupeKey,
    required this.title,
    required this.body,
    required this.severity,
    this.subjectType,
    this.subjectId,
    this.deeplink,
    required this.createdAt,
    this.readAt,
    this.dismissedAt,
    this.osDeliveredAt,
  });

  factory NotificationEntity.fromDrift(AppNotification n) => NotificationEntity(
        id: n.id,
        idaccount: n.idaccount,
        kind: n.kind,
        dedupeKey: n.dedupeKey,
        title: n.title,
        body: n.body,
        severity: n.severity,
        subjectType: n.subjectType,
        subjectId: n.subjectId,
        deeplink: n.deeplink,
        createdAt: n.createdAt,
        readAt: n.readAt,
        dismissedAt: n.dismissedAt,
        osDeliveredAt: n.osDeliveredAt,
      );

  @override
  List<Object?> get props => [
        id,
        idaccount,
        kind,
        dedupeKey,
        title,
        body,
        severity,
        subjectType,
        subjectId,
        deeplink,
        createdAt,
        readAt,
        dismissedAt,
        osDeliveredAt,
      ];
}
