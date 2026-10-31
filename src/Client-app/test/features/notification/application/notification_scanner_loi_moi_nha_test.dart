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

  test('quetKhiRanh trong lúc một lượt đang chạy → đúng MỘT lượt bù', () async {
    var soLanDoc = 0;
    final giu = Completer<void>();
    final s = quet((_) {
      soLanDoc++;
      return const [];
    }, giuBills: () => giu.future);
    final luotDau = s.scan(18);
    await Future<void>.delayed(Duration.zero);
    await s.quetKhiRanh(18);
    await s.quetKhiRanh(18); // ghi nợ hai lần vẫn chỉ MỘT lượt bù
    expect(soLanDoc, 0);
    giu.complete();
    await luotDau;
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(soLanDoc, 2, reason: 'lượt đầu + đúng một lượt bù');
  });

  test('đăng xuất giữa lượt quét: lượt bù đang nợ bị bỏ', () async {
    var soLanDoc = 0;
    final giu = Completer<void>();
    final s = quet((_) {
      soLanDoc++;
      return const [];
    }, giuBills: () => giu.future);
    final luotDau = s.scan(18);
    await Future<void>.delayed(Duration.zero);
    await s.quetKhiRanh(18);
    await s.stop();
    giu.complete();
    await luotDau;
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(soLanDoc, 1, reason: 'lượt bù sau stop() tự chuyển tiền và đặt lại lịch nhắc cho tài khoản đã đăng xuất');
  });
}
