/// `DeXuatThongBaoNguon` — gom nhật ký B5a, thông báo, mốc ghi giao dịch và
/// tuỳ chọn cho `deXuatThongBao` (B5b task 3).
///
/// Canh phần NỐI: đọc đúng tài khoản, *Bỏ qua* đi qua cửa ghi `NhatKyThongBao`
/// và làm đề xuất im, và mốc "lúc ghi giao dịch" chỉ lấy khoản có `updatedAt`
/// **cùng ngày lịch** với `date` (spec §2.3 — bảng không có `createdAt`).
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/notification/data/de_xuat_thong_bao_nguon.dart';
import 'package:flowmoney/features/notification/domain/hoc_gio_thong_bao.dart';
import 'package:flowmoney/features/notification/data/datasources/nhat_ky_thong_bao.dart';
import 'package:flowmoney/features/notification/data/datasources/os_notifier.dart';
import 'package:flowmoney/features/notification/domain/notification_prefs.dart';
import 'package:flowmoney/features/notification/data/notification_prefs_store.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';

class _Os implements OsNotifier {
  bool quyen = true;
  @override
  Future<bool> daCoQuyen() async => quyen;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const id = 7;
  final now = DateTime(2027, 3, 1, 9);
  late AppDatabase db;
  late InMemoryNotificationPrefsStore store;
  late _Os os;
  late NhatKyThongBao nhatKy;
  late DeXuatThongBaoNguon nguon;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    store = InMemoryNotificationPrefsStore();
    os = _Os();
    nhatKy = NhatKyThongBao(
        dao: db.notificationEventDao, idaccountPhien: () => null, clock: () => now);
    nguon = DeXuatThongBaoNguon(
        db: db, store: store, os: os, nhatKy: nhatKy, clock: () => now);
    await db.walletDao.insert(WalletsCompanion.insert(
        id: 'vi', idaccount: id, name: 'Tiền mặt', updatedAt: DateTime(2027, 1, 1)));
  });

  tearDown(() => db.close());

  Future<void> chamHoaDon({int taiKhoan = id}) async {
    for (var i = 0; i < 25; i++) {
      await nhatKy.ghi('billDue:b$i:2027-02-10:3', SuKienThongBao.chamHdh,
          idaccount: taiKhoan, luc: DateTime(2027, 1, 1 + i, 20, 5));
    }
  }

  Future<void> giaoDich(String ma, {required DateTime ngay, required DateTime ghiLuc, bool xoa = false}) =>
      db.transactionDao.insert(TransactionsCompanion.insert(
        id: ma,
        walletId: 'vi',
        idaccount: id,
        amount: 10000,
        type: 'chi',
        date: ngay,
        isDeleted: Value(xoa),
        deletedAt: xoa ? Value(ghiLuc) : const Value.absent(),
        updatedAt: ghiLuc,
      ));

  test('⭐ 25 cú chạm nhắc hoá đơn 20:05, đang đặt 08:00 → một đề xuất 20:00', () async {
    await chamHoaDon();
    final r = await nguon.tai(id);
    expect(r.map((d) => (d.loai, d.gio)), [(LoaiDeXuat.gioHoaDon, (gio: 20, phut: 0))]);
  });

  test('Bỏ qua → ghi bo_qua_de_xuat qua NhatKyThongBao, lần nạp sau im', () async {
    await chamHoaDon();
    final d = (await nguon.tai(id)).single;
    await nguon.boQua(id, d);

    final ev = await db.notificationEventDao.getAll(id);
    expect(ev.where((e) => e.suKien == SuKienThongBao.boQuaDeXuat).map((e) => e.dedupeKey),
        ['deXuat:gioHoaDon']);
    expect(await nguon.tai(id), isEmpty);
  });

  test('chỉ đọc nhật ký của ĐÚNG tài khoản', () async {
    await chamHoaDon(taiKhoan: 8);
    expect(await nguon.tai(id), isEmpty,
        reason: 'phản ứng của tài khoản khác trên cùng máy không dạy giờ cho '
            'tài khoản này (quy tắc 2)');
  });

  test('⚠️ mốc ghi: chỉ khoản ghi CÙNG NGÀY với date — khoản ghi lùi ngày bị loại', () async {
    await store.write(id, const NotificationPrefs(nhacGhiChepBat: true));
    for (var i = 0; i < 20; i++) {
      final ngay = DateTime(2027, 1, 1 + i, 21, 10);
      await giaoDich('cung$i', ngay: ngay, ghiLuc: ngay);
    }
    // 30 khoản ghi LÙI: date là ngày trước, updatedAt 06:10 hôm sau. Lọt vào mẫu
    // thì ô 06:00 chiếm 60 % và đề xuất thành 06:00.
    for (var i = 0; i < 30; i++) {
      await giaoDich('lui$i',
          ngay: DateTime(2027, 1, 1 + i, 12), ghiLuc: DateTime(2027, 1, 2 + i, 6, 10));
    }
    final d = (await nguon.tai(id)).singleWhere((e) => e.loai == LoaiDeXuat.gioGhiChep);
    expect(d.gio, (gio: 21, phut: 0));
    expect(d.soMau, 20);
  });

  test('khoản đã xoá không vào mốc ghi', () async {
    await store.write(id, const NotificationPrefs(nhacGhiChepBat: true));
    for (var i = 0; i < 25; i++) {
      final ngay = DateTime(2027, 1, 1 + i, 21, 10);
      await giaoDich('x$i', ngay: ngay, ghiLuc: ngay, xoa: i < 6);
    }
    expect((await nguon.tai(id)).where((e) => e.loai == LoaiDeXuat.gioGhiChep), isEmpty,
        reason: 'còn 19 khoản sống — dưới cửa 20');
  });

  // Ca thuần không CSDL: canh chữ ký Entity của `mocGhiGiaoDichTu`.
  test('mocGhiGiaoDichTu: bỏ hàng isDeleted / deletedAt, giữ hàng ghi trong ngày, bỏ hàng ghi lùi ngày', () {
    final ngay = DateTime(2026, 10, 14, 9);
    TransactionEntity gd(String id, {DateTime? date, bool isDeleted = false, DateTime? deletedAt}) => TransactionEntity(
        id: id, walletId: 'w', idaccount: 1, amount: 1, type: 'chi',
        date: date ?? ngay, updatedAt: ngay, isDeleted: isDeleted, deletedAt: deletedAt);
    final moc = mocGhiGiaoDichTu([
      gd('a'),
      gd('b', isDeleted: true),
      gd('c', deletedAt: ngay),
      gd('d', date: DateTime(2026, 10, 1)),
    ]);
    expect(moc, [ngay], reason: 'Chỉ khoản sống, ghi cùng ngày lịch với `date`, mới là mốc "lúc ghi" (spec B5b §2.3).');
  });

  test('quyền tắt → không đề xuất tắt nhóm (đọc daCoQuyen)', () async {
    for (var i = 0; i < 20; i++) {
      await db.notificationDao.insertIfAbsent(AppNotificationsCompanion.insert(
        id: 'n$i',
        idaccount: id,
        kind: 'budgetNearLimit',
        dedupeKey: 'budgetNear:n$i:2027-01:70',
        title: 't',
        body: 'b',
        severity: 'info',
        createdAt: DateTime(2027, 1, 1 + i),
        osDeliveredAt: Value(DateTime(2027, 1, 1 + i, 10)),
      ));
    }
    expect((await nguon.tai(id)).map((d) => d.nhom), [NotificationGroup.budget]);
    os.quyen = false;
    expect(await nguon.tai(id), isEmpty);
  });
}
