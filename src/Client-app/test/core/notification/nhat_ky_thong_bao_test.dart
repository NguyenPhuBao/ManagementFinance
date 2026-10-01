/// `NhatKyThongBao` — cửa ghi DUY NHẤT của nhật ký thông báo (B5a).
/// Ba lời hứa: ghi đúng tài khoản của phiên, KHÔNG ghi khi không có phiên,
/// và KHÔNG BAO GIỜ ném — nhật ký hỏng không được làm hỏng thao tác người dùng.
library;

import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/database/daos/notification_event_dao.dart';
import 'package:flowmoney/core/notification/nhat_ky_thong_bao.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  int? phien = 7;
  var dem = 0;
  late NhatKyThongBao nhatKy;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    phien = 7;
    dem = 0;
    nhatKy = NhatKyThongBao(
      dao: db.notificationEventDao,
      idaccountPhien: () => phien,
      clock: () => DateTime(2026, 9, 28, 20),
      idGenerator: () => 'e${dem++}',
    );
  });
  tearDown(() => db.close());

  test('ghi theo tài khoản của phiên, lúc = clock', () async {
    await nhatKy.ghi('walletNeg:vi1:2026-09-15', SuKienThongBao.moTrongApp);
    final r = await db.notificationEventDao.getAll(7);
    expect(r, hasLength(1));
    expect(r.single.suKien, 'mo_trong_app');
    expect(r.single.luc, DateTime(2026, 9, 28, 20));
  });

  test('idaccount truyền thẳng thắng phiên (scanner / scheduler)', () async {
    phien = null;
    await nhatKy.ghi('k', SuKienThongBao.datLich, idaccount: 9, luc: DateTime(2026, 10, 1, 8), osId: 5);
    final r = await db.notificationEventDao.getAll(9);
    expect(r.single.osId, 5);
    expect(r.single.luc, DateTime(2026, 10, 1, 8));
  });

  test('không có phiên thì KHÔNG ghi (quy tắc 2 — không đoán tài khoản)', () async {
    phien = null;
    await nhatKy.ghi('k', SuKienThongBao.gatBo);
    phien = 0;
    await nhatKy.ghi('k', SuKienThongBao.gatBo);
    expect(await db.customSelect('SELECT * FROM app_notification_events').get(), isEmpty);
  });

  test('ghiNhieu ghi một hàng mỗi khoá, danh sách rỗng không làm gì', () async {
    await nhatKy.ghiNhieu(['a', 'b', 'c'], SuKienThongBao.docTatCa);
    await nhatKy.ghiNhieu([], SuKienThongBao.docTatCa);
    expect((await db.notificationEventDao.getAll(7)).map((e) => e.dedupeKey), ['a', 'b', 'c']);
  });

  test('datNguonPhien: DI dựng với nguồn rỗng (không ghi), main.dart gán nguồn thật (ghi đúng tài khoản)', () async {
    // `AuthBloc` đăng ký dạng FACTORY trong `sl` — gọi `sl<AuthBloc>()` là một bloc MỚI, luôn chưa đăng nhập.
    // Nên DI không đọc được phiên; `main.dart` gán nguồn từ đúng bloc của app.
    final nk = NhatKyThongBao(dao: db.notificationEventDao, idaccountPhien: () => null);
    await nk.ghi('truoc', SuKienThongBao.moTrongApp);
    nk.datNguonPhien(() => 11);
    await nk.ghi('sau', SuKienThongBao.moTrongApp);
    expect((await db.notificationEventDao.getAll(11)).map((e) => e.dedupeKey), ['sau'],
        reason: 'trước khi gán nguồn thì KHÔNG ghi — không đoán tài khoản (quy tắc 2)');
  });

  test('CSDL hỏng thì nuốt lỗi, không ném — cả ghi lẫn ghiNhieu', () async {
    // ⚠️ Kế hoạch dựng ca này bằng `db.close()` rồi ghi — nhưng lời ghi sau `close()` KHÔNG ném (bản sai bỏ
    // try/catch vẫn xanh), tức ca ấy không canh gì. DAO giả dưới đây ném thật.
    final hong = NhatKyThongBao(dao: _DaoHong(db), idaccountPhien: () => 7);
    await expectLater(hong.ghi('k', SuKienThongBao.hoan), completes);
    await expectLater(hong.ghiNhieu(['a', 'b'], SuKienThongBao.docTatCa), completes);
  });
}

class _DaoHong extends NotificationEventDao {
  _DaoHong(super.db);

  @override
  Future<void> ghi(AppNotificationEventsCompanion e) => Future.error(StateError('ổ đĩa đầy'));

  @override
  Future<void> ghiNhieu(List<AppNotificationEventsCompanion> es) => Future.error(StateError('ổ đĩa đầy'));
}
