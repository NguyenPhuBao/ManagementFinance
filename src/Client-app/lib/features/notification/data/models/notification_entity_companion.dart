import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import 'notification_entity.dart';

/// Dựng `AppNotificationsCompanion` từ [NotificationEntity] — chỗ DUY NHẤT ánh xạ Entity ngược về hàng Drift (spec Entity Thông báo
/// 2026-10-15 mục 4.3; tiền lệ `bill_draft_companion.dart`). Một chỗ gọi: `ThongBaoRepositoryImpl.chenLai` — *Hoàn tác* sau khi vuốt xoá
/// cứng hàng biến động D1 (`xoaCung`) chèn lại đúng hàng đã chụp, nên **đủ 14 trường** kể cả `readAt` · `dismissedAt` · `osDeliveredAt`
/// (vắng là hàng về khác hàng đã xoá). `osScheduledId` để trống — cột chết, Entity không mang.
AppNotificationsCompanion companionTu(NotificationEntity e) =>
    AppNotificationsCompanion.insert(
      id: e.id,
      idaccount: e.idaccount,
      kind: e.kind,
      dedupeKey: e.dedupeKey,
      title: e.title,
      body: e.body,
      severity: e.severity,
      subjectType: Value(e.subjectType),
      subjectId: Value(e.subjectId),
      deeplink: Value(e.deeplink),
      createdAt: e.createdAt,
      readAt: Value(e.readAt),
      dismissedAt: Value(e.dismissedAt),
      osDeliveredAt: Value(e.osDeliveredAt),
    );
