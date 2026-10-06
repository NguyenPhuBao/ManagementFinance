/// Trang trung tâm thông báo ghi nhật ký B5a: chạm, vuốt xoá, hoàn tác, "Đọc tất
/// cả" — và KHÔNG ghi gì khi nhấn giữ đổi đã đọc (dọn danh sách, không phải
/// phản ứng với nội dung).
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/notification/nhat_ky_thong_bao.dart';
import 'package:flowmoney/features/notification/presentation/pages/notification_center_page.dart';

import '../../helpers/bat_thong_bao.dart';

void main() {
  const accountId = 7;
  late AppDatabase db;
  late NhatKyThongBao nhatKy;

  Future<void> them(String id, {bool daDoc = false, bool daGat = false}) async {
    await db.notificationDao.insertIfAbsent(AppNotificationsCompanion.insert(
      id: id,
      idaccount: accountId,
      kind: 'walletNegative',
      dedupeKey: 'k-$id',
      title: 'Tiêu đề $id',
      body: 'Nội dung $id',
      severity: 'warning',
      createdAt: DateTime(2026, 9, 15, 10),
    ));
    if (daDoc) await db.notificationDao.markRead(id);
    if (daGat) await db.notificationDao.dismiss(id);
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    nhatKy = NhatKyThongBao(dao: db.notificationEventDao, idaccountPhien: () => accountId);
  });
  tearDown(() async => db.close());

  Future<void> nhip(WidgetTester tester, [int lan = 10]) async {
    for (var i = 0; i < lan; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// ⚠️ BẮT BUỘC gọi ở cuối MỖI ca, trong thân ca — xem `notification_center_page_test.dart`. Thiếu là treo cả tệp.
  Future<void> dongTrang(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> moTrang(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      // E4: "Hoàn tác" là nút trên viên toast của AppToast — dựng thật.
      builder: bocToast(batThongBao()),
      home: NotificationCenterPage(
        idaccount: accountId,
        dao: db.notificationDao,
        nhatKy: nhatKy,
      ),
    ));
    await nhip(tester);
  }

  Future<List<String>> suKien() async => [
        for (final e in await db.notificationEventDao.getAll(accountId)) '${e.suKien}:${e.dedupeKey}',
      ];

  testWidgets('chạm một dòng → mo_trong_app', (tester) async {
    await them('n1');
    await moTrang(tester);
    await tester.tap(find.text('Tiêu đề n1'));
    await nhip(tester);
    expect(await suKien(), ['mo_trong_app:k-n1']);
    await dongTrang(tester);
  });

  testWidgets('vuốt xoá → gat_bo; bấm Hoàn tác → khoi_phuc', (tester) async {
    await them('n1');
    await moTrang(tester);
    await tester.drag(find.text('Tiêu đề n1'), const Offset(-600, 0));
    await nhip(tester);
    // Viên toast trượt lên từ đáy — chạm giữa hoạt ảnh là `tap()` rơi ra ngoài và chỉ cảnh báo (xem `vuotXoa` ở
    // `notification_center_page_test.dart`).
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Hoàn tác'));
    await nhip(tester);
    expect(await suKien(), ['gat_bo:k-n1', 'khoi_phuc:k-n1']);
    await dongTrang(tester);
  });

  testWidgets('Đọc tất cả → một doc_tat_ca cho MỖI hàng chưa đọc đang hiện, không cho hàng đã đọc hay đã gạt',
      (tester) async {
    await them('a');
    await them('b');
    await them('c');
    await them('d', daDoc: true);
    await them('e', daGat: true);
    await moTrang(tester);
    await tester.tap(find.text('Đọc tất cả'));
    await nhip(tester);
    final r = (await suKien())..sort();
    expect(r, ['doc_tat_ca:k-a', 'doc_tat_ca:k-b', 'doc_tat_ca:k-c'],
        reason: 'hàng đã đọc từ trước / đã gạt khỏi màn không phải phản ứng với cú bấm này');
    await dongTrang(tester);
  });

  testWidgets('nhấn giữ đổi đã đọc → KHÔNG ghi gì', (tester) async {
    await them('n1');
    await moTrang(tester);
    await tester.longPress(find.text('Tiêu đề n1'));
    await nhip(tester);
    expect(await suKien(), isEmpty);
    await dongTrang(tester);
  });
}
