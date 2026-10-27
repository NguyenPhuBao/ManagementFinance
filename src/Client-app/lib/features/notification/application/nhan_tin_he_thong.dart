/// Ghi tin admin (`system.broadcast` → `RealtimeChannel.tinHeThong`) vào Trung tâm thông báo và bắn khay hệ điều hành
/// (spec `2026-10-26-tin-tu-flowmoney-broadcast-design.md` mục 3.3). Cùng luật với `NotificationScanner`: nhóm tắt → không
/// sinh gì; ghi hàng rồi CHỈ hàng mới mới bắn khay, và chỉ khi `osBat && !dangImLang`.
///
/// Không bao giờ ném — một tin hỏng không được làm chết kênh thời gian thực. Không log tiêu đề / nội dung (quét 38).
library;

import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/notification_dao.dart';
import '../../../core/realtime/tin_he_thong.dart';
import '../data/datasources/os_notifier.dart';
import '../data/notification_prefs_store.dart';
import '../domain/notification_rules.dart';
import '../domain/os_scheduled_id.dart';

/// Khoá chống trùng của một tin — backend có thể phát một tin HAI lần (event bus cục bộ + Redis), cùng `id`.
String khoaTinHeThong(String id) => 'tinHeThong:$id';

class NhanTinHeThong {
  NhanTinHeThong({
    required NotificationDao dao,
    required NotificationPrefsStore prefsStore,
    OsNotifier? osNotifier,
    DateTime Function()? clock,
    String Function()? idGenerator,
  })  : _dao = dao,
        _kho = prefsStore,
        _os = osNotifier,
        _clock = clock ?? DateTime.now,
        _idMoi = idGenerator ?? (() => const Uuid().v4());

  final NotificationDao _dao;
  final NotificationPrefsStore _kho;
  final OsNotifier? _os;
  final DateTime Function() _clock;
  final String Function() _idMoi;

  /// Nghe [nguon] suốt vòng đời app — nối MỘT lần ở `main.dart`.
  StreamSubscription<TinHeThongNhan> batDau(Stream<TinHeThongNhan> nguon) => nguon.listen((t) => unawaited(xuLy(t)));

  Future<void> xuLy(TinHeThongNhan t) async {
    try {
      final prefs = await _kho.read(t.idaccount);
      if (!prefs.chapNhan(NotificationKind.tinHeThong)) return;
      final bayGio = _clock();
      final khoa = khoaTinHeThong(t.tin.id);
      final moi = await _dao.insertIfAbsent(AppNotificationsCompanion.insert(
        id: _idMoi(),
        idaccount: t.idaccount,
        kind: NotificationKind.tinHeThong.name,
        dedupeKey: khoa,
        title: t.tin.tieuDe,
        body: t.tin.noiDung,
        severity: NotificationSeverity.values.byName(t.tin.mucDo.name).name,
        subjectType: const Value('tinHeThong'),
        createdAt: bayGio,
      ));
      // Công tắc tổng / giờ im lặng chỉ chặn bước bắn khay — hàng vẫn vào Trung tâm (cùng ngữ nghĩa NotificationScanner).
      final os = _os;
      if (!moi || os == null || !prefs.osBat || prefs.dangImLang(bayGio)) return;
      // Nhật ký B5a: chỉ ghi `osDeliveredAt` khi quyền đang bật — Android 13+ nhận `show` im lặng khi quyền tắt.
      var coQuyen = false;
      try {
        coQuyen = await os.daCoQuyen();
      } catch (_) {}
      await os.show(id: osScheduledId(khoa), title: t.tin.tieuDe, body: t.tin.noiDung, payload: khoa);
      if (coQuyen) await _dao.danhDauDaBan(t.idaccount, khoa, bayGio);
    } catch (e) {
      debugPrint('[NhanTinHeThong] Bỏ qua tin ${t.tin.id}: ${e.runtimeType}');
    }
  }
}
