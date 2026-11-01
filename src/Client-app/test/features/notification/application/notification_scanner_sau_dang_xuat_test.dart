/// Không lối quét nào được chạy SAU `stop()` (đăng xuất): tự trả / tự trích và lịch nhắc đặt lại sau `cancelAll` là lịch nhắc nổ
/// trên màn khoá khi không ai đăng nhập (quy tắc 9). Ba lối: lượt `resumed` (sau khe nhập biên lai chạy ML Kit), `start` (sau khe
/// nhập hàng chờ), và `quetKhiRanh` gọi lúc `stop()` mới chạy được nửa đường. Lượt `scan` ĐANG chạy lúc `stop()` là nợ G115.
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppLifecycleState;

import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/notification/application/nhap_bien_dong.dart';
import 'package:flowmoney/features/notification/application/notification_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

/// `nhap` treo tới khi [giu] hoàn thành (khe ML Kit của `nhapBienLai` sống trong chính lượt nhập này).
class _NhapTreo extends NhapBienDong {
  _NhapTreo(AppDatabase db, this.giu)
      : super(
          thuMuc: () async => Directory.systemTemp,
          dao: db.notificationDao,
          nguonCuaGoi: (_) => null,
          batBienDong: (_) async => true,
        );

  final Completer<void> giu;
  bool treo = false;

  @override
  Future<int> nhap(int idaccount) async {
    if (treo) await giu.future;
    return 0;
  }

  @override
  Future<void> tatDocMay() async {}
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  var soLanQuet = 0;
  setUp(() => soLanQuet = 0);

  NotificationScanner quet({NhapBienDong? nhap, Stream<AppLifecycleState>? vongDoi}) => NotificationScanner(
        dao: db.notificationDao,
        loadBudgets: (_, __) async => const [],
        loadBills: (_, __) async {
          soLanQuet++;
          return const [];
        },
        syncStatus: const Stream.empty(),
        appLifecycle: vongDoi,
        nhapBienDong: nhap,
        clock: () => DateTime(2026, 10, 31, 9),
      );

  Future<void> xa() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('resumed → nhập biến động còn treo → stop() → nhập xong: KHÔNG quét', () async {
    final giu = Completer<void>();
    final nhap = _NhapTreo(db, giu);
    final vongDoi = StreamController<AppLifecycleState>();
    final s = quet(nhap: nhap, vongDoi: vongDoi.stream);
    await s.start(18);
    soLanQuet = 0;
    nhap.treo = true;
    vongDoi.add(AppLifecycleState.resumed);
    await xa();
    await s.stop();
    giu.complete();
    await xa();
    expect(soLanQuet, 0, reason: 'quét sau stop() đặt lại lịch nhắc SAU cancelAll — nổ trên màn khoá');
    await vongDoi.close();
  });

  test('resumed, phiên còn mở → nhập xong → quét đúng một lần (ca đòi kết quả)', () async {
    final giu = Completer<void>();
    final nhap = _NhapTreo(db, giu);
    final vongDoi = StreamController<AppLifecycleState>();
    final s = quet(nhap: nhap, vongDoi: vongDoi.stream);
    await s.start(18);
    soLanQuet = 0;
    nhap.treo = true;
    vongDoi.add(AppLifecycleState.resumed);
    await xa();
    giu.complete();
    await xa();
    expect(soLanQuet, 1);
    await s.stop();
    await vongDoi.close();
  });

  test('start → nhập biến động còn treo → stop() → nhập xong: KHÔNG quét, không nghe sự kiện nào', () async {
    final giu = Completer<void>();
    final nhap = _NhapTreo(db, giu)..treo = true;
    final s = quet(nhap: nhap);
    final dangStart = s.start(18);
    await xa();
    await s.stop();
    giu.complete();
    await dangStart;
    expect(soLanQuet, 0, reason: 'start chạy tiếp sau stop() là quét cho tài khoản đã đăng xuất');
  });

  test('stop() chưa xong nửa đường mà quetKhiRanh đã tới: không quét (`_idaccount` hạ trước mọi await)', () async {
    final s = quet();
    await s.start(18);
    soLanQuet = 0;
    final dangStop = s.stop(); // KHÔNG await: chốt phải hạ ngay ở dòng đầu
    await s.quetKhiRanh(18);
    await dangStop;
    expect(soLanQuet, 0);
  });

  test('main.dart: lối `quetNgay` của worker nền đi qua quetKhiRanh (chốt phiên), không scan trần', () {
    final main = File('lib/main.dart').readAsStringSync();
    final i = main.indexOf("call.method != 'quetNgay'");
    expect(i, isNonNegative);
    final khoi = main.substring(i, main.indexOf('});', i));
    expect(khoi, contains('quetKhiRanh(id)'));
    expect(khoi, isNot(contains('.scan(')), reason: 'đường cưỡng chế đăng xuất giữ AuthSuccess suốt dongPhien');
  });
}
