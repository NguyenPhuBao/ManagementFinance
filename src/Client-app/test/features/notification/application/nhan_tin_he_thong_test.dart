/// `NhanTinHeThong` — ghi tin admin (`system.broadcast`) vào Trung tâm thông báo và bắn khay hệ điều hành theo đúng luật
/// của `NotificationScanner` (spec 2026-10-26 mục 3.3).
library;

import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/realtime/tin_he_thong.dart';
import 'package:flowmoney/features/notification/application/nhan_tin_he_thong.dart';
import 'package:flowmoney/features/notification/data/datasources/os_notifier.dart';
import 'package:flowmoney/features/notification/data/notification_prefs_store.dart';
import 'package:flowmoney/features/notification/domain/cham_hdh.dart';
import 'package:flowmoney/features/notification/domain/notification_prefs.dart';
import 'package:flowmoney/features/notification/domain/os_scheduled_id.dart';

/// Kho tuỳ chọn trả một bộ đặt sẵn; [nem] = `read` ném.
class _Kho implements NotificationPrefsStore {
  NotificationPrefs prefs = NotificationPrefs.macDinh;
  bool nem = false;

  @override
  Future<NotificationPrefs> read(int idaccount) async {
    if (nem) throw StateError('kho hỏng');
    return prefs;
  }

  @override
  Future<void> write(int idaccount, NotificationPrefs value) async => prefs = value;

  @override
  Future<void> clear(int idaccount) async {}
}

/// Ghi lại mọi lần `show`; [coQuyen] cho `daCoQuyen`; [nem] = `show` ném.
class _OsGia implements OsNotifier {
  final List<({int id, String title, String body, String? payload})> daBan = [];
  bool coQuyen = true;
  bool nem = false;

  @override
  bool get isSupported => true;
  @override
  Future<void> init() async {}
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<bool> daCoQuyen() async => coQuyen;
  @override
  Future<void> show({required int id, required String title, required String body, String? payload}) async {
    if (nem) throw StateError('khay hỏng');
    daBan.add((id: id, title: title, body: body, payload: payload));
  }

  @override
  Future<void> zonedSchedule(
      {required int id, required String title, required String body, required DateTime when, String? payload}) async {}
  @override
  Stream<ChamHdh> get chamTho => const Stream<ChamHdh>.empty();
  @override
  Future<ChamHdh?> chamKhoiDong() async => null;
  @override
  Future<Set<int>> pendingIds() async => const {};
  @override
  Future<Set<int>> activeIds() async => const {};
  @override
  Future<void> datBadge(int soLuong) async {}
  @override
  Future<void> cancel(int id) async {}
  @override
  Future<void> cancelAll() async {}
}

TinHeThongNhan _nhan({String id = 'b-1', MucDoTinHeThong muc = MucDoTinHeThong.critical}) => (
      idaccount: 11,
      tin: TinHeThong(
          id: id,
          tieuDe: 'Bảo trì nâng cấp tối nay',
          noiDung: 'FlowMoney nâng cấp máy chủ từ 23:00 đến 23:30.',
          mucDo: muc),
    );

