/// `NotificationScanner` chạy bộ tự trả hoá đơn trong vòng quét và ghi kết
/// quả xuống bảng thông báo.
///
/// Vì sao cần canh ở đây chứ không chỉ ở bộ luật: `runAutoPays` là một closure
/// tuỳ chọn. Quên nối nó vào `NotificationRuleInput` là bộ chạy vẫn trừ tiền
/// mà không thông báo nào được ghi — tiền rời ví trong im lặng, kiểu hỏng tệ
/// nhất ở vùng này.
library;

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/notification/notification_scanner.dart';
import 'package:flowmoney/core/sync/sync_models.dart';
import 'package:flowmoney/features/bill/domain/bill_auto_pay.dart';
import 'package:flowmoney/features/bill/domain/bill_auto_pay_runner.dart';

void main() {
  const accountId = 7;
  final now = DateTime(2026, 9, 15, 10);

  late AppDatabase db;
  late StreamController<SyncStatus> syncStatus;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    syncStatus = StreamController<SyncStatus>.broadcast();
  });

  tearDown(() async {
    await syncStatus.close();
    await db.close();
  });

  NotificationScanner dung({
    required Future<List<BillAutoPayEvent>> Function(int, DateTime) runAutoPays,
    List<String>? thuTu,
  }) {
    var soId = 0;
    return NotificationScanner(
      dao: db.notificationDao,
      loadBudgets: (id, at) async => const [],
      loadBills: (id, at) async {
        thuTu?.add('loadBills');
        return const [];
      },
      markOverdue: (id, at) async {
        thuTu?.add('markOverdue');
        return 0;
      },
      runAutoPays: (id, at) {
        thuTu?.add('runAutoPays');
        return runAutoPays(id, at);
      },
      syncStatus: syncStatus.stream,
      clock: () => now,
      idGenerator: () => 'id-${soId++}',
    );
  }

  test('kết quả tự trả được ghi thành thông báo', () async {
    final scanner = dung(
      runAutoPays: (id, at) async => [
        BillAutoPayEvent(
          billId: 'hd1',
          billName: 'Tiền điện',
          ky: DateTime(2026, 9, 15),
          loai: LoaiTuTra.traDu,
          soTien: 300000,
          tenVi: 'Tiền mặt',
        ),
      ],
    );

    final soHang = await scanner.scan(accountId);

    expect(soHang, 1);
    final hang = (await db.notificationDao.getAll(accountId)).single;
    expect(hang.kind, 'billAutoPaid');
    expect(hang.body, contains('Tiền mặt'));
  });

  test('bộ tự trả nhận đúng tài khoản và mốc quét', () async {
    int? nhanId;
    DateTime? nhanAt;
    final scanner = dung(runAutoPays: (id, at) async {
      nhanId = id;
      nhanAt = at;
      return const [];
    });

    await scanner.scan(accountId);

    expect(nhanId, accountId);
    expect(nhanAt, now,
        reason: 'Mốc quét được tiêm, không phải đồng hồ riêng của bộ chạy: hai '
            'đồng hồ là hai câu trả lời cho "hôm nay là ngày mấy".');
  });

  test('chạy SAU markOverdue và TRƯỚC khi nạp hoá đơn', () async {
    final thuTu = <String>[];
    final scanner = dung(runAutoPays: (id, at) async => const [], thuTu: thuTu);

    await scanner.scan(accountId);

    expect(thuTu, ['markOverdue', 'runAutoPays', 'loadBills'],
        reason: 'Hoá đơn đọc lên cho bộ luật phải mang trạng thái SAU khi trả, '
            'nếu không thông báo "quá hạn" nổ cho đúng hoá đơn vừa được tự '
            'trả xong.');
  });

  test('bộ tự trả ném lỗi thì vòng quét vẫn sống', () async {
    final scanner = dung(runAutoPays: (id, at) => throw StateError('hỏng'));

    await expectLater(scanner.scan(accountId), completes,
        reason: 'Một sự cố ở chỗ chuyển tiền không được phép giết cả trung '
            'tâm thông báo — `payBill` là khối nguyên tử nên không để lại gì '
            'dở dang.');
  });
}
