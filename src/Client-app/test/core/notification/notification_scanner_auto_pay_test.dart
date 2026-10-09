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
    Future<int> Function(int)? gopKyTrung,
    int Function()? soLanKeoVe,
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
      soLanKeoVe: soLanKeoVe,
      gopKyTrung: gopKyTrung == null
          ? null
          : (id) {
              thuTu?.add('gopKyTrung');
              return gopKyTrung(id);
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

  // G87 (2026-10-09): kỳ hoá đơn trùng (cùng gốc chuỗi, cùng hạn) phải được gỡ TRƯỚC bộ tự trả — nếu không bộ tự
  // trả trừ tiền cho từng kỳ trùng (đo trên server: kỳ Netflix 05/10 bị trừ 3 lần).
  test('G87 · gộp kỳ trùng chạy ĐẦU TIÊN — trước markOverdue và bộ tự trả', () async {
    final thuTu = <String>[];
    int? nhanId;
    final scanner = dung(
      runAutoPays: (id, at) async => const [],
      thuTu: thuTu,
      gopKyTrung: (id) async {
        nhanId = id;
        return 0;
      },
      soLanKeoVe: () => 1,
    );

    await scanner.scan(accountId);

    expect(thuTu, ['gopKyTrung', 'markOverdue', 'runAutoPays', 'loadBills']);
    expect(nhanId, accountId);
  });

  test('G87 · gộp kỳ trùng ném lỗi thì lượt quét vẫn chạy (vệ sinh dữ liệu không được chặn tự trả, thông báo)',
      () async {
    final thuTu = <String>[];
    final scanner = dung(
      runAutoPays: (id, at) async => const [],
      thuTu: thuTu,
      gopKyTrung: (id) async => throw StateError('hỏng'),
      soLanKeoVe: () => 1,
    );

    await scanner.scan(accountId);

    expect(thuTu, ['gopKyTrung', 'markOverdue', 'runAutoPays', 'loadBills']);
  });

  test('G87 · CHƯA kéo về lần nào (lượt quét lúc mở app) → KHÔNG gộp: dữ liệu trên máy có thể cũ', () async {
    // Realme 2026-10-09: máy giữ hai kỳ trùng ở "Quá hạn" trong khi server đã "Đã trả". Gộp trên dữ liệu ấy là xoá
    // hai hoá đơn ĐÃ TRẢ, và lệnh xoá mang giờ mới hơn nên thắng trên server.
    final thuTu = <String>[];
    final scanner = dung(
      runAutoPays: (id, at) async => const [],
      thuTu: thuTu,
      gopKyTrung: (id) async => 0,
      soLanKeoVe: () => 0,
    );

    await scanner.scan(accountId);

    expect(thuTu, ['markOverdue', 'runAutoPays', 'loadBills']);
  });

  test('G87 · gộp MỘT lần cho mỗi lần kéo về thành công', () async {
    final thuTu = <String>[];
    var lan = 1;
    final scanner = dung(
      runAutoPays: (id, at) async => const [],
      thuTu: thuTu,
      gopKyTrung: (id) async => 0,
      soLanKeoVe: () => lan,
    );

    await scanner.scan(accountId);
    await scanner.scan(accountId); // ví dụ quay lại app — chưa kéo về thêm
    lan = 2;
    await scanner.scan(accountId);

    expect(thuTu.where((x) => x == 'gopKyTrung'), hasLength(2));
  });
}