void main() {
  late AppDatabase db;
  late _Kho kho;
  late _OsGia os;
  late NhanTinHeThong nhan;
  final bayGio = DateTime(2026, 10, 26, 10, 0);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    kho = _Kho();
    os = _OsGia();
    var n = 0;
    nhan = NhanTinHeThong(
      dao: db.notificationDao,
      prefsStore: kho,
      osNotifier: os,
      clock: () => bayGio,
      idGenerator: () => 'hang-${n++}',
    );
  });
  tearDown(() => db.close());

  test('tin mới → một hàng loại tinHeThong + một lần bắn khay', () async {
    await nhan.xuLy(_nhan());
    final hang = await db.notificationDao.getAll(11);
    expect(hang, hasLength(1));
    expect(hang.single.kind, 'tinHeThong');
    expect(hang.single.dedupeKey, 'tinHeThong:b-1');
    expect(hang.single.title, 'Bảo trì nâng cấp tối nay');
    expect(hang.single.body, 'FlowMoney nâng cấp máy chủ từ 23:00 đến 23:30.');
    expect(hang.single.severity, 'critical');
    expect(hang.single.subjectType, 'tinHeThong');
    expect(hang.single.deeplink, isNull, reason: 'nội dung đã hiện trọn ở hàng; chạm = đánh dấu đã đọc');
    expect(os.daBan, hasLength(1));
    expect(os.daBan.single.payload, 'tinHeThong:b-1');
    expect(os.daBan.single.id, osScheduledId('tinHeThong:b-1'));
  });

  test('cùng id tới HAI lần (event bus cục bộ + Redis) → một hàng, một lần bắn', () async {
    await nhan.xuLy(_nhan());
    await nhan.xuLy(_nhan());
    expect(await db.notificationDao.getAll(11), hasLength(1));
    expect(os.daBan, hasLength(1), reason: 'bắn theo hàng VỪA GHI, như NotificationScanner — không theo tin tới');
  });

  test('nhóm Tin từ FlowMoney tắt → không hàng, không khay', () async {
    kho.prefs = const NotificationPrefs(nhomTat: {NotificationGroup.tinFlowMoney});
    await nhan.xuLy(_nhan());
    expect(await db.notificationDao.getAll(11), isEmpty);
    expect(os.daBan, isEmpty);
  });

  test('công tắc tổng tắt → có hàng, không khay (luật NotificationScanner)', () async {
    kho.prefs = const NotificationPrefs(osBat: false);
    await nhan.xuLy(_nhan());
    expect(await db.notificationDao.getAll(11), hasLength(1));
    expect(os.daBan, isEmpty);
  });

  test('đang giờ im lặng → có hàng, không khay', () async {
    kho.prefs = const NotificationPrefs(imLangBat: true, imLangTuPhut: 0, imLangDenPhut: 1439);
    await nhan.xuLy(_nhan());
    expect(await db.notificationDao.getAll(11), hasLength(1));
    expect(os.daBan, isEmpty);
  });

  test('có quyền → ghi osDeliveredAt; không quyền → để null (nhật ký B5a)', () async {
    await nhan.xuLy(_nhan(id: 'co'));
    os.coQuyen = false;
    await nhan.xuLy(_nhan(id: 'khong'));
    final hang = {for (final h in await db.notificationDao.getAll(11)) h.dedupeKey: h};
    expect(hang['tinHeThong:co']!.osDeliveredAt, bayGio);
    expect(hang['tinHeThong:khong']!.osDeliveredAt, isNull,
        reason: 'Android 13+ nhận show im lặng khi quyền tắt — ghi mốc là nói dối nhật ký');
  });

  test('OS ném / kho ném → không ném ra ngoài', () async {
    os.nem = true;
    await expectLater(nhan.xuLy(_nhan(id: 'os')), completes);
    expect(await db.notificationDao.getAll(11), hasLength(1), reason: 'hàng đã ghi trước lúc bắn khay');
    kho.nem = true;
    await expectLater(nhan.xuLy(_nhan(id: 'kho')), completes,
        reason: 'một tin hỏng không được làm chết kênh thời gian thực');
  });

  test('mức độ đổi sang severity theo tên', () async {
    await nhan.xuLy(_nhan(id: 'i', muc: MucDoTinHeThong.info));
    await nhan.xuLy(_nhan(id: 'w', muc: MucDoTinHeThong.warning));
    final hang = {for (final h in await db.notificationDao.getAll(11)) h.dedupeKey: h.severity};
    expect(hang['tinHeThong:i'], 'info');
    expect(hang['tinHeThong:w'], 'warning');
  });

  test('batDau nghe luồng và xử lý từng tin', () async {
    final c = StreamController<TinHeThongNhan>();
    final sub = nhan.batDau(c.stream);
    c.add(_nhan());
    await pumpEventQueue();
    expect(await db.notificationDao.getAll(11), hasLength(1));
    await sub.cancel();
    await c.close();
  });

  test('main.dart nối NhanTinHeThong vào RealtimeChannel.tinHeThong MỘT lần; DI đăng ký', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(RegExp(r'sl<NhanTinHeThong>\(\)\s*\.batDau\(sl<RealtimeChannel>\(\)\.tinHeThong\)').allMatches(main).length, 1,
        reason: 'thiếu là tin admin tới socket rồi rơi mất, không một dòng log — vùng mù của widget test');
    final di = File('lib/core/di/injection_container.dart').readAsStringSync();
    expect(di, contains('registerLazySingleton<NhanTinHeThong>'));
  });
}
