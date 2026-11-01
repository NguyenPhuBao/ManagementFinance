import 'dart:async';

import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/notification/application/notification_scanner.dart';
import 'package:flowmoney/features/notification/domain/notification_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  NotificationScanner quet(List<LoiMoiNhaThongBao> Function(int) nguon, {Future<void> Function()? giuBills}) =>
      NotificationScanner(
        dao: db.notificationDao,
        loadBudgets: (_, __) async => const [],
        loadBills: (_, __) async {
          if (giuBills != null) await giuBills();
          return const [];
        },
        syncStatus: const Stream.empty(),
        loadLoiMoiNha: nguon,
        clock: () => DateTime(2026, 10, 31, 9),
      );

  test('quét hai lần chỉ một hàng mỗi mã', () async {
    final s = quet((_) => const [(ma: 'ABCD2345', tenNha: 'Nhà An', tenNguoiMoi: 'An', hetHan: null)]);
    expect(await s.scan(18), 1);
    expect(await s.scan(18), 0, reason: 'khoá chống trùng theo mã: quét chạy sau mỗi lần đồng bộ');
    final hang = await db.notificationDao.getAll(18);
    expect(hang.map((h) => h.dedupeKey), ['loiMoiNha:ABCD2345']);
  });

  test('nguồn rỗng → không sinh, không ném (đường nền không có phiên nhà)', () async {
    expect(await quet((_) => const []).scan(18), 0);
  });

  // `start` có `await scan`, nên cờ giữ chỉ bật SAU khi start xong.
  Future<(NotificationScanner, Completer<void>, int Function())> phienDangMo() async {
    var soLanDoc = 0;
    var giuBat = false;
    final giu = Completer<void>();
    final s = quet((_) {
      soLanDoc++;
      return const [];
    }, giuBills: () => giuBat ? giu.future : Future.value());
    await s.start(18);
    soLanDoc = 0;
    giuBat = true;
    return (s, giu, () => soLanDoc);
  }

  Future<void> xa() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('quetKhiRanh trong lúc một lượt đang chạy → đúng MỘT lượt bù', () async {
    final (s, giu, doc) = await phienDangMo();
    final luotDau = s.scan(18);
    await Future<void>.delayed(Duration.zero);
    await s.quetKhiRanh(18);
    await s.quetKhiRanh(18); // ghi nợ hai lần vẫn chỉ MỘT lượt bù
    expect(doc(), 0);
    giu.complete();
    await luotDau;
    await xa();
    expect(doc(), 2, reason: 'lượt đầu + đúng một lượt bù');
    await s.stop();
  });

  test('đăng xuất giữa lượt quét: lượt bù đang nợ bị bỏ', () async {
    final (s, giu, doc) = await phienDangMo();
    final luotDau = s.scan(18);
    await Future<void>.delayed(Duration.zero);
    await s.quetKhiRanh(18);
    await s.stop();
    giu.complete();
    await luotDau;
    await xa();
    expect(doc(), 1, reason: 'lượt bù sau stop() tự chuyển tiền và đặt lại lịch nhắc cho tài khoản đã đăng xuất');
  });

  test('lượt đang chạy → stop() → quetKhiRanh: không ghi nợ lượt bù', () async {
    final (s, giu, doc) = await phienDangMo();
    final luotDau = s.scan(18);
    await Future<void>.delayed(Duration.zero);
    await s.stop();
    await s.quetKhiRanh(18);
    giu.complete();
    await luotDau;
    await xa();
    expect(doc(), 1, reason: 'household.invited có thể phát giữa stop() và lúc phiên đóng hẳn');
  });

  test('rảnh → stop() → quetKhiRanh: không quét', () async {
    final (s, giu, doc) = await phienDangMo();
    // Xả cờ giữ TRƯỚC: hồi quy (quet sau stop) phải đỏ bằng assertion, không treo ở `await` chờ `giu` vô tận.
    giu.complete();
    await s.stop();
    await s.quetKhiRanh(18);
    expect(doc(), 0);
  });

  test('rảnh, phiên đang mở → quetKhiRanh quét đúng một lần', () async {
    final (s, giu, doc) = await phienDangMo();
    giu.complete();
    await s.quetKhiRanh(18);
    expect(doc(), 1);
    await s.stop();
  });
}
