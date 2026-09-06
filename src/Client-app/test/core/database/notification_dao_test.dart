/// Bảng thông báo cục bộ: khoá trùng phải nằm ở tầng SQLite, không phải ở Dart.
///
/// Vì sao cần: thông báo là dữ liệu **suy ra được** — mỗi lần quét lại nhìn
/// thấy đúng sự kiện cũ. Quét được kích hoạt từ nhiều nguồn (đồng bộ xong, app
/// trở lại foreground), nên hai nguồn nổ gần nhau sẽ cùng đi qua nhánh "chưa
/// có" nếu chỉ kiểm bằng `SELECT` rồi `INSERT`. Ràng buộc phải ở tầng lưu trữ.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  const accountId = 7;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  AppNotificationsCompanion mau({
    String id = 'n1',
    int idaccount = accountId,
    String kind = 'budgetNearLimit',
    String dedupeKey = 'budgetNear:b1:2026-09-01:critical',
    DateTime? createdAt,
  }) {
    return AppNotificationsCompanion.insert(
      id: id,
      idaccount: idaccount,
      kind: kind,
      dedupeKey: dedupeKey,
      title: 'Sắp vượt ngân sách',
      body: 'Bạn đã chi tiêu vượt 90% ngân sách Ăn uống',
      severity: 'warning',
      createdAt: createdAt ?? DateTime(2026, 9, 4, 8),
    );
  }

  group('khoá trùng', () {
    test('chèn hai lần cùng dedupeKey chỉ ra một hàng', () async {
      final lan1 = await db.notificationDao.insertIfAbsent(mau());
      final lan2 = await db.notificationDao.insertIfAbsent(mau(id: 'n2'));

      final rows = await db.notificationDao.getAll(accountId);
      expect(rows.length, 1,
          reason: 'Không có ràng buộc UNIQUE thì mỗi vòng quét đẻ thêm một bản '
              'sao của cùng một sự kiện.');
      expect(lan1, true, reason: 'Lần đầu phải báo là đã chèn thật.');
      expect(lan2, false,
          reason: 'Giá trị trả về là tín hiệu DUY NHẤT quyết định có bắn thông '
              'báo ra hệ điều hành hay không. Báo nhầm true là người dùng nhận '
              'lại thông báo cũ mỗi lần mở app.');
    });

    test('cùng dedupeKey nhưng khác tài khoản thì là hai hàng', () async {
      await db.notificationDao.insertIfAbsent(mau());
      await db.notificationDao.insertIfAbsent(mau(id: 'n2', idaccount: 9));

      expect((await db.notificationDao.getAll(accountId)).length, 1);
      expect((await db.notificationDao.getAll(9)).length, 1,
          reason: 'Khoá UNIQUE phải gồm cả idaccount, nếu không hai người dùng '
              'trên cùng máy sẽ chặn thông báo của nhau.');
    });

    test('hàng đã xoá vẫn chặn lần chèn sau', () async {
      await db.notificationDao.insertIfAbsent(mau());
      await db.notificationDao.dismiss('n1');

      final lai = await db.notificationDao.insertIfAbsent(mau(id: 'n3'));

      expect(lai, false,
          reason: 'Nếu vuốt xoá mà xoá hẳn hàng thì lần quét sau sinh lại ngay '
              '— người dùng xoá mãi không hết. Hàng chính là bản ghi khoá '
              'trùng, phải giữ lại và chỉ đánh dấu dismissedAt.');
    });
  });

  group('đọc theo tài khoản', () {
    test('watchUnreadCount không đếm hàng của tài khoản khác', () async {
      await db.notificationDao.insertIfAbsent(mau(dedupeKey: 'k1'));
      await db.notificationDao
          .insertIfAbsent(mau(id: 'n2', idaccount: 9, dedupeKey: 'k2'));

      expect(await db.notificationDao.watchUnreadCount(accountId).first, 1,
          reason: 'Dự án đã có tiền lệ hỏng đúng kiểu này: các truy vấn '
              '*NonDeleted không lọc tài khoản.');
    });

    test('đã đọc thì không còn đếm là chưa đọc', () async {
      await db.notificationDao.insertIfAbsent(mau());
      await db.notificationDao.markRead('n1');
      expect(await db.notificationDao.watchUnreadCount(accountId).first, 0);
    });

    test('markAllRead chỉ đụng tài khoản đang đăng nhập', () async {
      await db.notificationDao.insertIfAbsent(mau(dedupeKey: 'k1'));
      await db.notificationDao
          .insertIfAbsent(mau(id: 'n2', idaccount: 9, dedupeKey: 'k2'));

      await db.notificationDao.markAllRead(accountId);

      expect(await db.notificationDao.watchUnreadCount(accountId).first, 0);
      expect(await db.notificationDao.watchUnreadCount(9).first, 1,
          reason: 'Đọc hết của mình không được đọc hộ người khác.');
    });

    test('hàng đã xoá không hiện trong feed nhưng vẫn nằm trong bảng', () async {
      await db.notificationDao.insertIfAbsent(mau());
      await db.notificationDao.dismiss('n1');

      expect((await db.notificationDao.watchFeed(accountId).first).length, 0);
      expect((await db.notificationDao.getAll(accountId)).length, 1,
          reason: 'getAll là đường thô, dùng cho khoá trùng và dọn dẹp.');
    });

    test('feed sắp xếp mới nhất lên trước', () async {
      await db.notificationDao.insertIfAbsent(
          mau(id: 'cu', dedupeKey: 'k1', createdAt: DateTime(2026, 9, 1)));
      await db.notificationDao.insertIfAbsent(
          mau(id: 'moi', dedupeKey: 'k2', createdAt: DateTime(2026, 9, 4)));

      final feed = await db.notificationDao.watchFeed(accountId).first;
      expect(feed.first.id, 'moi');
    });
  });

  group('dọn dẹp', () {
    test('purgeOlderThan xoá hàng cũ hơn mốc', () async {
      await db.notificationDao.insertIfAbsent(
          mau(id: 'cu', dedupeKey: 'k1', createdAt: DateTime(2026, 1, 1)));
      await db.notificationDao.insertIfAbsent(
          mau(id: 'moi', dedupeKey: 'k2', createdAt: DateTime(2026, 9, 4)));

      final xoa = await db.notificationDao.purgeOlderThan(DateTime(2026, 6, 1));

      expect(xoa, 1);
      expect((await db.notificationDao.getAll(accountId)).single.id, 'moi',
          reason: 'Bảng chỉ lớn lên vì hàng đã xoá phải giữ để chặn trùng — '
              'không dọn thì sau một năm màn danh sách tải hàng nghìn hàng.');
    });

    test('purgeDataForOtherAccounts xoá thông báo của tài khoản khác',
        () async {
      await db.notificationDao.insertIfAbsent(mau(dedupeKey: 'k1'));
      await db.notificationDao
          .insertIfAbsent(mau(id: 'n2', idaccount: 9, dedupeKey: 'k2'));

      await db.purgeDataForOtherAccounts(accountId);

      expect((await db.notificationDao.getAll(9)).length, 0,
          reason: 'Bỏ sót bảng này trong purge là thông báo tài chính của '
              'người đăng nhập trước hiện trên máy người sau.');
      expect((await db.notificationDao.getAll(accountId)).length, 1,
          reason: 'Và không được xoá nhầm của người đang đăng nhập.');
    });
  });
}
